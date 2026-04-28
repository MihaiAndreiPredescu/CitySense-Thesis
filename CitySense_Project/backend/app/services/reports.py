from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from uuid import UUID

from geoalchemy2 import WKTElement
from geoalchemy2.types import Geography
from sqlalchemy import cast, func, select
from sqlalchemy.orm import Session

from ..config import Settings
from ..models import Report, ReportStatus
from ..schemas import ReportRead
from .detection import DetectionResult


@dataclass(frozen=True)
class ReportMutationResult:
    report: Report
    deduped: bool


def _make_geography_point(latitude: float, longitude: float):
    point = func.ST_SetSRID(func.ST_MakePoint(longitude, latitude), 4326)
    return cast(point, Geography)


def list_reports(db: Session, status: ReportStatus | None) -> list[Report]:
    statement = select(Report).order_by(Report.upvotes.desc(), Report.created_at.desc())
    if status is not None:
        statement = statement.where(Report.status == status.value)
    return list(db.scalars(statement).all())


def upsert_detected_report(
    *,
    db: Session,
    settings: Settings,
    latitude: float,
    longitude: float,
    detection: DetectionResult,
    image_filename: str,
) -> ReportMutationResult:
    geography_point = _make_geography_point(latitude, longitude)

    existing_report = db.scalars(
        select(Report)
        .where(
            Report.issue_type == detection.issue_type,
            Report.status == ReportStatus.OPEN.value,
            func.ST_DWithin(
                Report.location, geography_point, settings.duplicate_radius_meters
            ),
        )
        .order_by(Report.upvotes.desc(), Report.created_at.desc())
        .limit(1)
    ).first()

    if existing_report is not None:
        existing_report.upvotes += 1
        existing_report.last_photo_reported_at = datetime.now(UTC)
        db.commit()
        db.refresh(existing_report)
        return ReportMutationResult(report=existing_report, deduped=True)

    now = datetime.now(UTC)
    new_report = Report(
        issue_type=detection.issue_type,
        confidence=detection.confidence,
        latitude=latitude,
        longitude=longitude,
        location=WKTElement(f"POINT({longitude} {latitude})", srid=4326),
        image_path=image_filename,
        status=ReportStatus.OPEN.value,
        upvotes=1,
        last_photo_reported_at=now,
    )

    db.add(new_report)
    db.commit()
    db.refresh(new_report)
    return ReportMutationResult(report=new_report, deduped=False)


def update_report_status(
    db: Session,
    report_id: UUID,
    status: ReportStatus,
) -> Report | None:
    report = db.get(Report, report_id)
    if report is None:
        return None

    report.status = status.value
    db.commit()
    db.refresh(report)
    return report


def to_report_read(report: Report, settings: Settings) -> ReportRead:
    image_url = None
    if report.image_path:
        image_url = f"/uploads/{Path(report.image_path).name}"

    return ReportRead(
        id=report.id,
        issue_type=report.issue_type,
        confidence=report.confidence,
        latitude=report.latitude,
        longitude=report.longitude,
        image_path=report.image_path,
        image_url=image_url,
        status=ReportStatus(report.status),
        upvotes=report.upvotes,
        last_photo_reported_at=report.last_photo_reported_at,
        created_at=report.created_at,
        updated_at=report.updated_at,
    )

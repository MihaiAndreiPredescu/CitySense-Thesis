from __future__ import annotations

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from .models import ReportStatus


class ReportRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    issue_type: str
    confidence: float
    latitude: float
    longitude: float
    image_path: str | None = None
    image_url: str | None = None
    status: ReportStatus
    upvotes: int
    captured_at: datetime
    last_photo_reported_at: datetime
    created_at: datetime
    updated_at: datetime


class ReportSubmissionResponse(BaseModel):
    message: str
    deduped: bool
    report: ReportRead
    client_report_id: UUID | None = None
    replayed: bool = False


class ReportStatusUpdate(BaseModel):
    status: ReportStatus


class HealthResponse(BaseModel):
    status: str
    detector_mode: str
    model_path: str
    upload_dir: str
    duplicate_radius_meters: float
    min_detection_confidence: float
    detector_image_size: int
    detector_iou_threshold: float

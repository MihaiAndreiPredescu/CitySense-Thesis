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
    created_at: datetime
    updated_at: datetime


class ReportSubmissionResponse(BaseModel):
    message: str
    deduped: bool
    report: ReportRead


class ReportStatusUpdate(BaseModel):
    status: ReportStatus


class HealthResponse(BaseModel):
    status: str
    detector_mode: str
    model_path: str
    upload_dir: str
    duplicate_radius_meters: float

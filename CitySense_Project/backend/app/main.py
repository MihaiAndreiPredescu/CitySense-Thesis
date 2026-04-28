from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import datetime
from uuid import UUID

from fastapi import (
    Depends,
    FastAPI,
    File,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session

from .config import BACKEND_DIR, get_settings
from .database import get_db, initialize_database
from .models import ReportStatus
from .schemas import (
    HealthResponse,
    ReportRead,
    ReportStatusUpdate,
    ReportSubmissionResponse,
)
from .services.detection import (
    DetectionRejectedError,
    DetectorUnavailableError,
    PotholeDetector,
)
from .services.reports import (
    list_reports,
    to_report_read,
    update_report_status,
    upsert_detected_report,
)
from .services.storage import ensure_runtime_dirs, safe_unlink, save_upload


SUPPORTED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
}

settings = get_settings()
detector = PotholeDetector(settings)
templates = Jinja2Templates(directory=str(BACKEND_DIR / "templates"))


@asynccontextmanager
async def lifespan(_: FastAPI):
    ensure_runtime_dirs(settings)
    initialize_database()
    yield


app = FastAPI(title=settings.app_name, lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount(
    "/uploads",
    StaticFiles(directory=str(settings.upload_dir), check_dir=False),
    name="uploads",
)


@app.get("/", include_in_schema=False)
def root_redirect() -> RedirectResponse:
    return RedirectResponse(url="/admin")


@app.get(f"{settings.api_prefix}/health", response_model=HealthResponse)
def healthcheck() -> HealthResponse:
    return HealthResponse(
        status="ok",
        detector_mode=settings.detector_mode,
        model_path=str(settings.model_path),
        upload_dir=str(settings.upload_dir),
        duplicate_radius_meters=settings.duplicate_radius_meters,
    )


@app.post(
    f"{settings.api_prefix}/reports",
    response_model=ReportSubmissionResponse,
    status_code=201,
)
async def create_report(
    latitude: float = Form(...),
    longitude: float = Form(...),
    captured_at: datetime | None = Form(default=None),
    client_report_id: UUID | None = Form(default=None),
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> ReportSubmissionResponse:
    if image.content_type not in SUPPORTED_IMAGE_TYPES:
        raise HTTPException(
            status_code=415,
            detail="Unsupported image type. Please upload JPEG, PNG, or WebP.",
        )

    ensure_runtime_dirs(settings)
    saved_path = save_upload(image, settings.upload_dir)

    try:
        detection = detector.detect(saved_path)
    except DetectionRejectedError as exc:
        safe_unlink(saved_path)
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except DetectorUnavailableError as exc:
        safe_unlink(saved_path)
        raise HTTPException(status_code=503, detail=str(exc)) from exc

    mutation = upsert_detected_report(
        db=db,
        settings=settings,
        latitude=latitude,
        longitude=longitude,
        detection=detection,
        image_filename=saved_path.name,
        captured_at=captured_at,
        client_report_id=client_report_id,
    )

    if mutation.replayed:
        safe_unlink(saved_path)
        message = "Report was already synchronized earlier."
    elif mutation.deduped:
        safe_unlink(saved_path)
        message = "Merged with an existing pothole report and increased its priority."
    else:
        message = "Created a new pothole report."

    return ReportSubmissionResponse(
        message=message,
        deduped=mutation.deduped,
        report=to_report_read(mutation.report, settings),
        client_report_id=mutation.client_report_id,
        replayed=mutation.replayed,
    )


@app.get(f"{settings.api_prefix}/reports", response_model=list[ReportRead])
def get_reports(
    status: ReportStatus | None = Query(default=ReportStatus.OPEN),
    db: Session = Depends(get_db),
) -> list[ReportRead]:
    reports = list_reports(db, status)
    return [to_report_read(report, settings) for report in reports]


@app.patch(
    f"{settings.api_prefix}/reports/{{report_id}}/status",
    response_model=ReportRead,
)
def patch_report_status(
    report_id: UUID,
    payload: ReportStatusUpdate,
    db: Session = Depends(get_db),
) -> ReportRead:
    report = update_report_status(db, report_id, payload.status)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found.")
    return to_report_read(report, settings)


@app.get("/admin", response_class=HTMLResponse)
def admin_dashboard(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="admin.html",
        context={
            "request": request,
            "api_prefix": settings.api_prefix,
            "detector_mode": settings.detector_mode,
        },
    )

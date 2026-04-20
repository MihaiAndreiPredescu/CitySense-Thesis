from __future__ import annotations

import shutil
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from ..config import Settings


def ensure_runtime_dirs(settings: Settings) -> None:
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    settings.model_path.parent.mkdir(parents=True, exist_ok=True)


def save_upload(upload: UploadFile, target_dir: Path) -> Path:
    suffix = Path(upload.filename or "report.jpg").suffix.lower() or ".jpg"
    destination = target_dir / f"{uuid4().hex}{suffix}"

    with destination.open("wb") as buffer:
        shutil.copyfileobj(upload.file, buffer)

    return destination


def safe_unlink(path: Path) -> None:
    try:
        path.unlink(missing_ok=True)
    except OSError:
        return

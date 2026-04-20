from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]


def _split_csv(raw_value: str | None) -> tuple[str, ...]:
    if not raw_value:
        return ("*",)
    values = [item.strip() for item in raw_value.split(",") if item.strip()]
    return tuple(values) if values else ("*",)


@dataclass(frozen=True)
class Settings:
    app_name: str
    api_prefix: str
    database_url: str
    detector_mode: str
    model_path: Path
    upload_dir: Path
    duplicate_radius_meters: float
    min_detection_confidence: float
    cors_origins: tuple[str, ...]


@lru_cache
def get_settings() -> Settings:
    password = os.getenv("POSTGRES_PASSWORD", "citysense")
    database_url = os.getenv(
        "DATABASE_URL",
        f"postgresql+psycopg2://postgres:{password}@localhost:5432/citysense",
    )

    return Settings(
        app_name="CitySense Backend",
        api_prefix="/api/v1",
        database_url=database_url,
        detector_mode=os.getenv("DETECTOR_MODE", "yolo").strip().lower(),
        model_path=Path(
            os.getenv(
                "MODEL_PATH",
                str(BACKEND_DIR / "data" / "models" / "pothole_yolov8n.pt"),
            )
        ),
        upload_dir=Path(
            os.getenv(
                "UPLOAD_DIR",
                str(BACKEND_DIR / "data" / "uploads"),
            )
        ),
        duplicate_radius_meters=float(os.getenv("DUPLICATE_RADIUS_METERS", "10")),
        min_detection_confidence=float(
            os.getenv("MIN_DETECTION_CONFIDENCE", "0.35")
        ),
        cors_origins=_split_csv(os.getenv("CORS_ORIGINS")),
    )

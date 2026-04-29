from __future__ import annotations

from pathlib import Path

from PIL import Image

from app.config import Settings
from app.services.detection import PotholeDetector, normalize_issue_type


def _demo_settings(tmp_path: Path) -> Settings:
    return Settings(
        app_name="CitySense Backend",
        api_prefix="/api/v1",
        database_url="postgresql+psycopg2://postgres:citysense@localhost:5432/citysense",
        detector_mode="demo",
        model_path=tmp_path / "pothole_yolov8n.pt",
        upload_dir=tmp_path / "uploads",
        duplicate_radius_meters=10.0,
        min_detection_confidence=0.55,
        detector_image_size=416,
        detector_iou_threshold=0.50,
        cors_origins=("*",),
    )


def test_normalize_issue_type_accepts_pothole_aliases() -> None:
    assert normalize_issue_type("Pothole") == "pothole"
    assert normalize_issue_type("road pothole") == "pothole"
    assert normalize_issue_type("crack") is None


def test_demo_detector_produces_a_pothole_detection(tmp_path: Path) -> None:
    image_path = tmp_path / "demo.jpg"
    Image.new("RGB", (640, 480), color="gray").save(image_path)

    detector = PotholeDetector(_demo_settings(tmp_path))
    result = detector.detect(image_path)

    assert result.issue_type == "pothole"
    assert result.confidence > 0.5
    assert len(result.bounding_boxes) == 1

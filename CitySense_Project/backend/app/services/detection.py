from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from ..config import Settings


class DetectorUnavailableError(RuntimeError):
    """Raised when the YOLO detector cannot be used."""


class DetectionRejectedError(RuntimeError):
    """Raised when the detector runs but does not find a pothole."""


@dataclass(frozen=True)
class DetectionResult:
    issue_type: str
    confidence: float
    bounding_boxes: list[dict[str, float]]


def normalize_issue_type(raw_label: str) -> str | None:
    normalized = raw_label.strip().lower().replace("-", "_").replace(" ", "_")
    if "pothole" in normalized:
        return "pothole"
    return None


class PotholeDetector:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._model = None

    def _load_model(self):
        if self._settings.detector_mode == "demo":
            return None

        if not self._settings.model_path.exists():
            raise DetectorUnavailableError(
                f"Model file not found at {self._settings.model_path}. "
                "Train or copy a pothole checkpoint before using DETECTOR_MODE=yolo."
            )

        if self._model is None:
            from ultralytics import YOLO

            self._model = YOLO(str(self._settings.model_path))

        return self._model

    def detect(self, image_path: Path) -> DetectionResult:
        if self._settings.detector_mode == "demo":
            return self._detect_demo(image_path)

        model = self._load_model()
        results = model(
            str(image_path),
            conf=self._settings.min_detection_confidence,
            verbose=False,
        )

        if not results:
            raise DetectionRejectedError("The detector did not return any results.")

        first_result = results[0]
        boxes = first_result.boxes
        if boxes is None or len(boxes) == 0:
            raise DetectionRejectedError("No pothole was detected in the uploaded image.")

        pothole_candidates: list[DetectionResult] = []

        for box in boxes:
            confidence = float(box.conf[0])
            class_id = int(box.cls[0])
            label = normalize_issue_type(str(model.names[class_id]))
            if label != "pothole":
                continue

            x1, y1, x2, y2 = box.xyxy[0].tolist()
            pothole_candidates.append(
                DetectionResult(
                    issue_type="pothole",
                    confidence=confidence,
                    bounding_boxes=[
                        {
                            "x1": float(x1),
                            "y1": float(y1),
                            "x2": float(x2),
                            "y2": float(y2),
                        }
                    ],
                )
            )

        if not pothole_candidates:
            raise DetectionRejectedError(
                "The loaded model did not report a pothole class for this image."
            )

        return max(pothole_candidates, key=lambda result: result.confidence)

    def _detect_demo(self, image_path: Path) -> DetectionResult:
        with Image.open(image_path) as image:
            width, height = image.size

        x_padding = width * 0.18
        y_padding = height * 0.22

        return DetectionResult(
            issue_type="pothole",
            confidence=0.91,
            bounding_boxes=[
                {
                    "x1": x_padding,
                    "y1": y_padding,
                    "x2": width - x_padding,
                    "y2": height - y_padding,
                }
            ],
        )

from __future__ import annotations

import argparse
import json
from pathlib import Path

from app.config import get_settings
from app.services.detection import (
    DetectionRejectedError,
    DetectorUnavailableError,
    PotholeDetector,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run batch inference on a local evaluation folder."
    )
    parser.add_argument(
        "--images",
        required=True,
        help="Folder with JPG, JPEG, PNG, or WebP images.",
    )
    parser.add_argument(
        "--output",
        default="evaluation_results.json",
        help="Where to write the JSON summary.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    settings = get_settings()
    detector = PotholeDetector(settings)

    image_dir = Path(args.images)
    supported_suffixes = {".jpg", ".jpeg", ".png", ".webp"}
    results: list[dict[str, object]] = []

    for image_path in sorted(image_dir.iterdir()):
        if image_path.suffix.lower() not in supported_suffixes:
            continue

        try:
            detection = detector.detect(image_path)
            results.append(
                {
                    "image": image_path.name,
                    "status": "detected",
                    "issue_type": detection.issue_type,
                    "confidence": detection.confidence,
                    "boxes": detection.bounding_boxes,
                }
            )
        except (DetectionRejectedError, DetectorUnavailableError) as exc:
            results.append(
                {
                    "image": image_path.name,
                    "status": "rejected",
                    "reason": str(exc),
                }
            )

    output_path = Path(args.output)
    output_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"Wrote evaluation summary to {output_path.resolve()}")


if __name__ == "__main__":
    main()

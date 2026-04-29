from __future__ import annotations

import argparse
import shutil
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fine-tune a YOLOv8 pothole detector on an RDD2022-style dataset."
    )
    parser.add_argument(
        "--data",
        required=True,
        help="Path to a YOLO data.yaml file that exposes a pothole class.",
    )
    parser.add_argument(
        "--model",
        default="yolov8n.pt",
        help="Base YOLO model checkpoint to fine-tune.",
    )
    parser.add_argument("--epochs", type=int, default=50)
    parser.add_argument("--imgsz", type=int, default=416)
    parser.add_argument("--batch", type=int, default=8)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--project", default="runs/pothole")
    parser.add_argument("--name", default="yolov8n_cpu_50")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    from ultralytics import YOLO

    model = YOLO(args.model)
    results = model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        workers=args.workers,
        project=args.project,
        name=args.name,
    )

    best_checkpoint = Path(results.save_dir) / "weights" / "best.pt"
    target_checkpoint = (
        Path(__file__).resolve().parents[1] / "data" / "models" / "pothole_yolov8n.pt"
    )
    target_checkpoint.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(best_checkpoint, target_checkpoint)

    print(f"Saved trained checkpoint to {target_checkpoint}")


if __name__ == "__main__":
    main()

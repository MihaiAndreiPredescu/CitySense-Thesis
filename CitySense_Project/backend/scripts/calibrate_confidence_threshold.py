from __future__ import annotations

import argparse
from pathlib import Path


CONFIDENCE_VALUES = (
    0.20,
    0.25,
    0.30,
    0.35,
    0.40,
    0.45,
    0.50,
    0.55,
    0.60,
    0.65,
    0.70,
    0.75,
)
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Sweep YOLO confidence thresholds on a labelled YOLO dataset split and "
            "report precision, recall, and F1 at IoU 0.5."
        )
    )
    parser.add_argument("--model", required=True, help="Path to a trained YOLO .pt file.")
    parser.add_argument(
        "--dataset-root",
        required=True,
        help="Dataset root containing train/valid/test images and labels folders.",
    )
    parser.add_argument("--split", default="valid", choices=("train", "valid", "test"))
    parser.add_argument("--imgsz", type=int, default=416)
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--iou", type=float, default=0.50)
    parser.add_argument(
        "--precision-floor",
        type=float,
        default=0.90,
        help="Precision target used for the app-oriented threshold recommendation.",
    )
    return parser.parse_args()


def xywhn_to_xyxy(values: list[float], width: int, height: int) -> list[float]:
    x_center, y_center, box_width, box_height = values
    return [
        (x_center - box_width / 2) * width,
        (y_center - box_height / 2) * height,
        (x_center + box_width / 2) * width,
        (y_center + box_height / 2) * height,
    ]


def box_iou(left: list[float], right: list[float]) -> float:
    x1 = max(left[0], right[0])
    y1 = max(left[1], right[1])
    x2 = min(left[2], right[2])
    y2 = min(left[3], right[3])

    intersection = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    if intersection <= 0:
        return 0.0

    left_area = max(0.0, left[2] - left[0]) * max(0.0, left[3] - left[1])
    right_area = max(0.0, right[2] - right[0]) * max(0.0, right[3] - right[1])
    return intersection / (left_area + right_area - intersection)


def load_ground_truth(label_path: Path, width: int, height: int) -> list[list[float]]:
    if not label_path.exists():
        return []

    text = label_path.read_text(encoding="utf-8").strip()
    if not text:
        return []

    boxes: list[list[float]] = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) != 5:
            continue

        class_id = int(float(parts[0]))
        if class_id != 0:
            continue

        boxes.append(xywhn_to_xyxy([float(value) for value in parts[1:]], width, height))

    return boxes


def match_predictions(
    predictions: list[list[float]],
    ground_truth: list[list[float]],
    iou_threshold: float,
) -> tuple[int, int, int]:
    predictions = sorted(predictions, key=lambda item: item[4], reverse=True)
    matched_ground_truth: set[int] = set()
    true_positives = 0
    false_positives = 0

    for prediction in predictions:
        best_iou = 0.0
        best_index = None
        for index, target in enumerate(ground_truth):
            if index in matched_ground_truth:
                continue

            current_iou = box_iou(prediction[:4], target)
            if current_iou > best_iou:
                best_iou = current_iou
                best_index = index

        if best_index is not None and best_iou >= iou_threshold:
            true_positives += 1
            matched_ground_truth.add(best_index)
        else:
            false_positives += 1

    false_negatives = len(ground_truth) - len(matched_ground_truth)
    return true_positives, false_positives, false_negatives


def main() -> None:
    args = parse_args()

    from ultralytics import YOLO

    dataset_root = Path(args.dataset_root)
    image_dir = dataset_root / args.split / "images"
    label_dir = dataset_root / args.split / "labels"

    model = YOLO(args.model)
    predictions_by_image: dict[str, list[list[float]]] = {}
    ground_truth_by_image: dict[str, list[list[float]]] = {}

    for result in model.predict(
        source=str(image_dir),
        imgsz=args.imgsz,
        conf=min(CONFIDENCE_VALUES),
        iou=args.iou,
        device=args.device,
        stream=True,
        verbose=False,
    ):
        image_path = Path(result.path)
        height, width = result.orig_shape
        ground_truth_by_image[image_path.name] = load_ground_truth(
            label_dir / f"{image_path.stem}.txt",
            width,
            height,
        )

        predictions: list[list[float]] = []
        if result.boxes is not None and len(result.boxes) > 0:
            for box, confidence, class_id in zip(
                result.boxes.xyxy.cpu().numpy().tolist(),
                result.boxes.conf.cpu().numpy().tolist(),
                result.boxes.cls.cpu().numpy().tolist(),
            ):
                if int(class_id) == 0:
                    predictions.append(
                        [box[0], box[1], box[2], box[3], float(confidence)]
                    )

        predictions_by_image[image_path.name] = predictions

    rows: list[tuple[float, float, float, float, int, int, int, int, int]] = []
    for confidence in CONFIDENCE_VALUES:
        true_positives = false_positives = false_negatives = 0
        prediction_count = ground_truth_count = 0

        for image_name, ground_truth in ground_truth_by_image.items():
            predictions = [
                prediction
                for prediction in predictions_by_image.get(image_name, [])
                if prediction[4] >= confidence
            ]
            tp, fp, fn = match_predictions(predictions, ground_truth, args.iou)
            true_positives += tp
            false_positives += fp
            false_negatives += fn
            prediction_count += len(predictions)
            ground_truth_count += len(ground_truth)

        precision = (
            true_positives / (true_positives + false_positives)
            if true_positives + false_positives
            else 0.0
        )
        recall = (
            true_positives / (true_positives + false_negatives)
            if true_positives + false_negatives
            else 0.0
        )
        f1_score = (
            2 * precision * recall / (precision + recall)
            if precision + recall
            else 0.0
        )
        rows.append(
            (
                confidence,
                precision,
                recall,
                f1_score,
                true_positives,
                false_positives,
                false_negatives,
                prediction_count,
                ground_truth_count,
            )
        )

    print("conf   precision  recall  f1     tp   fp   fn   preds  gt")
    for row in rows:
        print(
            f"{row[0]:.2f}   {row[1]:.3f}      {row[2]:.3f}   {row[3]:.3f}"
            f"  {row[4]:4d} {row[5]:4d} {row[6]:4d} {row[7]:5d} {row[8]:4d}"
        )

    balanced = max(rows, key=lambda row: (row[3], row[1]))
    print(
        f"\nBEST_F1 conf={balanced[0]:.2f} precision={balanced[1]:.3f} "
        f"recall={balanced[2]:.3f} f1={balanced[3]:.3f}"
    )

    precision_candidates = [
        row for row in rows if row[1] >= args.precision_floor
    ]
    if precision_candidates:
        app_choice = max(precision_candidates, key=lambda row: (row[2], row[3]))
        print(
            f"BEST_RECALL_WITH_PRECISION>={args.precision_floor:.2f} "
            f"conf={app_choice[0]:.2f} precision={app_choice[1]:.3f} "
            f"recall={app_choice[2]:.3f} f1={app_choice[3]:.3f}"
        )


if __name__ == "__main__":
    main()

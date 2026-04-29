# Model assets

Place the trained pothole detector checkpoint in this directory as:

- `pothole_yolov8n.pt`

The backend loads that file when `DETECTOR_MODE=yolo`. The current thesis
configuration uses the YOLOv8n checkpoint trained for 50 epochs with:

- `MIN_DETECTION_CONFIDENCE=0.65`
- `DETECTOR_IMAGE_SIZE=416`
- `DETECTOR_IOU_THRESHOLD=0.50`

For local UI smoke tests before the checkpoint is available, run the backend with `DETECTOR_MODE=demo`.

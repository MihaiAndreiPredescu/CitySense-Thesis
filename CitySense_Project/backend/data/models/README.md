# Model assets

Place the trained pothole detector checkpoint in this directory as:

- `pothole_yolov8n.pt`

The backend loads that file when `DETECTOR_MODE=yolo`.

For local UI smoke tests before the checkpoint is available, run the backend with `DETECTOR_MODE=demo`.

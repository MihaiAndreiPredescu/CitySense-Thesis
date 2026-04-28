# CitySense Bachelor Project

CitySense is a pothole-first civic reporting platform developed as a Computer Science bachelor project at Babeș-Bolyai University. The repository is organized as a single monorepo that contains the mobile application, the FastAPI/PostGIS backend, and the LaTeX thesis that documents the system.

## Repository layout

- `CitySense_Project/backend` - FastAPI service, PostGIS integration, AI detector hooks, admin dashboard, and training/evaluation utilities
- `CitySense_Project/mobile_app` - Flutter mobile client for Android-first reporting and map exploration
- `THESIS` - LaTeX source for the bachelor thesis

## Core features

- Photo-based pothole reporting from a Flutter mobile app
- Automatic geolocation capture and upload
- Offline report queue on the phone with captured timestamp, location, and automatic sync when the backend becomes reachable
- YOLO-based pothole detection with a documented demo fallback for local UI smoke tests
- PostGIS duplicate detection inside a 10 meter radius
- Upvote-based merging of repeated reports
- Admin dashboard with a map, report list, status filter, and resolve actions

## Quick start

### 1. Backend

1. Copy `CitySense_Project/backend/.env.example` to `CitySense_Project/backend/.env` and adjust values if needed.
2. Start the database and backend:

```powershell
cd C:\UBB\THESIS\CitySense_Project\backend
docker compose up --build
```

3. Open the admin dashboard at [http://localhost:8000/admin](http://localhost:8000/admin).
4. Verify the API health endpoint at [http://localhost:8000/api/v1/health](http://localhost:8000/api/v1/health).

### 2. Mobile app

1. Install Flutter and ensure `flutter` is on your `PATH`.
2. Run the mobile app:

```powershell
cd C:\UBB\THESIS\CitySense_Project\mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use your machine IP instead of `10.0.2.2` when testing on a physical Android device.

## How the app works

1. The citizen opens the Flutter app and taps `Capture & submit`.
2. The app requests location permission, opens the camera, and records the photo plus GPS coordinates.
3. The report is saved locally first, including the copied image file, latitude, longitude, capture time, retry state, and a client-generated report UUID.
4. The app checks `GET /api/v1/health` on the configured backend URL.
5. If the backend is reachable, the queued report is uploaded as multipart form data with `image`, `latitude`, `longitude`, `captured_at`, and `client_report_id`.
6. If the backend is not reachable, the report remains on the phone and the UI shows that it was saved offline.
7. When connectivity changes or the app returns to the foreground, pending reports are retried automatically.
8. The backend uses `client_report_id` as an idempotency key, so retrying the same offline report does not create duplicate upvotes.
9. The backend runs pothole detection, applies the PostGIS 10 meter duplicate check, then creates a new report or merges it into an existing open report.
10. The mobile map and admin dashboard fetch open reports and display their location, priority, timestamps, and status.

### 3. Thesis

1. Install a LaTeX distribution such as MiKTeX.
2. Build the thesis:

```powershell
cd C:\UBB\THESIS\THESIS
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

## Detector modes

The backend supports two detector modes:

- `DETECTOR_MODE=yolo` loads a trained pothole checkpoint from `MODEL_PATH` and is the intended thesis mode.
- `DETECTOR_MODE=demo` returns a deterministic pothole response for UI and API smoke tests when a trained checkpoint is not yet available.

The default code path is the real YOLO-based detector. The demo mode is included only to keep the rest of the stack testable while training assets are prepared.

## Training and evaluation assets

- Place trained weights in `CitySense_Project/backend/data/models/pothole_yolov8n.pt`
- Use `CitySense_Project/backend/scripts/train_pothole_detector.py` to fine-tune a model on an RDD2022-style dataset
- Use `CitySense_Project/backend/scripts/evaluate_detector.py` to run batch inference over a local evaluation folder

## Notes

- Generated LaTeX artifacts, model weights, uploaded images, virtual environments, and build outputs are ignored by git.
- The legacy `CitySense_Project` history has been preserved and attached to this monorepo.

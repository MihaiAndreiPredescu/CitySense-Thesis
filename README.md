# CitySense Bachelor Project

CitySense is a pothole-first civic reporting platform developed as a Computer Science bachelor project at Babeș-Bolyai University. The repository is organized as a single monorepo that contains the mobile application, the FastAPI/PostGIS backend, and the LaTeX thesis that documents the system.

## Repository layout

- `CitySense_Project/backend` - FastAPI service, PostGIS integration, AI detector hooks, admin dashboard, and training/evaluation utilities
- `CitySense_Project/mobile_app` - Flutter mobile client for Android-first reporting and map exploration
- `THESIS` - LaTeX source for the bachelor thesis

## Core features

- Photo-based pothole reporting from a Flutter mobile app
- Automatic geolocation capture and upload
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

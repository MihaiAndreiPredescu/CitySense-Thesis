# CitySense Mobile App

This Flutter application is the citizen-facing client for CitySense. It supports an Android-first reporting flow in which the user:

1. captures a pothole photo,
2. grants location access,
3. submits the report to the backend,
4. reviews the result, and
5. explores active issues on a map.

## Run locally

```powershell
cd C:\UBB\THESIS\CitySense_Project\mobile_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use your machine IP instead of `10.0.2.2` when testing on a physical Android device.

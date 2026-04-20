import 'package:geolocator/geolocator.dart';

class LocationServiceException implements Exception {
  LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services are disabled on this device.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationServiceException(
        'Location permission was denied. Please grant access to continue.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission is permanently denied. Update it from the Android settings screen.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
      ),
    );
  }
}

import 'package:geolocator/geolocator.dart';

import '../models/weather.dart';
import 'weather_service.dart';

/// Resolves the farm's coordinates for the weather forecast.
///
/// Location is a convenience, never a hard requirement — every failure path
/// falls back to [FarmLocation.fallback] so the weather screen still works
/// when permission is denied.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final _weather = WeatherService();

  /// Returns the device location, or null when unavailable for any reason.
  Future<FarmLocation?> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final name = await _weather.describeCoordinates(
        position.latitude,
        position.longitude,
      );

      return FarmLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        name: name,
      );
    } catch (_) {
      return null;
    }
  }
}

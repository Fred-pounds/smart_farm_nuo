import 'package:flutter/foundation.dart';

import '../models/farm_profile.dart';
import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';

/// The farm's identity: name, location, size.
///
/// Held apart from [SettingsProvider] because this is farm data the user
/// authored, not a device preference — it decides what the weather layer
/// fetches and what the app calls the place it is reporting on.
class FarmProfileProvider extends ChangeNotifier {
  final SettingsService _settings = SettingsService();
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();

  FarmProfile _profile = FarmProfile.unset;
  bool _loaded = false;

  FarmProfile get profile => _profile;
  bool get isLoaded => _loaded;

  /// False until the farmer has named their farm. Drives first-run setup.
  bool get needsSetup => _loaded && !_profile.isConfigured;

  /// What to call the farm on screen. Never coordinates — a farmer does not
  /// recognise their own field from a decimal pair.
  String get displayName => _profile.isConfigured ? _profile.name : 'Your farm';

  FarmProfileProvider() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _settings.savedProfile();
    if (saved != null) {
      _profile = saved;
    } else {
      // Carry over a location set in the older Settings screen so upgrading
      // does not silently reset someone's farm to the default coordinates.
      final legacy = await _settings.savedLocation();
      if (legacy != null) {
        _profile = _profile.copyWith(location: legacy);
      }
      _profile = _profile.copyWith(areaSqm: await _settings.fieldAreaSqm());
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> save(FarmProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _settings.saveProfile(profile);
    // Kept in step so the weather layer and litre estimates read the same
    // values wherever they look.
    await _settings.saveLocation(profile.location);
    await _settings.setFieldAreaSqm(profile.areaSqm);
  }

  Future<void> setName(String name) => save(_profile.copyWith(name: name));

  Future<void> setLocation(FarmLocation location, {bool fromGps = false}) =>
      save(_profile.copyWith(location: location, locationFromGps: fromGps));

  Future<void> setArea(double areaSqm) =>
      save(_profile.copyWith(areaSqm: areaSqm));

  /// Asks the device where it is. Returns null when permission is refused or
  /// the fix times out — the caller decides what to say about it.
  Future<FarmLocation?> detectLocation() => _locationService.currentLocation();

  Future<List<FarmLocation>> searchPlaces(String query) =>
      _weatherService.searchPlaces(query);
}

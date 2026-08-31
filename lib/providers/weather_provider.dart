import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/weather.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/weather_service.dart';

enum WeatherStatus { idle, loading, ready, error }

class WeatherProvider extends ChangeNotifier {
  final WeatherService _weather = WeatherService();
  final LocationService _locationService = LocationService();
  final SettingsService _settings = SettingsService();

  /// Forecast data older than this is refreshed on the next screen visit.
  static const Duration staleAfter = Duration(minutes: 30);

  WeatherReport? _report;
  WeatherStatus _status = WeatherStatus.idle;
  String? _error;
  FarmLocation _location = FarmLocation.fallback;
  bool _usingFallbackLocation = true;

  WeatherReport? get report => _report;
  WeatherStatus get status => _status;
  String? get error => _error;
  FarmLocation get location => _location;
  bool get usingFallbackLocation => _usingFallbackLocation;
  bool get hasData => _report != null;

  bool get isStale =>
      _report == null ||
      DateTime.now().difference(_report!.fetchedAt) > staleAfter;

  WeatherProvider() {
    initialise();
  }

  Future<void> initialise() async {
    final saved = await _settings.savedLocation();
    final useGps = await _settings.useGps();

    if (saved != null && !useGps) {
      _location = saved;
      _usingFallbackLocation = false;
    } else {
      final gps = await _locationService.currentLocation();
      if (gps != null) {
        _location = gps;
        _usingFallbackLocation = false;
        await _settings.saveLocation(gps);
      } else if (saved != null) {
        _location = saved;
        _usingFallbackLocation = false;
      } else {
        _location = FarmLocation.fallback;
        _usingFallbackLocation = true;
      }
    }

    notifyListeners();
    await refresh();
  }

  /// Fetches only when the cached report has gone stale — cheap to call from
  /// `build` or on tab changes.
  Future<void> refreshIfStale() async {
    if (_status == WeatherStatus.loading) return;
    if (isStale) await refresh();
  }

  Future<void> refresh() async {
    _status = WeatherStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _report = await _weather.fetch(_location);
      _status = WeatherStatus.ready;
    } catch (e) {
      _status = WeatherStatus.error;
      _error = _friendlyError(e);
    }
    notifyListeners();
  }

  Future<void> setLocation(FarmLocation location) async {
    _location = location;
    _usingFallbackLocation = false;
    await _settings.saveLocation(location);
    await _settings.setUseGps(false);
    notifyListeners();
    await refresh();
  }

  /// Re-acquires GPS and refreshes, e.g. from the Settings screen.
  Future<bool> useDeviceLocation() async {
    final gps = await _locationService.currentLocation();
    if (gps == null) return false;

    _location = gps;
    _usingFallbackLocation = false;
    await _settings.saveLocation(gps);
    await _settings.setUseGps(true);
    notifyListeners();
    await refresh();
    return true;
  }

  Future<List<FarmLocation>> searchPlaces(String query) =>
      _weather.searchPlaces(query);

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('Failed host')) {
      return 'No internet connection. Weather needs a network to update.';
    }
    if (text.contains('TimeoutException')) {
      return 'The weather service timed out. Pull down to try again.';
    }
    return text.replaceFirst('Exception: ', '');
  }
}

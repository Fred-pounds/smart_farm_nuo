import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';

/// Device-local preferences, loaded once at startup and written through on
/// every change.
class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  String _farmerName = SettingsService.defaultFarmerName;
  bool _darkMode = false;
  double _fieldAreaSqm = 100;
  double _pumpFlowLpm = 12;
  bool _loaded = false;

  /// The person the dashboard greets. Empty when unset.
  String get farmerName => _farmerName;

  bool get darkMode => _darkMode;
  double get fieldAreaSqm => _fieldAreaSqm;
  double get pumpFlowLpm => _pumpFlowLpm;
  bool get isLoaded => _loaded;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    _darkMode = await _service.darkMode();
    _farmerName = await _service.farmerName();
    _fieldAreaSqm = await _service.fieldAreaSqm();
    _pumpFlowLpm = await _service.pumpFlowLpm();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFarmerName(String value) async {
    _farmerName = value.trim();
    notifyListeners();
    await _service.setFarmerName(_farmerName);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _service.setDarkMode(value);
  }

  Future<void> setFieldAreaSqm(double value) async {
    _fieldAreaSqm = value.clamp(1.0, 1000000.0);
    notifyListeners();
    await _service.setFieldAreaSqm(_fieldAreaSqm);
  }

  Future<void> setPumpFlowLpm(double value) async {
    _pumpFlowLpm = value.clamp(0.1, 1000.0);
    notifyListeners();
    await _service.setPumpFlowLpm(_pumpFlowLpm);
  }
}

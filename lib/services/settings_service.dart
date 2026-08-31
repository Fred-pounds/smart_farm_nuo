import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/farm_profile.dart';
import '../models/weather.dart';

/// Local, device-only preferences. Farm state stays in Firebase; this holds
/// the things only this phone needs to know.
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _kLocation = 'farm_location';
  static const _kProfile = 'farm_profile';
  static const _kUseGps = 'use_gps';
  static const _kFieldArea = 'field_area_sqm';
  static const _kPumpFlow = 'pump_flow_lpm';
  static const _kDarkMode = 'dark_mode';
  static const _kFarmerName = 'farmer_name';
  static const _kPlantings = 'plantings';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  // --- Location ------------------------------------------------------------

  Future<FarmLocation?> savedLocation() async {
    final raw = (await _p).getString(_kLocation);
    if (raw == null) return null;
    try {
      return FarmLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocation(FarmLocation location) async =>
      (await _p).setString(_kLocation, jsonEncode(location.toJson()));

  /// The farm profile the user set up, or null before first run.
  Future<FarmProfile?> savedProfile() async {
    final raw = (await _p).getString(_kProfile);
    if (raw == null) return null;
    try {
      return FarmProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(FarmProfile profile) async =>
      (await _p).setString(_kProfile, jsonEncode(profile.toJson()));

  Future<bool> useGps() async => (await _p).getBool(_kUseGps) ?? true;

  Future<void> setUseGps(bool value) async =>
      (await _p).setBool(_kUseGps, value);

  // --- Field geometry, used for litre estimates ----------------------------

  Future<double> fieldAreaSqm() async =>
      (await _p).getDouble(_kFieldArea) ?? 100;

  Future<void> setFieldAreaSqm(double value) async =>
      (await _p).setDouble(_kFieldArea, value);

  /// Pump output in litres per minute — turns pump runtime into water volume.
  Future<double> pumpFlowLpm() async => (await _p).getDouble(_kPumpFlow) ?? 12;

  Future<void> setPumpFlowLpm(double value) async =>
      (await _p).setDouble(_kPumpFlow, value);

  // --- Appearance ----------------------------------------------------------

  Future<bool> darkMode() async => (await _p).getBool(_kDarkMode) ?? false;

  Future<void> setDarkMode(bool value) async =>
      (await _p).setBool(_kDarkMode, value);

  // --- Identity ------------------------------------------------------------

  /// The person the dashboard greets, as distinct from the farm's name.
  ///
  /// Device-local rather than part of [FarmProfile], which is the *farm's*
  /// record and is shaped around location and area. One phone, one greeting;
  /// two people sharing a farm should not have to agree on a first name.
  ///
  /// Empty means "not set", and the greeting falls back to the farm name.
  Future<String> farmerName() async =>
      (await _p).getString(_kFarmerName) ?? defaultFarmerName;

  Future<void> setFarmerName(String value) async =>
      (await _p).setString(_kFarmerName, value.trim());

  /// Seeded for this build's owner so the dashboard reads correctly out of
  /// the box. **Change this to `''` before the app goes to anyone else** —
  /// it is the one place a name is hard-coded, and an empty default makes the
  /// greeting fall back to the farm's own name.
  static const String defaultFarmerName = 'Fredrick';

  // --- Plantings -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadPlantings() async {
    final raw = (await _p).getString(_kPlantings);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePlantings(List<Map<String, dynamic>> plantings) async =>
      (await _p).setString(_kPlantings, jsonEncode(plantings));
}

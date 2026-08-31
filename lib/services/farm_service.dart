import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/farm_data.dart';

/// The app's single point of contact with `/farm`.
///
/// Each field is watched separately and merged into one [FarmData] stream, so
/// a change to any one value produces a complete, current snapshot without
/// re-reading the whole subtree.
///
/// Traffic is bidirectional but strictly divided:
///
/// * **Read** — everything the controller publishes about itself.
/// * **Write** — `mode`, `pump`, `threshold` (user intent), and
///   `weather/*` (the forecast the controller cannot fetch for itself).
///
/// The app never writes a field the device owns. Doing so would let the UI
/// manufacture device state.
class FarmService {
  static final FarmService _instance = FarmService._internal();
  factory FarmService() => _instance;
  FarmService._internal();

  final _db = FirebaseDatabase.instance.ref('farm');

  late final StreamController<FarmData> _controller =
      StreamController<FarmData>.broadcast();

  FarmData _current = FarmData.initial;
  final List<StreamSubscription> _subs = [];
  bool _initialized = false;

  Stream<FarmData> get stream => _controller.stream;

  /// The most recent snapshot, for callers that need a value rather than a
  /// subscription.
  FarmData get current => _current;

  void init() {
    if (_initialized) return;
    _initialized = true;

    // --- Control and configuration ----------------------------------------
    _watch('mode', (v) => _current.copyWith(mode: v.toString()));
    _watch('pump', (v) => _current.copyWith(pump: _asBool(v)));
    _watch('threshold', (v) => _current.copyWith(threshold: _asInt(v)));

    // --- Device-owned truth ------------------------------------------------
    _watch('pumpStatus', (v) => _current.copyWith(pumpStatus: _asBool(v)));
    _watch('soilMoisture', (v) => _current.copyWith(soilMoisture: _asInt(v)));
    _watch('temperature', (v) => _current.copyWith(temperature: _asDouble(v)));
    _watch('humidity', (v) => _current.copyWith(humidity: _asDouble(v)));
    _watch(
      'irrigationDuration',
      (v) => _current.copyWith(irrigationDurationMs: _asInt(v)),
    );
    _watch(
      'irrigationReason',
      (v) => _current.copyWith(irrigationReason: v.toString()),
    );

    // --- The app's own weather publication, read back for confirmation -----
    _watch(
      'weather/rainExpected',
      (v) => _current.copyWith(rainExpected: _asBool(v)),
    );
    _watch(
      'weather/rainProbability',
      (v) => _current.copyWith(rainProbability: _asInt(v)),
    );
  }

  /// Subscribes to one field and folds it into the merged snapshot.
  ///
  /// A malformed or unexpected value is dropped rather than crashing the
  /// stream: one bad field must not take down every reading on the dashboard.
  void _watch(String path, FarmData Function(Object value) fold) {
    _subs.add(
      _db.child(path).onValue.listen((event) {
        final value = event.snapshot.value;
        if (value == null) return;
        try {
          _current = fold(value);
          _controller.add(_current);
        } catch (e) {
          // Keep the last good snapshot for this field.
        }
      }, onError: _controller.addError),
    );
  }

  static bool _asBool(Object value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().toLowerCase() == 'true';
  }

  static int _asInt(Object value) {
    if (value is num) return value.toInt();
    return int.parse(value.toString());
  }

  static double _asDouble(Object value) {
    if (value is num) return value.toDouble();
    return double.parse(value.toString());
  }

  Future<void> setMode(String mode) => _db.child('mode').set(mode);

  Future<void> setPump(bool on) => _db.child('pump').set(on);

  Future<void> setThreshold(int value) => _db.child('threshold').set(value);

  /// Hands the controller the rain outlook it cannot fetch for itself.
  ///
  /// Written as one atomic update so the controller can never read a new
  /// probability against an old `rainExpected` flag.
  ///
  /// `updatedAt` is written for a firmware change that should follow: the
  /// controller has no way to tell a fresh outlook from a week-old one, and
  /// should ignore this block once it ages out. Current firmware reads only
  /// the two fields it knows and is unaffected by the extra key.
  Future<void> publishWeather({
    required bool rainExpected,
    required int rainProbability,
  }) {
    return _db.child('weather').update({
      'rainExpected': rainExpected,
      'rainProbability': rainProbability,
      'updatedAt': ServerValue.timestamp,
    });
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _controller.close();
    _initialized = false;
  }
}

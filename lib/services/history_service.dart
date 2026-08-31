import 'package:firebase_database/firebase_database.dart';

import '../models/farm_data.dart';
import '../models/sensor_reading.dart';

/// Logs soil-moisture samples to `/farm/history` and reads them back for the
/// trend charts.
///
/// Logging happens app-side deliberately: it means trends work with the
/// existing ESP32 firmware untouched. If the firmware is later updated to log
/// its own samples to the same path, this service reads those too.
class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  final _history = FirebaseDatabase.instance.ref('farm/history');

  /// Minimum gap between routine samples. Pump state changes bypass this so
  /// irrigation events are never missed.
  static const Duration sampleInterval = Duration(minutes: 10);

  /// Samples older than this are pruned on the next write.
  static const Duration retention = Duration(days: 7);

  /// Upper bound on how many samples the charts read.
  static const int maxSamples = 1000;

  DateTime? _lastLoggedAt;
  bool? _lastPumpState;
  DateTime? _lastPrunedAt;

  /// Records a sample if enough time has passed, or if the pump just changed
  /// state. Returns true when something was written.
  Future<bool> maybeLog(FarmData data) async {
    if (data.soilMoisture <= 0) return false;

    final now = DateTime.now();
    final pumpChanged =
        _lastPumpState != null && _lastPumpState != data.pumpStatus;
    final intervalElapsed =
        _lastLoggedAt == null ||
        now.difference(_lastLoggedAt!) >= sampleInterval;

    _lastPumpState = data.pumpStatus;
    if (!pumpChanged && !intervalElapsed) return false;

    _lastLoggedAt = now;

    final reading = SensorReading(
      timestamp: now,
      soilMoisture: data.soilMoisture,
      pumpOn: data.pumpStatus,
    );

    await _history.push().set(reading.toJson());
    await _maybePrune(now);
    return true;
  }

  /// Deletes samples past the retention window, at most once an hour.
  Future<void> _maybePrune(DateTime now) async {
    if (_lastPrunedAt != null &&
        now.difference(_lastPrunedAt!) < const Duration(hours: 1)) {
      return;
    }
    _lastPrunedAt = now;

    final cutoff = now.subtract(retention).millisecondsSinceEpoch;
    final stale = await _history
        .orderByChild('ts')
        .endBefore(cutoff.toDouble())
        .limitToFirst(200)
        .get();

    if (!stale.exists) return;
    for (final child in stale.children) {
      final key = child.key;
      if (key != null) await _history.child(key).remove();
    }
  }

  /// Streams the reading history, oldest first.
  Stream<List<SensorReading>> stream() {
    return _history.orderByChild('ts').limitToLast(maxSamples).onValue.map((
      event,
    ) {
      final readings = <SensorReading>[];
      for (final child in event.snapshot.children) {
        final value = child.value;
        if (value is Map) {
          try {
            readings.add(SensorReading.fromJson(value));
          } catch (_) {
            // Skip malformed entries rather than breaking the whole chart.
          }
        }
      }
      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return readings;
    });
  }

  Future<void> clear() => _history.remove();
}

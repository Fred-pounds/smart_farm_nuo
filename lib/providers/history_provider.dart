import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/farm_data.dart';
import '../models/sensor_reading.dart';
import '../services/history_service.dart';

/// Holds the soil-moisture reading history and the water-usage figures
/// derived from it.
class HistoryProvider extends ChangeNotifier {
  final HistoryService _service = HistoryService();

  List<SensorReading> _readings = const [];
  IrrigationStats _stats = IrrigationStats.empty;
  StreamSubscription<List<SensorReading>>? _sub;
  double _pumpFlowLpm = 12;

  List<SensorReading> get readings => _readings;
  IrrigationStats get stats => _stats;
  bool get hasEnoughData => _readings.length >= 2;

  HistoryProvider() {
    _sub = _service.stream().listen(
      (readings) {
        _readings = readings;
        _stats = _computeStats(readings);
        notifyListeners();
      },
      onError: (_) {
        // A missing /farm/history node is normal on first run — the first
        // logged sample creates it.
      },
    );
  }

  /// Called by the dashboard whenever fresh sensor data arrives.
  void onFarmData(FarmData data) {
    _service.maybeLog(data);
  }

  /// Keeps litre estimates in step with the configured pump flow rate.
  void setPumpFlow(double lpm) {
    if (_pumpFlowLpm == lpm) return;
    _pumpFlowLpm = lpm;
    _stats = _computeStats(_readings);
    notifyListeners();
  }

  /// Readings from the last [hours] hours, for the trend chart.
  List<SensorReading> recent(int hours) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return _readings.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  /// Attributes pump runtime to the gap between consecutive samples.
  ///
  /// Gaps longer than twice the sampling interval are capped — the app may
  /// have been closed, and we should not credit that whole window as
  /// irrigation.
  IrrigationStats _computeStats(List<SensorReading> readings) {
    if (readings.length < 2) return IrrigationStats.empty;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(const Duration(days: 6));
    final maxGap = HistoryService.sampleInterval * 2;

    var todaySeconds = 0;
    var weekSeconds = 0;
    var cyclesToday = 0;
    var previousPumpOn = readings.first.pumpOn;

    for (var i = 0; i < readings.length - 1; i++) {
      final current = readings[i];
      final next = readings[i + 1];

      // A cycle starts on each off → on transition.
      if (current.pumpOn &&
          !previousPumpOn &&
          current.timestamp.isAfter(startOfDay)) {
        cyclesToday++;
      }
      previousPumpOn = current.pumpOn;

      if (!current.pumpOn) continue;

      var gap = next.timestamp.difference(current.timestamp);
      if (gap > maxGap) gap = maxGap;
      if (gap.isNegative) continue;

      if (current.timestamp.isAfter(startOfDay)) {
        todaySeconds += gap.inSeconds;
      }
      if (current.timestamp.isAfter(startOfWeek)) {
        weekSeconds += gap.inSeconds;
      }
    }

    final todayRuntime = Duration(seconds: todaySeconds);
    final weekRuntime = Duration(seconds: weekSeconds);

    return IrrigationStats(
      runtimeToday: todayRuntime,
      runtimeThisWeek: weekRuntime,
      cyclesToday: cyclesToday,
      litresToday: todayRuntime.inSeconds / 60 * _pumpFlowLpm,
      litresThisWeek: weekRuntime.inSeconds / 60 * _pumpFlowLpm,
    );
  }

  Future<void> clearHistory() async {
    await _service.clear();
    _readings = const [];
    _stats = IrrigationStats.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

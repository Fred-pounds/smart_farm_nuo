import '../models/alert.dart';
import '../models/farm_data.dart';
import '../models/planting.dart';
import '../models/pump_command.dart';
import '../models/sensor_reading.dart';
import '../models/weather.dart';

/// Derives the alert list on demand from live state.
///
/// Nothing is persisted: an alert exists exactly as long as the condition
/// that raised it, which keeps the list honest and avoids stale warnings.
class AlertBuilder {
  const AlertBuilder._();

  /// No new reading for this long means the ESP32 has probably dropped off.
  static const Duration sensorTimeout = Duration(minutes: 45);

  /// Continuous pump runtime beyond this is almost certainly a stuck relay or
  /// a failed sensor. Used when the controller has not declared a cycle
  /// length, and in manual mode where a long run may be deliberate.
  static const Duration maxContinuousRuntime = Duration(hours: 2);

  /// How far past its declared cycle an automatic run may go before it counts
  /// as an overrun.
  ///
  /// The controller polls every 3 s and publishes every 5 s, so a cycle of a
  /// few seconds is only ever observed coarsely; the multiplier and floor
  /// absorb that without hiding a genuinely stuck pump.
  static const int _overrunFactor = 6;
  static const Duration _minOverrunWindow = Duration(minutes: 1);

  /// The runtime beyond which an automatic cycle is considered stuck.
  ///
  /// The firmware's own `irrigationDuration` is measured in seconds, so the
  /// flat two-hour ceiling would let a stuck relay flood a field for hours
  /// before anyone was told. When the controller states its intended cycle,
  /// hold it to that instead.
  static Duration overrunLimitFor(FarmData farm) {
    if (!farm.isAutomatic || farm.irrigationDurationMs <= 0) {
      return maxContinuousRuntime;
    }
    final scaled = farm.irrigationDuration * _overrunFactor;
    return scaled < _minOverrunWindow ? _minOverrunWindow : scaled;
  }

  static List<FarmAlert> build({
    required FarmData farm,
    required bool isConnected,
    required WeatherReport? weather,
    required List<SensorReading> history,
    required List<FarmTask> tasks,
    PumpCommandState command = PumpCommandState.idle,
  }) {
    final alerts = <FarmAlert>[];
    final now = DateTime.now();

    // --- Connectivity ------------------------------------------------------
    if (!isConnected) {
      alerts.add(
        FarmAlert(
          id: 'offline',
          title: 'Farm controller offline',
          message:
              'The app cannot reach Firebase. Readings and pump control are '
              'unavailable until the connection is restored.',
          severity: AlertSeverity.critical,
          category: AlertCategory.sensor,
          raisedAt: now,
        ),
      );
    } else if (history.isNotEmpty &&
        now.difference(history.last.timestamp) > sensorTimeout) {
      final minutes = now.difference(history.last.timestamp).inMinutes;
      alerts.add(
        FarmAlert(
          id: 'sensor_stale',
          title: 'No sensor update for ${_humanMinutes(minutes)}',
          message:
              'The last soil reading arrived ${_humanMinutes(minutes)} ago. '
              'Check that the ESP32 has power and Wi-Fi.',
          severity: AlertSeverity.warning,
          category: AlertCategory.sensor,
          raisedAt: now,
        ),
      );
    }

    // --- Sensor plausibility ----------------------------------------------
    if (isConnected && farm.soilMoisture == 0) {
      alerts.add(
        FarmAlert(
          id: 'sensor_zero',
          title: 'Soil sensor reading zero',
          message:
              'A reading of 0 usually means the sensor is disconnected or '
              'short-circuited, not that the soil is saturated.',
          severity: AlertSeverity.warning,
          category: AlertCategory.sensor,
          raisedAt: now,
        ),
      );
    } else if (isConnected && farm.soilMoisture > 4000) {
      alerts.add(
        FarmAlert(
          id: 'sensor_max',
          title: 'Soil sensor reading at maximum',
          message:
              'A reading of ${farm.soilMoisture} suggests the probe is in air '
              'rather than soil, or the wiring has come loose.',
          severity: AlertSeverity.warning,
          category: AlertCategory.sensor,
          raisedAt: now,
        ),
      );
    }

    // --- Pump --------------------------------------------------------------
    final continuousRuntime = _continuousPumpRuntime(history);
    final overrunLimit = overrunLimitFor(farm);
    if (farm.pumpStatus && continuousRuntime > overrunLimit) {
      final declared = farm.isAutomatic && farm.irrigationDurationMs > 0
          ? ' The controller intended a '
                '${_humanDuration(farm.irrigationDuration)} cycle.'
          : '';
      alerts.add(
        FarmAlert(
          id: 'pump_stuck',
          title: 'Pump has run for ${_humanDuration(continuousRuntime)}',
          message:
              'Continuous running this long points to a stuck relay, a dry '
              'water source, or a controller that lost its connection mid-cycle.'
              '$declared Check the system before the pump is damaged or the '
              'field is flooded.',
          severity: AlertSeverity.critical,
          category: AlertCategory.pump,
          raisedAt: now,
          actionLabel: 'Turn pump off',
        ),
      );
    }

    // A command in flight is *expected* to diverge: the backend holds the new
    // value while the relay has not switched yet. Only divergence that has
    // outlived the command lifecycle means something is actually wrong.
    if (!farm.isAutomatic &&
        farm.pump &&
        !farm.pumpStatus &&
        !command.isInFlight) {
      alerts.add(
        FarmAlert(
          id: 'pump_not_responding',
          title: 'Pump not responding',
          message:
              'The controller has been told to run the pump, but it still '
              'reports the pump OFF. Check the relay wiring and the pump power '
              'supply — do not assume water is flowing.',
          severity: AlertSeverity.warning,
          category: AlertCategory.pump,
          raisedAt: now,
        ),
      );
    }

    // --- Soil --------------------------------------------------------------
    if (isConnected && farm.isDry && farm.soilMoisture > 0) {
      final severelyDry = farm.soilMoisture > farm.threshold * 1.25;
      alerts.add(
        FarmAlert(
          id: 'soil_dry',
          title: severelyDry ? 'Soil is severely dry' : 'Soil is dry',
          message: severelyDry
              ? 'Reading ${farm.soilMoisture} is well past the ${farm.threshold} '
                    'threshold. The crop is likely under water stress right now.'
              : 'Reading ${farm.soilMoisture} is above the ${farm.threshold} '
                    'threshold. Irrigation is due.',
          severity: severelyDry
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          category: AlertCategory.soil,
          raisedAt: now,
          actionLabel: farm.isAutomatic ? null : 'Turn pump on',
        ),
      );
    }

    // --- Weather -----------------------------------------------------------
    if (weather != null) {
      final rain24h = weather.rainfallInNextHours(24);
      if (rain24h >= 25) {
        alerts.add(
          FarmAlert(
            id: 'heavy_rain',
            title: 'Heavy rain expected',
            message:
                '${rain24h.toStringAsFixed(0)} mm forecast in the next 24 hours. '
                'Clear drainage channels and switch to manual mode if you want '
                'to keep the pump off.',
            severity: AlertSeverity.warning,
            category: AlertCategory.weather,
            raisedAt: now,
          ),
        );
      }

      if (weather.current.temperatureC >= 36) {
        alerts.add(
          FarmAlert(
            id: 'heat_stress',
            title: 'Heat stress risk',
            message:
                'It is ${weather.current.temperatureC.round()}°C. Irrigate early '
                'morning or late evening — midday water mostly evaporates.',
            severity: AlertSeverity.warning,
            category: AlertCategory.weather,
            raisedAt: now,
          ),
        );
      }

      if (weather.daily.isNotEmpty && weather.daily.first.et0Mm >= 6) {
        alerts.add(
          FarmAlert(
            id: 'high_et0',
            title: 'High water loss today',
            message:
                'Evapotranspiration is ${weather.daily.first.et0Mm.toStringAsFixed(1)} mm '
                'today, so soil will dry out unusually fast. Consider lowering '
                'the dry threshold.',
            severity: AlertSeverity.info,
            category: AlertCategory.weather,
            raisedAt: now,
          ),
        );
      }

      final strongWind =
          weather.daily.isNotEmpty && weather.daily.first.windMaxKph >= 40;
      if (strongWind) {
        alerts.add(
          FarmAlert(
            id: 'wind',
            title: 'Strong wind forecast',
            message:
                'Gusts up to ${weather.daily.first.windMaxKph.round()} km/h. '
                'Stake tall crops and postpone any spraying.',
            severity: AlertSeverity.info,
            category: AlertCategory.weather,
            raisedAt: now,
          ),
        );
      }
    }

    // --- Crop tasks --------------------------------------------------------
    final overdue = tasks.where((t) => t.isOverdue).toList();
    if (overdue.isNotEmpty) {
      alerts.add(
        FarmAlert(
          id: 'tasks_overdue',
          title:
              '${overdue.length} overdue farm ${overdue.length == 1 ? "task" : "tasks"}',
          message: overdue
              .take(3)
              .map((t) => '${t.cropName}: ${t.title}')
              .join('\n'),
          severity: AlertSeverity.info,
          category: AlertCategory.crop,
          raisedAt: now,
        ),
      );
    }

    alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return alerts;
  }

  /// How long the pump has been on without interruption, from the tail of the
  /// reading history.
  static Duration _continuousPumpRuntime(List<SensorReading> history) {
    if (history.isEmpty || !history.last.pumpOn) return Duration.zero;

    var start = history.last.timestamp;
    for (var i = history.length - 1; i >= 0; i--) {
      if (!history[i].pumpOn) break;
      start = history[i].timestamp;
    }
    return DateTime.now().difference(start);
  }

  static String _humanMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hour' : '$hours hours';
  }

  static String _humanDuration(Duration d) {
    // Automatic cycles are only seconds long, so minutes alone would render
    // the controller's intended duration as "0 min".
    if (d.inMinutes < 1) return '${d.inSeconds} sec';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return mins == 0 ? '$hours h' : '$hours h $mins min';
  }
}

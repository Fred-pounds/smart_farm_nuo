// A point-in-time soil moisture sample, logged to `/farm/history` so the app
// can draw trends without any firmware change.

class SensorReading {
  final DateTime timestamp;
  final int soilMoisture;
  final bool pumpOn;

  const SensorReading({
    required this.timestamp,
    required this.soilMoisture,
    required this.pumpOn,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestamp.millisecondsSinceEpoch,
    'moisture': soilMoisture,
    'pump': pumpOn,
  };

  factory SensorReading.fromJson(Map<dynamic, dynamic> json) => SensorReading(
    timestamp: DateTime.fromMillisecondsSinceEpoch((json['ts'] as num).toInt()),
    soilMoisture: (json['moisture'] as num?)?.toInt() ?? 0,
    pumpOn: json['pump'] as bool? ?? false,
  );
}

/// Aggregated water-usage figures derived from the reading history.
class IrrigationStats {
  final Duration runtimeToday;
  final Duration runtimeThisWeek;
  final int cyclesToday;

  /// Estimated litres, from runtime × the configured pump flow rate.
  final double litresToday;
  final double litresThisWeek;

  const IrrigationStats({
    required this.runtimeToday,
    required this.runtimeThisWeek,
    required this.cyclesToday,
    required this.litresToday,
    required this.litresThisWeek,
  });

  static const IrrigationStats empty = IrrigationStats(
    runtimeToday: Duration.zero,
    runtimeThisWeek: Duration.zero,
    cyclesToday: 0,
    litresToday: 0,
    litresThisWeek: 0,
  );
}

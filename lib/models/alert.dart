// Farm alerts, derived on the fly from sensor state + weather rather than
// stored anywhere.

enum AlertSeverity { info, warning, critical }

enum AlertCategory { soil, pump, sensor, weather, crop }

class FarmAlert {
  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final AlertCategory category;
  final DateTime raisedAt;

  /// Optional one-tap remedy, e.g. "Turn pump on".
  final String? actionLabel;

  const FarmAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.category,
    required this.raisedAt,
    this.actionLabel,
  });
}

/// The recommendation the irrigation advisor produces by fusing soil moisture
/// with the rain forecast.
enum IrrigationVerdict { irrigateNow, holdForRain, soilIsMoist, sensorUnknown }

class IrrigationAdvice {
  final IrrigationVerdict verdict;
  final String headline;
  final String reasoning;

  /// Litres of irrigation avoided by deferring to forecast rain — null when
  /// nothing is being saved.
  final double? litresSaved;

  /// Threshold the advisor suggests writing to the ESP32, if different from
  /// the current one.
  final int? suggestedThreshold;

  const IrrigationAdvice({
    required this.verdict,
    required this.headline,
    required this.reasoning,
    this.litresSaved,
    this.suggestedThreshold,
  });
}

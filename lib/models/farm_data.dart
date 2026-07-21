class FarmData {
  final String mode;
  final bool pump;
  final bool pumpStatus;
  final int soilMoisture;
  final int threshold;

  const FarmData({
    required this.mode,
    required this.pump,
    required this.pumpStatus,
    required this.soilMoisture,
    required this.threshold,
  });

  static const FarmData initial = FarmData(
    mode: 'manual',
    pump: false,
    pumpStatus: false,
    soilMoisture: 0,
    threshold: 1800,
  );

  bool get isAutomatic => mode == 'automatic';
  bool get isDry => soilMoisture > threshold;

  FarmData copyWith({
    String? mode,
    bool? pump,
    bool? pumpStatus,
    int? soilMoisture,
    int? threshold,
  }) {
    return FarmData(
      mode: mode ?? this.mode,
      pump: pump ?? this.pump,
      pumpStatus: pumpStatus ?? this.pumpStatus,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      threshold: threshold ?? this.threshold,
    );
  }
}

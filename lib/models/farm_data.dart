/// What the irrigation controller is doing and why, as published to
/// `/farm` by the ESP32.
///
/// Field roles differ and must not be blurred:
///
/// * `pump` is the **command** the app last wrote.
/// * `pumpStatus` is the **measured** relay state. Only this may be presented
///   as the pump's state.
/// * `soilMoisture`, `temperature`, `humidity` are sensor measurements.
/// * `irrigationDurationMs` and `irrigationReason` are the controller's own
///   account of its decision — useful, but authored on the device.
/// * `rainExpected` / `rainProbability` are written *by the app* and read by
///   the controller. They are the only fields that travel in that direction.
class FarmData {
  final String mode;
  final bool pump;
  final bool pumpStatus;

  final int soilMoisture;
  final int threshold;

  /// Air temperature in °C from the DHT11, or null before the first reading.
  final double? temperature;

  /// Relative humidity in % from the DHT11, or null before the first reading.
  final double? humidity;

  /// How long the controller intends to run the pump, in milliseconds.
  final int irrigationDurationMs;

  /// The controller's own explanation, verbatim. Device-authored text, so it
  /// is never rendered as-is where an unexpected value would confuse; use
  /// [reason] for a value the UI can switch on safely.
  final String irrigationReason;

  /// The rain outlook the app published for the controller to act on.
  final bool rainExpected;
  final int rainProbability;

  const FarmData({
    required this.mode,
    required this.pump,
    required this.pumpStatus,
    required this.soilMoisture,
    required this.threshold,
    this.temperature,
    this.humidity,
    this.irrigationDurationMs = 0,
    this.irrigationReason = '',
    this.rainExpected = false,
    this.rainProbability = 0,
  });

  static const FarmData initial = FarmData(
    mode: 'manual',
    pump: false,
    pumpStatus: false,
    soilMoisture: 0,
    threshold: 1800,
  );

  bool get isAutomatic => mode == 'automatic';

  /// The soil sensor reads *higher* when drier, so dry is above threshold.
  ///
  /// Only meaningful when [hasPlausibleSoil]; a disconnected probe reads 0,
  /// which would otherwise be reported as thoroughly wet soil.
  bool get isDry => soilMoisture > threshold;

  /// The readings a capacitive probe on a 12-bit ADC can physically produce.
  ///
  /// 0 means the probe is disconnected or shorted, not saturated. Values at
  /// the top of the range mean it is sitting in air. Both are hardware
  /// faults, and neither may be translated into advice about the soil.
  static const int soilFloor = 1;
  static const int soilCeiling = 4000;

  bool get hasPlausibleSoil =>
      soilMoisture >= soilFloor && soilMoisture <= soilCeiling;

  bool get hasClimateReading => temperature != null && humidity != null;

  Duration get irrigationDuration =>
      Duration(milliseconds: irrigationDurationMs);

  /// The controller's stated reason, mapped onto a closed set the UI can rely
  /// on. Anything unrecognised becomes [IrrigationReason.unknown] rather than
  /// being trusted — the firmware's vocabulary may change without the app.
  IrrigationReason get reason => IrrigationReason.parse(irrigationReason);

  FarmData copyWith({
    String? mode,
    bool? pump,
    bool? pumpStatus,
    int? soilMoisture,
    int? threshold,
    double? temperature,
    double? humidity,
    int? irrigationDurationMs,
    String? irrigationReason,
    bool? rainExpected,
    int? rainProbability,
  }) {
    return FarmData(
      mode: mode ?? this.mode,
      pump: pump ?? this.pump,
      pumpStatus: pumpStatus ?? this.pumpStatus,
      soilMoisture: soilMoisture ?? this.soilMoisture,
      threshold: threshold ?? this.threshold,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      irrigationDurationMs: irrigationDurationMs ?? this.irrigationDurationMs,
      irrigationReason: irrigationReason ?? this.irrigationReason,
      rainExpected: rainExpected ?? this.rainExpected,
      rainProbability: rainProbability ?? this.rainProbability,
    );
  }
}

/// The controller's irrigation state, translated from the firmware's strings.
///
/// The firmware writes free text (`"Hot/Dry"`, `"Soil Wet"`, …). Matching on
/// those strings all over the UI would scatter the firmware's vocabulary
/// through the app and break silently when it changes, so the translation
/// happens exactly once, here.
enum IrrigationReason {
  waiting,
  soilWet,
  cooldown,
  hotDry,
  hot,
  normal,
  coolHumid,
  rainExpected,
  done,
  manualOn,
  manualOff,
  unknown;

  static IrrigationReason parse(String raw) {
    return switch (raw.trim()) {
      'Waiting' => waiting,
      'Soil Wet' => soilWet,
      'Cooldown' => cooldown,
      'Hot/Dry' => hotDry,
      'Hot' => hot,
      'Normal' => normal,
      'Cool/Humid' => coolHumid,
      'Rain Expected' => rainExpected,
      'Irrigation Done' => done,
      'Manual ON' => manualOn,
      'Manual OFF' => manualOff,
      _ => unknown,
    };
  }

  /// A farmer-facing sentence explaining what the controller is doing.
  String get explanation => switch (this) {
    waiting => 'The controller is starting up and has not decided yet.',
    soilWet => 'The soil has enough water, so the pump is off.',
    cooldown =>
      'The soil is dry, but the controller is waiting between cycles to '
          'let the last watering soak in before judging again.',
    hotDry =>
      'Hot and dry air, so the controller is watering for longer than '
          'usual to offset fast evaporation.',
    hot => 'Warm air, so the controller extended the watering time.',
    normal => 'Ordinary conditions — a standard watering cycle.',
    coolHumid =>
      'Cool, humid air means water evaporates slowly, so a shorter cycle '
          'is enough.',
    rainExpected =>
      'The soil is dry, but rain is forecast, so watering is being held '
          'back to save water.',
    done => 'The watering cycle finished.',
    manualOn => 'You are running the pump by hand.',
    manualOff => 'The pump is off under your manual control.',
    unknown => 'The controller reported a state this app does not know.',
  };

  /// Short label for dense UI.
  String get label => switch (this) {
    waiting => 'Starting up',
    soilWet => 'Soil has enough water',
    cooldown => 'Waiting between cycles',
    hotDry => 'Hot and dry — longer cycle',
    hot => 'Warm — extended cycle',
    normal => 'Standard cycle',
    coolHumid => 'Cool and humid — short cycle',
    rainExpected => 'Holding back for rain',
    done => 'Watering finished',
    manualOn => 'Manual control — running',
    manualOff => 'Manual control — off',
    unknown => 'Unrecognised state',
  };
}

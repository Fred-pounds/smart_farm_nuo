import '../models/weather.dart';

/// How urgent a signal is. Drives colour and ordering, never wording.
enum SignalLevel {
  /// Conditions favour the work. Nothing to do.
  good,

  /// Worth planning around today.
  watch,

  /// Do something, or deliberately choose not to.
  act,
}

/// One farming decision the forecast has an opinion about.
///
/// [value] is the answer at a glance — "Hold off", "High", "Good now". [detail]
/// is the number behind it. Both are needed: a card that only says "High" is
/// unactionable, and one that only prints the humidity makes the farmer do the
/// agronomy.
class FarmingSignal {
  /// The decision, not the measurement: "Irrigation", not "Rainfall".
  final String title;

  final String value;
  final String detail;
  final SignalLevel level;

  const FarmingSignal({
    required this.title,
    required this.value,
    required this.detail,
    required this.level,
  });
}

/// Turns a forecast into the four decisions a farmer makes from one.
///
/// Extracted from the Weather screen so the thresholds are testable without a
/// widget tree, and so the same judgement can be reused elsewhere — the
/// project keeps decision logic in `logic/` for exactly this reason.
///
/// Every threshold here is carried over unchanged from the previous
/// implementation. They are agronomic, not stylistic, and a redesign is not
/// the place to quietly move the line at which the app says "do not spray".
class WeatherAdvisor {
  const WeatherAdvisor._();

  /// Rain in 24 h at or above this is enough to skip irrigation entirely.
  static const double heavyRainMm = 10;

  /// Below this, rain will not meaningfully water the field.
  static const double usefulRainMm = 3;

  /// Reference evapotranspiration above this is a heavy-loss day.
  static const double highEt0Mm = 5;

  /// Spray drift becomes wasteful and hits neighbouring crops above this.
  static const double sprayWindLimitKph = 20;

  /// The four cards, always in this order, always all four present.
  ///
  /// A card that disappears when conditions are fine is a card a farmer
  /// cannot learn the position of, and its absence is ambiguous — no disease
  /// warning could mean low risk or could mean the humidity reading failed.
  static List<FarmingSignal> signals(WeatherReport report) => [
    irrigation(report),
    rain(report),
    disease(report),
    spray(report),
  ];

  static FarmingSignal irrigation(WeatherReport report) {
    final rain24 = report.rainfallInNextHours(24);
    final et0 = report.daily.isNotEmpty ? report.daily.first.et0Mm : 0.0;

    if (rain24 >= heavyRainMm) {
      return FarmingSignal(
        title: 'Irrigation',
        value: 'Hold off',
        detail:
            '${rain24.toStringAsFixed(1)} mm expected in 24 h. Check your '
            'drainage instead.',
        level: SignalLevel.good,
      );
    }
    if (rain24 >= usefulRainMm) {
      return FarmingSignal(
        title: 'Irrigation',
        value: 'Top up only',
        detail:
            'Light rain (${rain24.toStringAsFixed(1)} mm) will help, but '
            'sandy soil will still need water.',
        level: SignalLevel.watch,
      );
    }
    if (et0 >= highEt0Mm) {
      return FarmingSignal(
        title: 'Irrigation',
        value: 'Needed',
        detail:
            'No useful rain, and high water loss today (ET₀ '
            '${et0.toStringAsFixed(1)} mm) — about ${(et0 * 10).round()} '
            'litres per 10 m² to break even.',
        level: SignalLevel.act,
      );
    }
    return FarmingSignal(
      title: 'Irrigation',
      value: 'On you',
      detail:
          'Little to no rain in the next 24 hours. Normal irrigation should '
          'keep up (ET₀ ${et0.toStringAsFixed(1)} mm).',
      level: SignalLevel.watch,
    );
  }

  static FarmingSignal rain(WeatherReport report) {
    final rain24 = report.rainfallInNextHours(24);
    final chance = report.peakRainChanceInNextHours(24);

    if (rain24 >= heavyRainMm) {
      return FarmingSignal(
        title: 'Rain',
        value: '${rain24.round()} mm',
        detail: 'Heavy rain likely in 24 h · $chance% peak chance.',
        level: SignalLevel.watch,
      );
    }
    if (rain24 >= usefulRainMm) {
      return FarmingSignal(
        title: 'Rain',
        value: '${rain24.toStringAsFixed(1)} mm',
        detail: 'Light rain in the next 24 h · $chance% peak chance.',
        level: SignalLevel.good,
      );
    }
    return FarmingSignal(
      title: 'Rain',
      value: chance >= 30 ? 'Possible' : 'Unlikely',
      detail:
          '${rain24.toStringAsFixed(1)} mm expected in 24 h · $chance% peak '
          'chance.',
      level: SignalLevel.good,
    );
  }

  static FarmingSignal disease(WeatherReport report) {
    final humidity = report.current.humidity;
    final temp = report.current.temperatureC;

    // Blight and mildew need warmth and sustained leaf wetness. Outside this
    // band the same humidity is not a risk, which is why both halves are
    // required.
    if (humidity >= 80 && temp >= 18 && temp <= 30) {
      return FarmingSignal(
        title: 'Disease risk',
        value: 'High',
        detail:
            '${humidity.round()}% humidity at ${temp.round()}°C suits blight '
            'and mildew. Scout tomato and pepper leaves today.',
        level: SignalLevel.act,
      );
    }
    if (humidity >= 70) {
      return FarmingSignal(
        title: 'Disease risk',
        value: 'Moderate',
        detail:
            '${humidity.round()}% humidity at ${temp.round()}°C. Watch for '
            'leaf spots if it stays damp.',
        level: SignalLevel.watch,
      );
    }
    return FarmingSignal(
      title: 'Disease risk',
      value: 'Low',
      detail:
          '${humidity.round()}% humidity at ${temp.round()}°C is too dry for '
          'the usual fungal pressure.',
      level: SignalLevel.good,
    );
  }

  static FarmingSignal spray(WeatherReport report) {
    final wind = report.current.windKph;
    final rain24 = report.rainfallInNextHours(24);

    if (wind >= sprayWindLimitKph) {
      return FarmingSignal(
        title: 'Spray window',
        value: 'Postpone',
        detail:
            'Wind at ${wind.round()} km/h will carry drift onto neighbouring '
            'crops and waste the chemical.',
        level: SignalLevel.act,
      );
    }
    if (rain24 >= usefulRainMm) {
      return FarmingSignal(
        title: 'Spray window',
        value: 'Wash-out risk',
        detail:
            '${rain24.toStringAsFixed(1)} mm of rain expected within 24 h '
            'could wash the application off.',
        level: SignalLevel.watch,
      );
    }
    return FarmingSignal(
      title: 'Spray window',
      value: 'Good now',
      detail:
          'Light wind (${wind.round()} km/h) and no wash-out rain expected.',
      level: SignalLevel.good,
    );
  }

  /// A heat-stress line, or null when there is no heat to report.
  ///
  /// Kept out of the four cards because it is seasonal rather than daily —
  /// most days it would be an empty box in the grid.
  static String? heatNote(WeatherReport report) {
    final temp = report.current.temperatureC;
    if (temp < 35) return null;
    return 'Heat stress at ${temp.round()}°C. Irrigate before 8 a.m. or after '
        '5 p.m. — midday water mostly evaporates.';
  }

  /// The week in one sentence.
  static String weekNote(WeatherReport report) {
    return '${report.totalRainfallNext7Days.toStringAsFixed(0)} mm of rain '
        'forecast over the next 7 days, averaging '
        '${report.averageMaxTempNext7Days.round()}°C daytime highs.';
  }
}

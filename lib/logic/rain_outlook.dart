import '../models/weather.dart';

/// The near-term rain outlook, condensed to the two facts the irrigation
/// controller acts on.
class RainOutlook {
  /// Enough rain, confidently enough forecast, to be worth skipping a cycle.
  final bool rainExpected;

  /// Peak chance of rain across the look-ahead window, 0–100.
  final int probability;

  /// Total rainfall expected across the window, in mm.
  final double millimetres;

  /// When rain first appears in the window, if it does.
  final HourlyForecast? firstRainHour;

  /// False when no forecast was available. A `rainExpected` of false with
  /// `isKnown` false means "we don't know", not "it will be dry" — and the
  /// difference decides whether it is safe to publish.
  final bool isKnown;

  const RainOutlook({
    required this.rainExpected,
    required this.probability,
    required this.millimetres,
    required this.isKnown,
    this.firstRainHour,
  });

  static const RainOutlook unknown = RainOutlook(
    rainExpected: false,
    probability: 0,
    millimetres: 0,
    isKnown: false,
  );
}

/// Turns a forecast into the irrigation-relevant rain outlook.
///
/// This is the *single* definition of "rain is coming" in the system. The
/// advice shown to the farmer and the value written to
/// `/farm/weather/rainExpected` both come from here, so the app can never
/// explain one thing while the controller does another.
class RainForecaster {
  const RainForecaster._();

  /// Rain below this over the window will not replace an irrigation cycle.
  static const double meaningfulRainMm = 3.0;

  /// Minimum forecast confidence before irrigation is deferred.
  ///
  /// Must stay in step with `RAIN_PROBABILITY_LIMIT` in the ESP32 firmware.
  /// The controller applies the same cut-off to the value published here, so
  /// if these disagree the pump and the app disagree.
  static const int minConfidence = 60;

  /// How far ahead to look for rain that could replace this cycle.
  ///
  /// Longer than the controller's own cycle, short enough that the forecast
  /// is still trustworthy.
  static const int lookAheadHours = 12;

  static RainOutlook forecast(WeatherReport? report) {
    if (report == null) return RainOutlook.unknown;

    final mm = report.rainfallInNextHours(lookAheadHours);
    final chance = report.peakRainChanceInNextHours(lookAheadHours);

    return RainOutlook(
      rainExpected: mm >= meaningfulRainMm && chance >= minConfidence,
      probability: chance,
      millimetres: mm,
      firstRainHour: report.nextRainHour,
      isKnown: true,
    );
  }
}

/// What, if anything, to write to `/farm/weather` for the controller.
class WeatherPublication {
  final bool shouldWrite;
  final bool rainExpected;
  final int rainProbability;

  /// Why nothing is being written, for logging and for the UI to explain the
  /// weather layer's status honestly.
  final String? skipReason;

  const WeatherPublication({
    required this.shouldWrite,
    this.rainExpected = false,
    this.rainProbability = 0,
    this.skipReason,
  });
}

/// Decides what rain outlook the app should hand the controller.
///
/// The ESP32 cannot fetch a forecast; it only reads two fields the app
/// maintains. That makes the app responsible not just for writing them, but
/// for **not leaving a stale value in place**: a `rainExpected: true` left
/// over from yesterday would suppress irrigation indefinitely, with no way
/// for the controller to know the value had expired.
///
/// So the rules are asymmetric on purpose. A fresh forecast is published as
/// it stands. A forecast that has gone stale retracts a standing "rain is
/// coming" back to false, because the failure that lets a crop dry out is
/// worse than the one that waters unnecessarily.
class WeatherPublisher {
  const WeatherPublisher._();

  /// Beyond this age a forecast is no longer allowed to hold back irrigation.
  static const Duration maxAge = Duration(hours: 3);

  static const String staleRetraction =
      'Forecast is too old to hold back irrigation; cleared the rain delay.';
  static const String noForecast =
      'No forecast available, and no rain delay is standing.';
  static const String upToDate = 'The controller already has this outlook.';

  static WeatherPublication decide({
    required WeatherReport? report,
    required DateTime now,
    required bool currentRainExpected,
    required int currentProbability,
  }) {
    final outlook = RainForecaster.forecast(report);
    final isFresh =
        report != null &&
        now.difference(report.fetchedAt) <= maxAge &&
        outlook.isKnown;

    if (!isFresh) {
      // Only intervene if a stale delay is actually suppressing irrigation.
      if (currentRainExpected) {
        return const WeatherPublication(
          shouldWrite: true,
          rainExpected: false,
          rainProbability: 0,
          skipReason: staleRetraction,
        );
      }
      return const WeatherPublication(
        shouldWrite: false,
        skipReason: noForecast,
      );
    }

    final unchanged =
        outlook.rainExpected == currentRainExpected &&
        outlook.probability == currentProbability;
    if (unchanged) {
      return WeatherPublication(
        shouldWrite: false,
        rainExpected: outlook.rainExpected,
        rainProbability: outlook.probability,
        skipReason: upToDate,
      );
    }

    return WeatherPublication(
      shouldWrite: true,
      rainExpected: outlook.rainExpected,
      rainProbability: outlook.probability,
    );
  }
}

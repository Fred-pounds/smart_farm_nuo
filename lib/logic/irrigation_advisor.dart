import '../models/alert.dart';
import '../models/farm_data.dart';
import '../models/weather.dart';
import 'rain_outlook.dart';

/// Fuses the ESP32 soil reading with the rain forecast to decide whether
/// watering right now is actually worth it.
///
/// The dashboard alone can only say "soil is dry". This adds the question the
/// farmer really cares about: *is it going to rain before it matters?*
class IrrigationAdvisor {
  const IrrigationAdvisor._();

  /// The look-ahead window, named locally for readability in the prose below.
  ///
  /// The rain thresholds themselves live in [RainForecaster], which is also
  /// what gets published to the controller — so the advice on screen and the
  /// controller's decision are always the same judgement.
  static const int _lookAheadHours = RainForecaster.lookAheadHours;

  static IrrigationAdvice advise({
    required FarmData farm,
    required WeatherReport? weather,
    required double fieldAreaSqm,
    required bool hasLiveData,
  }) {
    if (!hasLiveData) {
      return const IrrigationAdvice(
        verdict: IrrigationVerdict.sensorUnknown,
        headline: 'Waiting for sensor data',
        reasoning:
            'No reading has arrived from the ESP32 yet. Check that the board '
            'is powered and connected to Wi-Fi.',
      );
    }

    // A reading the probe cannot physically produce is a hardware fault, and
    // advising on it would be worse than saying nothing: reading 0 as
    // "thoroughly wet" tells a farmer to withhold water from dry soil.
    if (!farm.hasPlausibleSoil) {
      return IrrigationAdvice(
        verdict: IrrigationVerdict.sensorUnknown,
        headline: 'Soil sensor not reporting properly',
        reasoning:
            'The probe is reading ${farm.soilMoisture}, which it cannot '
            'produce from soil. Check the probe wiring at the controller. '
            'Until it reports a real value, irrigation advice is unavailable.',
      );
    }

    final outlook = RainForecaster.forecast(weather);
    final rainMm = outlook.millimetres;
    final rainChance = outlook.probability;
    final nextRain = outlook.firstRainHour;
    final rainIsComing = outlook.rainExpected;

    if (farm.isDry) {
      if (rainIsComing) {
        // 1 mm of rain over 1 m² delivers 1 litre.
        final litresSaved = rainMm * fieldAreaSqm;
        return IrrigationAdvice(
          verdict: IrrigationVerdict.holdForRain,
          headline: 'Hold irrigation — rain is coming',
          reasoning:
              'Soil is dry (${farm.soilMoisture} vs threshold ${farm.threshold}), '
              'but ${rainMm.toStringAsFixed(1)} mm of rain is forecast '
              '${_whenPhrase(nextRain)} at $rainChance% confidence. '
              'Waiting saves the water and the pump runtime.',
          litresSaved: litresSaved,
        );
      }

      return IrrigationAdvice(
        verdict: IrrigationVerdict.irrigateNow,
        headline: 'Irrigate now',
        reasoning: _dryReasoning(farm, weather, rainChance),
        suggestedThreshold: _heatAdjustedThreshold(farm, weather),
      );
    }

    // Soil is already moist.
    if (rainIsComing && rainMm > 20) {
      return IrrigationAdvice(
        verdict: IrrigationVerdict.soilIsMoist,
        headline: 'No watering needed — heavy rain expected',
        reasoning:
            'Soil moisture is adequate and ${rainMm.toStringAsFixed(1)} mm of '
            'rain is forecast within $_lookAheadHours hours. Check that your '
            'drainage channels are clear.',
      );
    }

    return IrrigationAdvice(
      verdict: IrrigationVerdict.soilIsMoist,
      headline: 'No watering needed',
      reasoning:
          'Soil moisture (${farm.soilMoisture}) is below the dry threshold of '
          '${farm.threshold}. The crop has enough water for now.',
      suggestedThreshold: _heatAdjustedThreshold(farm, weather),
    );
  }

  static String _dryReasoning(
    FarmData farm,
    WeatherReport? weather,
    int rainChance,
  ) {
    final base =
        'Soil reading ${farm.soilMoisture} is above the dry threshold of '
        '${farm.threshold}.';

    if (weather == null) {
      return '$base No forecast available, so irrigate on the sensor alone.';
    }

    final et0 = weather.daily.isNotEmpty ? weather.daily.first.et0Mm : 0.0;
    final heat = weather.current.temperatureC;

    final buffer = StringBuffer(base);
    if (rainChance < 20) {
      buffer.write(' No rain expected in the next $_lookAheadHours hours.');
    } else {
      buffer.write(
        ' Rain chance is only $rainChance% — not reliable enough to wait for.',
      );
    }
    if (et0 >= 5) {
      buffer.write(
        ' Evapotranspiration is high today (${et0.toStringAsFixed(1)} mm), '
        'so the soil will dry out fast.',
      );
    }
    if (heat >= 33) {
      buffer.write(
        ' Water early morning or evening — midday irrigation at '
        '${heat.round()}°C mostly evaporates.',
      );
    }
    return buffer.toString();
  }

  /// Suggests a lower (wetter) threshold during hot, high-evaporation spells
  /// so the pump triggers before the crop is stressed.
  static int? _heatAdjustedThreshold(FarmData farm, WeatherReport? weather) {
    if (weather == null || weather.daily.isEmpty) return null;
    final et0 = weather.daily.first.et0Mm;
    if (et0 < 5.5) return null;

    final suggested = farm.threshold - 150;
    return suggested < 800 ? null : suggested;
  }

  static String _whenPhrase(HourlyForecast? next) {
    if (next == null) return 'soon';
    final hours = next.time.difference(DateTime.now()).inHours;
    if (hours <= 0) return 'within the hour';
    if (hours == 1) return 'in about 1 hour';
    return 'in about $hours hours';
  }
}

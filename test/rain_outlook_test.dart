import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/rain_outlook.dart';
import 'package:smart_farm/models/farm_data.dart';
import 'package:smart_farm/models/weather.dart';

/// The app is the only component that can tell the ESP32 rain is coming, and
/// `rainExpected` suppresses irrigation outright. Both directions matter: a
/// missed publication wastes water, a stale one starves the crop.
WeatherReport _report({
  required double mmPerHour,
  required int probability,
  int rainHours = 6,
  DateTime? fetchedAt,
}) {
  final now = DateTime.now();
  return WeatherReport(
    current: CurrentWeather(
      temperatureC: 28,
      feelsLikeC: 30,
      humidity: 60,
      windKph: 10,
      precipitationMm: 0,
      condition: WeatherCondition.cloudy,
      isDay: true,
      observedAt: now,
    ),
    hourly: List.generate(24, (i) {
      final raining = i < rainHours;
      return HourlyForecast(
        time: now.add(Duration(hours: i + 1)),
        temperatureC: 28,
        precipitationMm: raining ? mmPerHour : 0,
        precipitationProbability: raining ? probability : 0,
        condition: WeatherCondition.cloudy,
      );
    }),
    daily: const [],
    locationName: 'Test Farm',
    fetchedAt: fetchedAt ?? now,
  );
}

void main() {
  group('RainForecaster', () {
    test('expects rain when it is both meaningful and confident', () {
      final outlook = RainForecaster.forecast(
        _report(mmPerHour: 2, probability: 80),
      );

      expect(outlook.rainExpected, isTrue);
      expect(outlook.probability, 80);
      expect(outlook.isKnown, isTrue);
    });

    test('ignores rain that is forecast but not confident enough', () {
      final outlook = RainForecaster.forecast(
        _report(mmPerHour: 5, probability: 40),
      );

      expect(outlook.rainExpected, isFalse);
    });

    test('ignores a confident forecast of barely any rain', () {
      final outlook = RainForecaster.forecast(
        _report(mmPerHour: 0.1, probability: 95, rainHours: 2),
      );

      expect(outlook.rainExpected, isFalse);
    });

    test('distinguishes "no rain" from "no forecast"', () {
      final none = RainForecaster.forecast(null);

      expect(none.rainExpected, isFalse);
      expect(
        none.isKnown,
        isFalse,
        reason: 'an absent forecast must not read as a dry outlook',
      );
    });

    test('confidence cut-off matches the firmware limit', () {
      // The ESP32 applies RAIN_PROBABILITY_LIMIT to the published value. If
      // these drift apart the app explains one thing and the pump does
      // another.
      expect(RainForecaster.minConfidence, 60);
    });
  });

  group('WeatherPublisher', () {
    final now = DateTime(2026, 8, 12, 10, 0, 0);

    test('publishes a fresh outlook the controller does not have yet', () {
      final decision = WeatherPublisher.decide(
        report: _report(mmPerHour: 2, probability: 80),
        now: now,
        currentRainExpected: false,
        currentProbability: 0,
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.rainExpected, isTrue);
      expect(decision.rainProbability, 80);
    });

    test('does not rewrite an outlook the controller already has', () {
      final decision = WeatherPublisher.decide(
        report: _report(mmPerHour: 2, probability: 80),
        now: now,
        currentRainExpected: true,
        currentProbability: 80,
      );

      expect(decision.shouldWrite, isFalse);
      expect(decision.skipReason, WeatherPublisher.upToDate);
    });

    test('retracts a stale rain delay so irrigation can resume', () {
      // The crop-killing failure: a "rain is coming" written hours ago that
      // no longer reflects reality, silently holding the pump off.
      final stale = _report(
        mmPerHour: 2,
        probability: 80,
        fetchedAt: now.subtract(const Duration(hours: 9)),
      );

      final decision = WeatherPublisher.decide(
        report: stale,
        now: now,
        currentRainExpected: true,
        currentProbability: 80,
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.rainExpected, isFalse);
      expect(decision.rainProbability, 0);
      expect(decision.skipReason, WeatherPublisher.staleRetraction);
    });

    test('retracts a standing delay when the forecast disappears entirely', () {
      final decision = WeatherPublisher.decide(
        report: null,
        now: now,
        currentRainExpected: true,
        currentProbability: 90,
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.rainExpected, isFalse);
    });

    test('stays silent when there is nothing to say and nothing to undo', () {
      final decision = WeatherPublisher.decide(
        report: null,
        now: now,
        currentRainExpected: false,
        currentProbability: 0,
      );

      expect(decision.shouldWrite, isFalse);
      expect(decision.skipReason, WeatherPublisher.noForecast);
    });

    test('updates the probability even when the flag is unchanged', () {
      final decision = WeatherPublisher.decide(
        report: _report(mmPerHour: 2, probability: 90),
        now: now,
        currentRainExpected: true,
        currentProbability: 70,
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.rainProbability, 90);
    });

    test('clears a delay once the rain drops out of the forecast', () {
      final decision = WeatherPublisher.decide(
        report: _report(mmPerHour: 0, probability: 10),
        now: now,
        currentRainExpected: true,
        currentProbability: 80,
      );

      expect(decision.shouldWrite, isTrue);
      expect(decision.rainExpected, isFalse);
    });
  });

  group('IrrigationReason', () {
    test('translates every state the firmware can publish', () {
      const fromFirmware = [
        'Waiting',
        'Soil Wet',
        'Cooldown',
        'Hot/Dry',
        'Hot',
        'Normal',
        'Cool/Humid',
        'Rain Expected',
        'Irrigation Done',
        'Manual ON',
        'Manual OFF',
      ];

      for (final raw in fromFirmware) {
        expect(
          IrrigationReason.parse(raw),
          isNot(IrrigationReason.unknown),
          reason: '"$raw" is written by the ESP32 and must be understood',
        );
      }
    });

    test('treats an unrecognised device string as unknown, not as a state', () {
      expect(
        IrrigationReason.parse('Ludicrous Speed'),
        IrrigationReason.unknown,
      );
      expect(IrrigationReason.parse(''), IrrigationReason.unknown);
    });

    test('every reason has farmer-facing wording', () {
      for (final reason in IrrigationReason.values) {
        expect(reason.label, isNotEmpty);
        expect(reason.explanation, isNotEmpty);
      }
    });
  });
}

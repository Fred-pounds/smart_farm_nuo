import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/weather_advice.dart';
import 'package:smart_farm/models/weather.dart';
import 'package:smart_farm/theme/gauges.dart';

/// Builds a forecast where the first [rainHours] hours carry [mmPerHour] of
/// rain at [probability]% confidence.
///
/// Mirrors the helper in `logic_test.dart` rather than sharing one, so a
/// change made for these tests cannot silently move the ground under the
/// irrigation advisor's suite.
WeatherReport _weather({
  double mmPerHour = 0,
  int probability = 0,
  int rainHours = 0,
  double tempC = 28,
  double et0 = 3,
  double windKph = 10,
  double humidity = 60,
}) {
  final now = DateTime.now();

  return WeatherReport(
    current: CurrentWeather(
      temperatureC: tempC,
      feelsLikeC: tempC,
      humidity: humidity,
      windKph: windKph,
      precipitationMm: 0,
      condition: WeatherCondition.clear,
      isDay: true,
      observedAt: now,
    ),
    hourly: List.generate(48, (i) {
      final isRainy = i < rainHours;
      return HourlyForecast(
        // Offset by 30 min so the first entry is unambiguously in the future.
        time: now.add(Duration(minutes: 30 + i * 60)),
        temperatureC: tempC,
        precipitationMm: isRainy ? mmPerHour : 0,
        precipitationProbability: isRainy ? probability : 0,
        condition: isRainy ? WeatherCondition.rain : WeatherCondition.clear,
      );
    }),
    daily: List.generate(7, (i) {
      return DailyForecast(
        date: now.add(Duration(days: i)),
        maxTempC: tempC,
        minTempC: tempC - 8,
        precipitationMm: i == 0 ? mmPerHour * rainHours : 0,
        precipitationProbability: i == 0 ? probability : 0,
        windMaxKph: windKph,
        et0Mm: et0,
        condition: WeatherCondition.clear,
      );
    }),
    locationName: 'Test Farm',
    fetchedAt: now,
  );
}

void main() {
  group('WeatherAdvisor grid contract', () {
    test('always returns the four cards, in a fixed order', () {
      // The Weather screen lays these out as a 2x2 grid by index. A signal
      // that disappears in fine conditions would both break the layout and
      // make its absence ambiguous — no disease card could mean low risk, or
      // could mean the humidity reading failed.
      for (final report in [
        _weather(),
        _weather(mmPerHour: 4, probability: 90, rainHours: 6),
        _weather(humidity: 88, tempC: 24, windKph: 30),
      ]) {
        final signals = WeatherAdvisor.signals(report);
        expect(signals, hasLength(4));
        expect(
          signals.map((s) => s.title),
          ['Irrigation', 'Rain', 'Disease risk', 'Spray window'],
        );
        for (final signal in signals) {
          expect(signal.value, isNotEmpty);
          expect(signal.detail, isNotEmpty);
        }
      }
    });
  });

  group('WeatherAdvisor irrigation', () {
    test('heavy rain in 24 h means hold off', () {
      // 2 mm across 6 hours = 12 mm, over the 10 mm threshold.
      final signal = WeatherAdvisor.irrigation(
        _weather(mmPerHour: 2, probability: 90, rainHours: 6),
      );
      expect(signal.value, 'Hold off');
      expect(signal.level, SignalLevel.good);
    });

    test('light rain still needs a top-up on sandy soil', () {
      // 4 mm total: useful, but under the 10 mm skip threshold.
      final signal = WeatherAdvisor.irrigation(
        _weather(mmPerHour: 1, probability: 80, rainHours: 4),
      );
      expect(signal.value, 'Top up only');
      expect(signal.level, SignalLevel.watch);
    });

    test('no rain plus high evapotranspiration escalates to act', () {
      final signal = WeatherAdvisor.irrigation(_weather(et0: 6));
      expect(signal.value, 'Needed');
      expect(signal.level, SignalLevel.act);
      // The litres figure is the whole point of the card.
      expect(signal.detail, contains('60'));
    });

    test('no rain and ordinary evapotranspiration stays advisory', () {
      final signal = WeatherAdvisor.irrigation(_weather(et0: 3));
      expect(signal.value, 'On you');
      expect(signal.level, SignalLevel.watch);
    });
  });

  group('WeatherAdvisor disease risk', () {
    test('warm and humid is high risk', () {
      final signal = WeatherAdvisor.disease(
        _weather(humidity: 85, tempC: 24),
      );
      expect(signal.value, 'High');
      expect(signal.level, SignalLevel.act);
    });

    test('humid but too cold falls back to moderate', () {
      // Above 80% humidity, but outside the 18-30 C band blight needs.
      final signal = WeatherAdvisor.disease(
        _weather(humidity: 85, tempC: 12),
      );
      expect(signal.value, 'Moderate');
    });

    test('dry air is low risk regardless of heat', () {
      final signal = WeatherAdvisor.disease(
        _weather(humidity: 40, tempC: 28),
      );
      expect(signal.value, 'Low');
      expect(signal.level, SignalLevel.good);
    });
  });

  group('WeatherAdvisor spray window', () {
    test('wind outranks everything else', () {
      final signal = WeatherAdvisor.spray(_weather(windKph: 25));
      expect(signal.value, 'Postpone');
      expect(signal.level, SignalLevel.act);
    });

    test('calm but rainy warns about wash-out', () {
      final signal = WeatherAdvisor.spray(
        _weather(mmPerHour: 1, probability: 80, rainHours: 5, windKph: 8),
      );
      expect(signal.value, 'Wash-out risk');
    });

    test('calm and dry is a good window', () {
      final signal = WeatherAdvisor.spray(_weather(windKph: 8));
      expect(signal.value, 'Good now');
      expect(signal.level, SignalLevel.good);
    });
  });

  group('WeatherAdvisor heat note', () {
    test('is silent below the stress threshold', () {
      expect(WeatherAdvisor.heatNote(_weather(tempC: 30)), isNull);
    });

    test('names the hours to irrigate when it fires', () {
      final note = WeatherAdvisor.heatNote(_weather(tempC: 38));
      expect(note, isNotNull);
      expect(note, contains('38'));
    });
  });

  group('SoilScale', () {
    test('inverts the probe, which reads higher when drier', () {
      // The single most confusing fact about this hardware. A gauge that got
      // this backwards would show a full arc for bone-dry soil.
      expect(SoilScale.wetness(0), 1.0);
      expect(SoilScale.wetness(4095), 0.0);
      expect(SoilScale.wetness(1000), greaterThan(SoilScale.wetness(3000)));
    });

    test('clamps readings outside the ADC range', () {
      expect(SoilScale.wetness(-50), 1.0);
      expect(SoilScale.wetness(9999), 0.0);
    });

    test('reports whole percentages', () {
      expect(SoilScale.percent(4095), 0);
      expect(SoilScale.percent(0), 100);
    });
  });
}

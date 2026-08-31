import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/data/crop_database.dart';
import 'package:smart_farm/logic/alert_builder.dart';
import 'package:smart_farm/logic/crop_recommender.dart';
import 'package:smart_farm/logic/irrigation_advisor.dart';
import 'package:smart_farm/logic/pump_command_machine.dart';
import 'package:smart_farm/models/alert.dart';
import 'package:smart_farm/models/farm_data.dart';
import 'package:smart_farm/models/pump_command.dart';
import 'package:smart_farm/models/sensor_reading.dart';
import 'package:smart_farm/models/weather.dart';

/// Builds a forecast where every hour in [rainHours] carries [mmPerHour] of
/// rain at [probability]% confidence.
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

const _dry = FarmData(
  mode: 'automatic',
  pump: false,
  pumpStatus: false,
  soilMoisture: 2400,
  threshold: 1800,
);

const _moist = FarmData(
  mode: 'automatic',
  pump: false,
  pumpStatus: false,
  soilMoisture: 1200,
  threshold: 1800,
);

void main() {
  group('IrrigationAdvisor', () {
    test('advises irrigating when soil is dry and no rain is coming', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: _weather(),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.irrigateNow);
      expect(advice.litresSaved, isNull);
    });

    test('defers irrigation when meaningful rain is confidently forecast', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: _weather(mmPerHour: 2, probability: 85, rainHours: 4),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.holdForRain);
      // 8 mm over 100 m² is 800 litres.
      expect(advice.litresSaved, closeTo(800, 1));
    });

    test('ignores rain that is forecast but unlikely', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: _weather(mmPerHour: 2, probability: 25, rainHours: 4),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.irrigateNow);
    });

    test('ignores rain too light to replace a cycle', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: _weather(mmPerHour: 0.2, probability: 95, rainHours: 3),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.irrigateNow);
    });

    test('reports no watering needed when soil is already moist', () {
      final advice = IrrigationAdvisor.advise(
        farm: _moist,
        weather: _weather(),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.soilIsMoist);
    });

    test('falls back safely when no sensor data has arrived', () {
      final advice = IrrigationAdvisor.advise(
        farm: FarmData.initial,
        weather: _weather(),
        fieldAreaSqm: 100,
        hasLiveData: false,
      );

      expect(advice.verdict, IrrigationVerdict.sensorUnknown);
    });

    test('works without any weather data', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: null,
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.verdict, IrrigationVerdict.irrigateNow);
      expect(advice.suggestedThreshold, isNull);
    });

    test('suggests a wetter threshold during high evaporation', () {
      final advice = IrrigationAdvisor.advise(
        farm: _dry,
        weather: _weather(et0: 7),
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(advice.suggestedThreshold, lessThan(_dry.threshold));
    });
  });

  group('CropRecommender', () {
    test('returns every crop, ranked by score descending', () {
      final results = CropRecommender.recommend(soilMoistureRaw: 1800);

      expect(results.length, CropDatabase.crops.length);
      for (var i = 0; i < results.length - 1; i++) {
        expect(results[i].score, greaterThanOrEqualTo(results[i + 1].score));
      }
    });

    test('scores stay inside 0–100', () {
      final results = CropRecommender.recommend(
        soilMoistureRaw: 3900,
        weather: _weather(tempC: 42),
      );

      for (final r in results) {
        expect(r.score, inInclusiveRange(0, 100));
      }
    });

    test('penalises crops that are out of their temperature range', () {
      // Lettuce tops out at 28 °C; okra tolerates 40 °C.
      final hot = CropRecommender.recommend(
        soilMoistureRaw: 1800,
        weather: _weather(tempC: 38),
        now: DateTime(2026, 6, 15),
      );

      final lettuce = hot.firstWhere((r) => r.crop.id == 'lettuce');
      final okra = hot.firstWhere((r) => r.crop.id == 'okra');

      expect(lettuce.score, lessThan(okra.score));
      expect(lettuce.concerns, isNotEmpty);
    });

    test('rewards in-season planting over out-of-season', () {
      // Onion is planted Oct–Jan.
      final inSeason = CropRecommender.recommend(
        soilMoistureRaw: 1800,
        now: DateTime(2026, 11, 10),
      ).firstWhere((r) => r.crop.id == 'onion');

      final outOfSeason = CropRecommender.recommend(
        soilMoistureRaw: 1800,
        now: DateTime(2026, 5, 10),
      ).firstWhere((r) => r.crop.id == 'onion');

      expect(inSeason.score, greaterThan(outOfSeason.score));
    });

    test('every result carries at least one explanation', () {
      final results = CropRecommender.recommend(
        soilMoistureRaw: 1800,
        weather: _weather(),
      );

      for (final r in results) {
        expect(
          r.positives.isNotEmpty || r.concerns.isNotEmpty,
          isTrue,
          reason: '${r.crop.name} produced no reasons',
        );
      }
    });
  });

  group('AlertBuilder', () {
    List<SensorReading> pumpRunningFor(Duration duration) {
      final now = DateTime.now();
      final samples = duration.inMinutes ~/ 10;
      return List.generate(samples + 1, (i) {
        return SensorReading(
          timestamp: now.subtract(Duration(minutes: (samples - i) * 10)),
          soilMoisture: 2400,
          pumpOn: true,
        );
      });
    }

    test('raises a critical alert when disconnected', () {
      final alerts = AlertBuilder.build(
        farm: FarmData.initial,
        isConnected: false,
        weather: null,
        history: const [],
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'offline'), isTrue);
      expect(alerts.first.severity, AlertSeverity.critical);
    });

    test('flags dry soil and offers a manual remedy', () {
      final alerts = AlertBuilder.build(
        farm: _dry.copyWith(mode: 'manual'),
        isConnected: true,
        weather: null,
        history: const [],
        tasks: const [],
      );

      final dry = alerts.firstWhere((a) => a.id == 'soil_dry');
      expect(dry.actionLabel, 'Turn pump on');
    });

    test('offers no manual remedy in automatic mode', () {
      final alerts = AlertBuilder.build(
        farm: _dry,
        isConnected: true,
        weather: null,
        history: const [],
        tasks: const [],
      );

      expect(alerts.firstWhere((a) => a.id == 'soil_dry').actionLabel, isNull);
    });

    test('detects a pump stuck on beyond the runtime limit', () {
      final alerts = AlertBuilder.build(
        farm: _dry.copyWith(pumpStatus: true),
        isConnected: true,
        weather: null,
        history: pumpRunningFor(const Duration(hours: 3)),
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'pump_stuck'), isTrue);
    });

    test('does not flag a pump running within normal limits', () {
      final alerts = AlertBuilder.build(
        farm: _dry.copyWith(pumpStatus: true),
        isConnected: true,
        weather: null,
        history: pumpRunningFor(const Duration(minutes: 30)),
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'pump_stuck'), isFalse);
    });

    test('flags a commanded pump that never reports on', () {
      final alerts = AlertBuilder.build(
        farm: _moist.copyWith(mode: 'manual', pump: true),
        isConnected: true,
        weather: null,
        history: const [],
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'pump_not_responding'), isTrue);
    });

    test(
      'holds an automatic cycle to the duration the controller declared',
      () {
        // A 10-second cycle still running two minutes later is a stuck relay,
        // and must not wait for the two-hour ceiling to be reported.
        final farm = _moist.copyWith(
          mode: 'automatic',
          pumpStatus: true,
          irrigationDurationMs: 10000,
        );

        expect(
          AlertBuilder.overrunLimitFor(farm),
          lessThan(const Duration(minutes: 5)),
        );

        final now = DateTime.now();
        final alerts = AlertBuilder.build(
          farm: farm,
          isConnected: true,
          weather: null,
          history: [
            SensorReading(
              timestamp: now.subtract(const Duration(minutes: 2)),
              soilMoisture: 1200,
              pumpOn: true,
            ),
            SensorReading(timestamp: now, soilMoisture: 1200, pumpOn: true),
          ],
          tasks: const [],
        );

        expect(alerts.any((a) => a.id == 'pump_stuck'), isTrue);
      },
    );

    test('leaves manual running to the farmer, not the cycle length', () {
      final farm = _moist.copyWith(
        mode: 'manual',
        pumpStatus: true,
        irrigationDurationMs: 10000,
      );

      expect(
        AlertBuilder.overrunLimitFor(farm),
        AlertBuilder.maxContinuousRuntime,
      );
    });

    test('stays quiet while a pump command is still in flight', () {
      // The backend holds ON and the relay has not switched yet — that is a
      // normal command in progress, not a fault. Alerting here would cry wolf
      // on every single press.
      final inFlight = PumpCommandMachine.writeSucceeded(
        current: PumpCommandMachine.request(
          current: PumpCommandState.idle,
          desired: true,
          deviceState: false,
          now: DateTime.now(),
          isAutomatic: false,
          isConnected: true,
        ),
        now: DateTime.now(),
      );

      final alerts = AlertBuilder.build(
        farm: _moist.copyWith(mode: 'manual', pump: true),
        isConnected: true,
        weather: null,
        history: const [],
        tasks: const [],
        command: inFlight,
      );

      expect(alerts.any((a) => a.id == 'pump_not_responding'), isFalse);
    });

    test('flags an implausible zero sensor reading', () {
      final alerts = AlertBuilder.build(
        farm: FarmData.initial,
        isConnected: true,
        weather: null,
        history: const [],
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'sensor_zero'), isTrue);
    });

    test('warns about heavy rain', () {
      final alerts = AlertBuilder.build(
        farm: _moist,
        isConnected: true,
        weather: _weather(mmPerHour: 5, probability: 90, rainHours: 8),
        history: const [],
        tasks: const [],
      );

      expect(alerts.any((a) => a.id == 'heavy_rain'), isTrue);
    });

    test('stays quiet when everything is healthy', () {
      final alerts = AlertBuilder.build(
        farm: _moist,
        isConnected: true,
        weather: _weather(),
        history: const [],
        tasks: const [],
      );

      expect(alerts, isEmpty);
    });

    test('orders alerts most severe first', () {
      final alerts = AlertBuilder.build(
        farm: _dry.copyWith(pumpStatus: true),
        isConnected: true,
        weather: _weather(tempC: 38, et0: 7),
        history: pumpRunningFor(const Duration(hours: 3)),
        tasks: const [],
      );

      for (var i = 0; i < alerts.length - 1; i++) {
        expect(
          alerts[i].severity.index,
          greaterThanOrEqualTo(alerts[i + 1].severity.index),
        );
      }
    });
  });
}

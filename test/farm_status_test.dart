import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/farm_status.dart';
import 'package:smart_farm/logic/irrigation_advisor.dart';
import 'package:smart_farm/models/alert.dart';
import 'package:smart_farm/models/farm_data.dart';

/// The dashboard headline is the one sentence most farmers will ever read.
/// It must never be reassuring about something the app cannot vouch for.
void main() {
  const moist = FarmData(
    mode: 'automatic',
    pump: false,
    pumpStatus: false,
    soilMoisture: 1200,
    threshold: 1800,
  );

  const advice = IrrigationAdvice(
    verdict: IrrigationVerdict.soilIsMoist,
    headline: 'No watering needed',
    reasoning: 'Soil moisture is below the dry threshold.',
  );

  group('FarmData soil plausibility', () {
    test('a disconnected probe reading zero is not a measurement', () {
      expect(moist.copyWith(soilMoisture: 0).hasPlausibleSoil, isFalse);
    });

    test('a probe sitting in air is not a measurement', () {
      expect(moist.copyWith(soilMoisture: 4095).hasPlausibleSoil, isFalse);
    });

    test('ordinary readings are accepted', () {
      expect(moist.hasPlausibleSoil, isTrue);
      expect(moist.copyWith(soilMoisture: 2400).hasPlausibleSoil, isTrue);
    });
  });

  group('FarmStatusReporter', () {
    test('a zero reading reports a fault, never moist soil', () {
      // The exact bug this guards: soil 0 renders as "thoroughly wet", so the
      // app told a farmer to withhold water while its own alert said the
      // sensor was broken.
      final status = FarmStatusReporter.of(
        farm: moist.copyWith(soilMoisture: 0),
        isConnected: true,
        advice: advice,
      );

      expect(status.tone, FarmTone.fault);
      expect(status.headline, contains('fault'));
      expect(status.detail.toLowerCase(), isNot(contains('moist')));
    });

    test('losing the controller outranks any reading', () {
      final status = FarmStatusReporter.of(
        farm: moist,
        isConnected: false,
        advice: advice,
      );

      expect(status.tone, FarmTone.fault);
      expect(status.headline, 'Controller offline');
    });

    test('a running pump is reported as working', () {
      final status = FarmStatusReporter.of(
        farm: moist.copyWith(pumpStatus: true),
        isConnected: true,
        advice: advice,
      );

      expect(status.tone, FarmTone.working);
      expect(status.headline, 'Watering now');
    });

    test('moist soil settles', () {
      final status = FarmStatusReporter.of(
        farm: moist,
        isConnected: true,
        advice: advice,
      );

      expect(status.tone, FarmTone.settled);
      expect(status.headline, 'Soil is moist');
    });

    test('dry soil raises caution', () {
      final status = FarmStatusReporter.of(
        farm: moist.copyWith(soilMoisture: 2400),
        isConnected: true,
        advice: const IrrigationAdvice(
          verdict: IrrigationVerdict.irrigateNow,
          headline: 'Irrigate now',
          reasoning: 'Above threshold.',
        ),
      );

      expect(status.tone, FarmTone.caution);
      expect(status.headline, 'Soil is dry');
    });

    test('every status carries a headline and a supporting line', () {
      for (final connected in [true, false]) {
        for (final reading in [0, 1200, 2400, 4095]) {
          final status = FarmStatusReporter.of(
            farm: moist.copyWith(soilMoisture: reading),
            isConnected: connected,
            advice: advice,
          );
          expect(status.headline, isNotEmpty);
          expect(status.detail, isNotEmpty);
        }
      }
    });
  });

  group('IrrigationAdvisor sensor guard', () {
    test('refuses to advise on an implausible reading', () {
      final result = IrrigationAdvisor.advise(
        farm: moist.copyWith(soilMoisture: 0),
        weather: null,
        fieldAreaSqm: 100,
        hasLiveData: true,
      );

      expect(result.verdict, IrrigationVerdict.sensorUnknown);
      expect(result.headline.toLowerCase(), contains('sensor'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/farm_status.dart';
import 'package:smart_farm/logic/field_band.dart';
import 'package:smart_farm/logic/pump_command_machine.dart';
import 'package:smart_farm/models/alert.dart';
import 'package:smart_farm/models/farm_data.dart';
import 'package:smart_farm/models/pump_command.dart';

/// The band is the largest text on the Farm screen and the first thing read.
/// Its ordering rules are what stop it implying an outcome the controller has
/// not reported.
void main() {
  final now = DateTime(2026, 8, 12, 14, 0, 0);

  const moist = FarmData(
    mode: 'manual',
    pump: false,
    pumpStatus: false,
    soilMoisture: 1200,
    threshold: 1800,
    temperature: 28.4,
    humidity: 62,
  );

  const settled = FarmStatus(
    headline: 'Soil is moist',
    detail: 'No watering needed',
    tone: FarmTone.settled,
    why: 'Below the dry threshold.',
  );

  const noAdvice = IrrigationAdvice(
    verdict: IrrigationVerdict.soilIsMoist,
    headline: 'No watering needed',
    reasoning: 'Below threshold.',
  );

  PumpCommandState inFlight({bool start = true}) {
    return PumpCommandMachine.writeSucceeded(
      current: PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: start,
        deviceState: !start,
        now: now,
        isAutomatic: false,
        isConnected: true,
      ),
      now: now,
    );
  }

  FieldBand band({
    FarmData farm = moist,
    PumpCommandState command = PumpCommandState.idle,
    FarmStatus status = settled,
    IrrigationAdvice advice = noAdvice,
  }) {
    return FieldBand.of(
      farmName: 'Nuo Farm',
      farm: farm,
      isConnected: true,
      command: command,
      status: status,
      advice: advice,
    );
  }

  group('FieldBand ordering', () {
    test('an unconfirmed command outranks the farm state', () {
      // The farm is fine, but the farmer is waiting on a specific request —
      // that is what the band must be about.
      final b = band(command: inFlight());

      expect(b.headline, 'Start sent');
      expect(b.detail, contains('not running yet'));
      expect(b.tone, FarmTone.caution);
    });

    test('a stop request says the pump has not stopped yet', () {
      final b = band(
        farm: moist.copyWith(pumpStatus: true),
        command: inFlight(start: false),
      );

      expect(b.headline, 'Stop sent');
      expect(b.detail, contains('has not stopped yet'));
    });

    test('a timed-out command reports the outcome as unknowable', () {
      final timedOut = PumpCommandMachine.tick(
        current: inFlight(),
        now: now.add(PumpCommandMachine.deviceTimeout),
      );

      final b = band(command: timedOut);
      expect(b.headline, 'No answer from the pump');
      expect(b.detail, contains('cannot tell'));
      expect(b.tone, FarmTone.fault);
    });

    test('with nothing in flight the farm speaks for itself', () {
      final b = band();
      expect(b.headline, 'Soil is moist');
      expect(b.tone, FarmTone.settled);
    });

    test('the eyebrow names the farm and the mode', () {
      expect(band().eyebrow, 'NUO FARM · MANUAL');
      expect(
        band(farm: moist.copyWith(mode: 'automatic')).eyebrow,
        'NUO FARM · AUTOMATIC',
      );
    });
  });

  group('FieldBand savings chip', () {
    test('appears only when the saving is worth stating', () {
      expect(band().chip, isNull);

      const small = IrrigationAdvice(
        verdict: IrrigationVerdict.holdForRain,
        headline: 'Hold',
        reasoning: 'Rain coming.',
        litresSaved: 12,
      );
      expect(band(advice: small).chip, isNull);

      const worthIt = IrrigationAdvice(
        verdict: IrrigationVerdict.holdForRain,
        headline: 'Hold',
        reasoning: 'Rain coming.',
        litresSaved: 800,
      );
      expect(band(advice: worthIt).chip, 'Saves ~800 L');
    });

    test('never dresses up a fault with a saving', () {
      const fault = FarmStatus(
        headline: 'Soil sensor fault',
        detail: 'Reading 0 is not a measurement',
        tone: FarmTone.fault,
      );
      const worthIt = IrrigationAdvice(
        verdict: IrrigationVerdict.holdForRain,
        headline: 'Hold',
        reasoning: 'Rain.',
        litresSaved: 800,
      );

      expect(band(status: fault, advice: worthIt).chip, isNull);
    });
  });

  group('Reading — the word leads, the number supports', () {
    List<Reading> read(FarmData farm, {double? rain}) => Reading.from(
      farm: farm,
      rainMm: rain,
      rainProbability: 80,
      rainWhen: 'in about 4h',
    );

    test('soil is reported as a word, not a raw value', () {
      final dry = read(moist.copyWith(soilMoisture: 2400)).first;
      expect(dry.value, 'Dry');
      expect(dry.caption, 'needs water');

      final wet = read(moist).first;
      expect(wet.value, 'Moist');
    });

    test('a dead probe shows no reading at all', () {
      final soil = read(moist.copyWith(soilMoisture: 0)).first;
      expect(soil.value, '—');
      expect(soil.caption, 'no signal');
      expect(soil.tone, ReadingTone.fault);
      expect(soil.value, isNot('Moist'));
    });

    test('a missing air sensor is blank, not zero', () {
      final air = Reading.from(
        farm: const FarmData(
          mode: 'manual',
          pump: false,
          pumpStatus: false,
          soilMoisture: 1200,
          threshold: 1800,
        ),
        rainMm: null,
        rainProbability: 0,
        rainWhen: null,
      )[1];

      expect(air.value, '—');
      expect(air.caption, 'no signal');
    });

    test('rain distinguishes none, unknown, and expected', () {
      expect(read(moist, rain: null)[2].caption, 'no forecast');
      expect(read(moist, rain: 0)[2].value, 'None');

      final coming = read(moist, rain: 8)[2];
      expect(coming.value, '8mm');
      expect(coming.caption, 'in about 4h');
      expect(coming.tone, ReadingTone.water);
    });

    test('always produces exactly three cells', () {
      expect(read(moist, rain: 8).length, 3);
      expect(read(moist, rain: 8).map((r) => r.label), ['Soil', 'Air', 'Rain']);
    });
  });
}

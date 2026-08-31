import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/farm_brief.dart';
import 'package:smart_farm/logic/pump_command_machine.dart';
import 'package:smart_farm/models/alert.dart';
import 'package:smart_farm/models/assistant.dart';
import 'package:smart_farm/models/farm_data.dart';
import 'package:smart_farm/models/farm_profile.dart';
import 'package:smart_farm/models/pump_command.dart';
import 'package:smart_farm/models/sensor_reading.dart';
import 'package:smart_farm/models/weather.dart';

/// The brief is the assistant's entire view of the farm. Anything it omits,
/// the model is free to invent; anything it states wrongly, the model will
/// repeat with confidence. These tests pin the grounding rules.
void main() {
  final now = DateTime(2026, 8, 12, 14, 0, 0);

  const profile = FarmProfile(
    name: 'Nuo Farm',
    location: FarmLocation(
      latitude: 6.68,
      longitude: -1.62,
      name: 'Kumasi, Ghana',
    ),
    areaSqm: 500,
  );

  const moist = FarmData(
    mode: 'manual',
    pump: false,
    pumpStatus: false,
    soilMoisture: 1200,
    threshold: 1800,
    temperature: 28.4,
    humidity: 62,
  );

  String brief({
    FarmData farm = moist,
    bool isConnected = true,
    PumpCommandState command = PumpCommandState.idle,
    List<FarmAlert> alerts = const [],
    List<SensorReading> history = const [],
  }) {
    return FarmBrief.build(
      profile: profile,
      farm: farm,
      isConnected: isConnected,
      command: command,
      weather: null,
      alerts: alerts,
      history: history,
      now: now,
    );
  }

  group('FarmBrief grounding', () {
    test('states the farm by name and place', () {
      final text = brief();
      expect(text, contains('Nuo Farm'));
      expect(text, contains('Kumasi, Ghana'));
    });

    test('a missing sensor is named as missing, not omitted', () {
      // An absent line is an invitation to invent a plausible number.
      final text = brief(farm: moist.copyWith().copyWithNullClimate());
      expect(text, contains('Temperature: not reporting'));
      expect(text, contains('Humidity: not reporting'));
    });

    test('an implausible soil reading is never described as wet or dry', () {
      final text = brief(farm: moist.copyWith(soilMoisture: 0));

      expect(text, contains('NOT A VALID MEASUREMENT'));
      expect(
        text,
        isNot(contains('State: MOIST')),
        reason: 'a dead probe must not be reported as moist soil',
      );
      expect(text, isNot(contains('State: DRY')));
    });

    test('a lost link is stated before any value is read', () {
      final text = brief(isConnected: false);
      expect(text, contains('CONTROLLER LINK: DOWN'));
      expect(text, contains('may no longer be true'));
    });

    test('old readings are marked stale', () {
      final fresh = brief(
        history: [
          SensorReading(
            timestamp: now.subtract(const Duration(minutes: 2)),
            soilMoisture: 1200,
            pumpOn: false,
          ),
        ],
      );
      expect(fresh, isNot(contains('STALE')));

      final old = brief(
        history: [
          SensorReading(
            timestamp: now.subtract(const Duration(hours: 3)),
            soilMoisture: 1200,
            pumpOn: false,
          ),
        ],
      );
      expect(old, contains('STALE'));
    });

    test('command and measured pump state are kept apart', () {
      // The exact confusion the whole system is built to prevent.
      final text = brief(farm: moist.copyWith(pump: true, pumpStatus: false));

      expect(text, contains('Measured state (authoritative): OFF'));
      expect(text, contains('Last command written: ON'));
      expect(text, contains('These disagree'));
    });

    test('automatic mode is flagged as a refusal, not a fault', () {
      final text = brief(farm: moist.copyWith(mode: 'automatic'));
      expect(text, contains('AUTOMATIC'));
      expect(text, contains('will be refused'));
      expect(text, contains('Only the farmer can switch to manual'));
    });

    test('an unconfirmed command is described as unknown', () {
      final sent = PumpCommandMachine.writeSucceeded(
        current: PumpCommandMachine.request(
          current: PumpCommandState.idle,
          desired: true,
          deviceState: false,
          now: now,
          isAutomatic: false,
          isConnected: true,
        ),
        now: now,
      );

      final text = brief(command: sent);
      expect(text, contains('outcome unknown'));
    });

    test('active alerts are carried verbatim', () {
      final text = brief(
        alerts: [
          FarmAlert(
            id: 'pump_stuck',
            title: 'Pump has run for 3 h',
            message: 'Check the relay.',
            severity: AlertSeverity.critical,
            category: AlertCategory.pump,
            raisedAt: now,
          ),
        ],
      );

      expect(text, contains('CRITICAL'));
      expect(text, contains('Pump has run for 3 h'));
    });

    test('the irrigation hierarchy is stated in order', () {
      final text = brief();
      final soil = text.indexOf('SOIL (primary');
      final air = text.indexOf('AIR (modifies');
      final weather = text.indexOf('WEATHER (can delay');

      expect(soil, greaterThan(-1));
      expect(air, greaterThan(soil));
      expect(weather, greaterThan(air));
      expect(text, contains('never decides whether to'));
      expect(text, contains('cannot start it'));
    });
  });

  group('PumpOutcome', () {
    test('a refused command reports the pump unchanged', () {
      final refused = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: false,
        now: now,
        isAutomatic: true, // controller owns the pump
        isConnected: true,
      );

      final text = PumpOutcome.describe(
        requestedStart: true,
        command: refused,
        farm: moist,
      );

      expect(text, startsWith('REFUSED'));
      expect(text, contains('did not change'));
    });

    test('a sent-but-unconfirmed command forbids claiming success', () {
      final sent = PumpCommandMachine.writeSucceeded(
        current: PumpCommandMachine.request(
          current: PumpCommandState.idle,
          desired: true,
          deviceState: false,
          now: now,
          isAutomatic: false,
          isConnected: true,
        ),
        now: now,
      );

      final text = PumpOutcome.describe(
        requestedStart: true,
        command: sent,
        farm: moist,
      );

      expect(text, contains('NOT YET CONFIRMED'));
      expect(text, contains('Do not tell the farmer the pump is on'));
    });

    test('a timeout reports the physical state as unknown', () {
      final timedOut = PumpCommandMachine.tick(
        current: PumpCommandMachine.writeSucceeded(
          current: PumpCommandMachine.request(
            current: PumpCommandState.idle,
            desired: true,
            deviceState: false,
            now: now,
            isAutomatic: false,
            isConnected: true,
          ),
          now: now,
        ),
        now: now.add(PumpCommandMachine.deviceTimeout),
      );

      final text = PumpOutcome.describe(
        requestedStart: true,
        command: timedOut,
        farm: moist,
      );

      expect(text, contains('TIMED OUT'));
      expect(text, contains('unknown'));
    });
  });

  group('PumpIntent', () {
    test('the tool schema is a closed, fully-required function', () {
      // A narrow, closed schema is what makes a mid-sized open model reliable
      // at filling it — and what lets the app reject anything else outright.
      final def = PumpIntent.toolDefinition;
      expect(def['type'], 'function');

      final fn = def['function'] as Map<String, dynamic>;
      expect(fn['name'], PumpIntent.toolName);

      final schema = fn['parameters'] as Map<String, dynamic>;
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], containsAll(['action', 'reason']));

      final props = schema['properties'] as Map<String, dynamic>;
      final action = props['action'] as Map<String, dynamic>;
      expect(
        action['enum'],
        ['start', 'stop'],
        reason: 'the model must not be able to invent a third action',
      );
    });

    test('parses the two legal actions', () {
      expect(
        PumpIntent.tryParse('t1', {
          'action': 'start',
          'reason': 'soil dry',
        })?.start,
        isTrue,
      );
      expect(
        PumpIntent.tryParse('t1', {
          'action': 'stop',
          'reason': 'enough',
        })?.start,
        isFalse,
      );
    });

    test('rejects anything else rather than guessing', () {
      expect(
        PumpIntent.tryParse('t1', {'action': 'toggle', 'reason': 'x'}),
        isNull,
      );
      expect(PumpIntent.tryParse('t1', {'action': 'start'}), isNull);
      expect(PumpIntent.tryParse('t1', const {}), isNull);
    });
  });
}

/// Clears the climate readings, which `copyWith` cannot do by design.
extension on FarmData {
  FarmData copyWithNullClimate() => FarmData(
    mode: mode,
    pump: pump,
    pumpStatus: pumpStatus,
    soilMoisture: soilMoisture,
    threshold: threshold,
    irrigationDurationMs: irrigationDurationMs,
    irrigationReason: irrigationReason,
    rainExpected: rainExpected,
    rainProbability: rainProbability,
  );
}

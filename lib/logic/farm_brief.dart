import '../models/alert.dart';
import '../models/farm_data.dart';
import '../models/farm_profile.dart';
import '../models/pump_command.dart';
import '../models/sensor_reading.dart';
import '../models/weather.dart';
import 'rain_outlook.dart';

/// Everything the assistant is allowed to know about the farm, rendered as
/// text for the model.
///
/// This is the assistant's *only* source of farm facts. It is built as a pure
/// function so the grounding can be tested without a network, a model, or a
/// device — the thing most likely to make an assistant untrustworthy is a
/// context that quietly omits or misstates state.
///
/// Two rules shape the output:
///
/// 1. **Unknown is stated, never omitted.** A missing temperature reads as
///    "not reporting", not as an absent line the model can fill in from
///    plausibility. Silence in a context window becomes invention.
///
/// 2. **Age travels with the value.** Every measurement carries how old it is,
///    so the model can say "as of eleven minutes ago" instead of implying it
///    is looking at the farm right now.
class FarmBrief {
  const FarmBrief._();

  /// A reading older than this is called out as stale rather than presented as
  /// current. Matches the controller's ~5 s publish cadence with generous
  /// slack for a slow rural link.
  static const Duration stalenessThreshold = Duration(minutes: 10);

  static String build({
    required FarmProfile profile,
    required FarmData farm,
    required bool isConnected,
    required PumpCommandState command,
    required WeatherReport? weather,
    required List<FarmAlert> alerts,
    required List<SensorReading> history,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final b = StringBuffer();

    b.writeln('<farm_state>');
    b.writeln('Captured at: ${clock.toIso8601String()}');
    b.writeln('Farm: ${profile.isConfigured ? profile.name : "(unnamed)"}');
    b.writeln('Location: ${profile.location.name}');
    b.writeln('Field size: ${profile.areaLabel}');
    b.writeln();

    // --- Link -------------------------------------------------------------
    if (!isConnected) {
      b.writeln(
        'CONTROLLER LINK: DOWN. Every value below is the last received and '
        'may no longer be true. The pump cannot be commanded.',
      );
    } else {
      b.writeln('Controller link: connected.');
    }

    final lastReading = history.isEmpty ? null : history.last.timestamp;
    if (lastReading != null) {
      final age = clock.difference(lastReading);
      b.writeln(
        'Last sensor sample: ${_age(age)} ago'
        '${age > stalenessThreshold ? " — STALE" : ""}.',
      );
    } else {
      b.writeln('Last sensor sample: none recorded this session.');
    }
    b.writeln();

    // --- Soil (the primary signal) ----------------------------------------
    b.writeln('SOIL (primary irrigation signal)');
    if (!farm.hasPlausibleSoil) {
      b.writeln(
        '  Reading: ${farm.soilMoisture} — NOT A VALID MEASUREMENT. The probe '
        'is disconnected, shorted, or in air. Do not describe the soil as wet, '
        'dry, or moist; there is no usable soil reading.',
      );
    } else {
      b.writeln('  Raw value: ${farm.soilMoisture}');
      b.writeln('  Dry threshold: ${farm.threshold}');
      b.writeln(
        '  State: ${farm.isDry ? "DRY (above threshold)" : "MOIST (below threshold)"}',
      );
      b.writeln('  Note: this probe reads HIGHER when the soil is DRIER.');
    }
    b.writeln();

    // --- Air (modifies duration, never triggers) --------------------------
    b.writeln('AIR (modifies how long to water; never decides whether to)');
    b.writeln(
      '  Temperature: ${farm.temperature == null ? "not reporting" : "${farm.temperature!.toStringAsFixed(1)} C"}',
    );
    b.writeln(
      '  Humidity: ${farm.humidity == null ? "not reporting" : "${farm.humidity!.toStringAsFixed(0)} %"}',
    );
    b.writeln();

    // --- Pump: command vs measured ---------------------------------------
    b.writeln('PUMP');
    b.writeln(
      '  Measured state (authoritative): ${farm.pumpStatus ? "RUNNING" : "OFF"}',
    );
    b.writeln('  Last command written: ${farm.pump ? "ON" : "OFF"}');
    if (farm.pump != farm.pumpStatus) {
      b.writeln(
        '  These disagree. The commanded value is NOT the pump state — say '
        'the pump is ${farm.pumpStatus ? "running" : "off"}.',
      );
    }
    b.writeln('  Mode: ${farm.isAutomatic ? "AUTOMATIC" : "MANUAL"}');
    if (farm.isAutomatic) {
      b.writeln(
        '  In automatic mode the controller owns the pump. A manual command '
        'will be refused. Only the farmer can switch to manual.',
      );
    }
    b.writeln('  In-flight command: ${_commandPhrase(command)}');
    b.writeln("  Controller's stated reason: ${farm.reason.label}");
    if (farm.irrigationDurationMs > 0) {
      b.writeln(
        '  Intended cycle length: '
        '${(farm.irrigationDurationMs / 1000).toStringAsFixed(0)} seconds',
      );
    }
    b.writeln();

    // --- Weather layer ----------------------------------------------------
    b.writeln('WEATHER (can delay irrigation; cannot start it)');
    if (weather == null) {
      b.writeln('  No forecast available.');
    } else {
      final outlook = RainForecaster.forecast(weather);
      final fetchAge = clock.difference(weather.fetchedAt);
      b.writeln(
        '  Now: ${weather.current.temperatureC.toStringAsFixed(0)} C, '
        '${weather.current.condition.label}, '
        '${weather.current.humidity.toStringAsFixed(0)}% humidity '
        '(fetched ${_age(fetchAge)} ago)',
      );
      b.writeln(
        '  Next ${RainForecaster.lookAheadHours} h: '
        '${outlook.millimetres.toStringAsFixed(1)} mm at '
        '${outlook.probability}% peak chance',
      );
      if (weather.daily.isNotEmpty) {
        final today = weather.daily.first;
        b.writeln(
          '  Today: high ${today.maxTempC.toStringAsFixed(0)} C, '
          'rain chance ${today.precipitationProbability}%, '
          'evapotranspiration ${today.et0Mm.toStringAsFixed(1)} mm',
        );
      }
    }
    b.writeln(
      '  Published to controller: rainExpected=${farm.rainExpected}, '
      'rainProbability=${farm.rainProbability}%',
    );
    b.writeln(
      '  The controller holds irrigation only when rainExpected is true AND '
      'rainProbability is at least ${RainForecaster.minConfidence}%.',
    );
    b.writeln();

    // --- Alerts -----------------------------------------------------------
    b.writeln('ACTIVE ALERTS');
    if (alerts.isEmpty) {
      b.writeln('  None.');
    } else {
      for (final a in alerts) {
        b.writeln(
          '  [${a.severity.name.toUpperCase()}] ${a.title} — ${a.message}',
        );
      }
    }

    b.writeln('</farm_state>');
    return b.toString();
  }

  static String _commandPhrase(PumpCommandState command) {
    return switch (command.phase) {
      PumpCommandPhase.idle => 'none',
      PumpCommandPhase.sending => 'being sent, not yet acknowledged',
      PumpCommandPhase.awaitingDevice =>
        'sent, waiting for the controller to confirm — outcome unknown',
      PumpCommandPhase.confirmed => 'confirmed by the controller',
      PumpCommandPhase.failed => 'FAILED to send; the pump did not change',
      PumpCommandPhase.timedOut =>
        'TIMED OUT; the controller never confirmed and the real pump state is unknown',
      PumpCommandPhase.rejected => 'refused by app rules; nothing was sent',
    };
  }

  static String _age(Duration d) {
    if (d.inSeconds < 90) return '${d.inSeconds} seconds';
    if (d.inMinutes < 90) return '${d.inMinutes} minutes';
    if (d.inHours < 36) return '${d.inHours} hours';
    return '${d.inDays} days';
  }
}

/// What to tell the model after it asked for a pump change.
///
/// The model must never learn "the pump is on" from having requested it. This
/// reports the *command's* fate — accepted, refused, unconfirmed — and says
/// explicitly when the physical outcome is still unknown.
class PumpOutcome {
  const PumpOutcome._();

  static String describe({
    required bool requestedStart,
    required PumpCommandState command,
    required FarmData farm,
  }) {
    final wanted = requestedStart ? 'start' : 'stop';

    return switch (command.phase) {
      PumpCommandPhase.rejected =>
        'REFUSED. ${command.message ?? "The app rejected the request."} '
            'Nothing was sent to the controller and the pump did not change. '
            'It is still ${farm.pumpStatus ? "running" : "off"}.',
      PumpCommandPhase.failed =>
        'FAILED TO SEND. ${command.message ?? "The write did not reach the controller."} '
            'The pump did not change.',
      PumpCommandPhase.sending || PumpCommandPhase.awaitingDevice =>
        'SENT, NOT YET CONFIRMED. The request to $wanted the pump reached the '
            'controller, which has not reported back. The pump may not have '
            'changed yet. Do not tell the farmer the pump is '
            '${requestedStart ? "on" : "off"} — say the command is on its way '
            'and the app will confirm within about fifteen seconds.',
      PumpCommandPhase.confirmed =>
        'CONFIRMED. The controller reports the pump is now '
            '${farm.pumpStatus ? "running" : "off"}.',
      PumpCommandPhase.timedOut =>
        'TIMED OUT. The controller never confirmed, so the real pump state is '
            'unknown. Tell the farmer to check the pump physically.',
      PumpCommandPhase.idle =>
        'No command is in flight. The pump is '
            '${farm.pumpStatus ? "running" : "off"}.',
    };
  }
}

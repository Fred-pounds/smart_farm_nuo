import '../models/alert.dart';
import '../models/farm_data.dart';
import '../models/pump_command.dart';
import 'farm_status.dart';

/// The status band at the top of the Farm screen.
///
/// It answers one question — *what is happening and do I need to act* — in a
/// headline a farmer can read at arm's length in sunlight.
///
/// The layering is the important part: **an unconfirmed command outranks
/// everything else**. While a pump request is in flight the band describes the
/// request, not the farm, and says plainly that the pump has not moved yet.
/// Any other ordering would let the band imply an outcome the controller has
/// not reported.
class FieldBand {
  /// Small caps line: farm name and operating mode.
  final String eyebrow;

  /// Three or four words. The thing that is true right now.
  final String headline;

  /// One line: what it means, or what happens next.
  final String detail;

  final FarmTone tone;

  /// Optional quantified upside, e.g. water a rain delay saves.
  final String? chip;

  /// Longer reasoning, shown only when the farmer taps "Why?".
  final String? why;

  const FieldBand({
    required this.eyebrow,
    required this.headline,
    required this.detail,
    required this.tone,
    this.chip,
    this.why,
  });

  /// True while a pump request is unresolved. The band renders amber and the
  /// action bar shows the request rather than a state.
  bool get isAwaitingDevice => tone == FarmTone.caution && chip == null;

  static FieldBand of({
    required String farmName,
    required FarmData farm,
    required bool isConnected,
    required PumpCommandState command,
    required FarmStatus status,
    required IrrigationAdvice advice,
  }) {
    final eyebrow =
        '${farmName.toUpperCase()} · ${farm.isAutomatic ? "AUTOMATIC" : "MANUAL"}';

    // 1. A command the controller has not answered. Outranks the farm's own
    //    state, because the farmer is waiting on this specific thing.
    if (command.isInFlight) {
      final starting = command.desired == true;
      return FieldBand(
        eyebrow: eyebrow,
        headline: starting ? 'Start sent' : 'Stop sent',
        detail: starting
            ? 'Waiting for the pump to answer. It is not running yet.'
            : 'Waiting for the pump to answer. It has not stopped yet.',
        tone: FarmTone.caution,
      );
    }

    // 2. A command that resolved badly. The physical outcome is unknown, and
    //    that is the most important thing on the screen.
    if (command.isUnresolved) {
      return FieldBand(
        eyebrow: eyebrow,
        headline: command.phase == PumpCommandPhase.timedOut
            ? 'No answer from the pump'
            : 'Command not sent',
        detail: command.phase == PumpCommandPhase.timedOut
            ? 'Check the pump yourself — the app cannot tell if it changed.'
            : 'The pump did not change. Try again.',
        tone: FarmTone.fault,
        why: command.message,
      );
    }

    // 3. Otherwise the farm speaks for itself.
    return FieldBand(
      eyebrow: eyebrow,
      headline: status.headline,
      detail: status.detail,
      tone: status.tone,
      chip: _savingsChip(status, advice),
      why: status.why,
    );
  }

  /// Only shown when holding for rain actually saves a measurable amount —
  /// a chip that appears on every screen stops carrying information.
  static String? _savingsChip(FarmStatus status, IrrigationAdvice advice) {
    if (status.tone == FarmTone.fault) return null;
    final litres = advice.litresSaved;
    if (litres == null || litres < 50) return null;
    return litres >= 1000
        ? 'Saves ~${(litres / 1000).toStringAsFixed(1)}k L'
        : 'Saves ~${litres.round()} L';
  }
}

/// One cell of the three-up readings row.
///
/// The design's central move: **the word leads, the number supports.** A
/// farmer glancing at the screen needs "Dry", not 1,870 — the raw value is
/// there for anyone who wants it, one line down.
class Reading {
  final String label;

  /// The headline value. A word for soil, a number for air and rain.
  final String value;

  /// The qualifier beneath it.
  final String caption;

  /// Which semantic colour to use; resolved against the theme by the widget so
  /// this stays free of Flutter imports.
  final ReadingTone tone;

  const Reading({
    required this.label,
    required this.value,
    required this.caption,
    required this.tone,
  });

  /// Builds all three cells from live state.
  static List<Reading> from({
    required FarmData farm,
    required double? rainMm,
    required int rainProbability,
    required String? rainWhen,
  }) {
    return [_soil(farm), _air(farm), _rain(rainMm, rainProbability, rainWhen)];
  }

  static Reading _soil(FarmData farm) {
    if (!farm.hasPlausibleSoil) {
      return const Reading(
        label: 'Soil',
        value: '—',
        caption: 'no signal',
        tone: ReadingTone.fault,
      );
    }
    return Reading(
      label: 'Soil',
      value: farm.isDry ? 'Dry' : 'Moist',
      caption: farm.isDry ? 'needs water' : 'no water needed',
      tone: farm.isDry ? ReadingTone.dry : ReadingTone.wet,
    );
  }

  static Reading _air(FarmData farm) {
    final t = farm.temperature;
    if (t == null) {
      return const Reading(
        label: 'Air',
        value: '—',
        caption: 'no signal',
        tone: ReadingTone.fault,
      );
    }
    final word = t >= 33
        ? 'Hot'
        : t >= 28
        ? 'Warm'
        : t >= 20
        ? 'Mild'
        : 'Cool';
    return Reading(
      label: 'Air',
      value: '${t.round()}°',
      caption: word,
      tone: t >= 33 ? ReadingTone.hot : ReadingTone.neutral,
    );
  }

  static Reading _rain(double? mm, int probability, String? when) {
    if (mm == null) {
      return const Reading(
        label: 'Rain',
        value: '—',
        caption: 'no forecast',
        tone: ReadingTone.neutral,
      );
    }
    if (mm < 1) {
      return const Reading(
        label: 'Rain',
        value: 'None',
        caption: 'next 12 h',
        tone: ReadingTone.neutral,
      );
    }
    return Reading(
      label: 'Rain',
      value: '${mm.round()}mm',
      caption: when ?? '$probability% chance',
      tone: ReadingTone.water,
    );
  }
}

enum ReadingTone { dry, wet, hot, water, neutral, fault }

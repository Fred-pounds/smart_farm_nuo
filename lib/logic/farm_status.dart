import '../models/alert.dart';
import '../models/farm_data.dart';

/// How the farm is doing, in the few words a glance can carry.
enum FarmTone {
  /// Nothing to do.
  settled,

  /// The system is acting right now.
  working,

  /// Needs a decision or an eye kept on it.
  caution,

  /// Something is broken. Readings cannot be trusted.
  fault,
}

/// The answer to "how is my farm doing", reduced to a headline a farmer can
/// read in about a second.
class FarmStatus {
  /// Three or four words. The thing that is true right now.
  final String headline;

  /// One short line: what it means, or what happens next.
  final String detail;

  final FarmTone tone;

  /// The full reasoning, shown only when the farmer asks for it.
  ///
  /// Kept out of the headline deliberately. The dashboard used to print a
  /// paragraph under every card, and a wall of prose is not something anyone
  /// reads standing in a field.
  final String? why;

  const FarmStatus({
    required this.headline,
    required this.detail,
    required this.tone,
    this.why,
  });
}

/// Reduces every live signal to one status line.
///
/// Ordered by what would hurt most if it were wrong. Connectivity and sensor
/// faults outrank irrigation advice, because advice derived from a reading
/// the app cannot trust is worse than no advice at all.
class FarmStatusReporter {
  const FarmStatusReporter._();

  static FarmStatus of({
    required FarmData farm,
    required bool isConnected,
    required IrrigationAdvice advice,
  }) {
    if (!isConnected) {
      return const FarmStatus(
        headline: 'Controller offline',
        detail: 'Readings are not updating',
        tone: FarmTone.fault,
        why:
            'The app cannot reach Firebase. Everything shown is the last '
            'value received, and the pump cannot be commanded until the '
            'connection returns.',
      );
    }

    if (!farm.hasPlausibleSoil) {
      return FarmStatus(
        headline: 'Soil sensor fault',
        detail: 'Reading ${farm.soilMoisture} is not a real measurement',
        tone: FarmTone.fault,
        why:
            'A capacitive probe cannot produce ${farm.soilMoisture} from '
            'soil. It usually means the probe is disconnected, shorted, or '
            'sitting in air. Irrigation advice is unavailable until it '
            'reports a real value.',
      );
    }

    if (farm.pumpStatus) {
      return FarmStatus(
        headline: 'Watering now',
        detail: farm.isAutomatic
            ? 'The controller started this cycle'
            : 'Running under your manual control',
        tone: FarmTone.working,
        why: farm.reason.explanation,
      );
    }

    return switch (advice.verdict) {
      IrrigationVerdict.irrigateNow => FarmStatus(
        headline: 'Soil is dry',
        detail: farm.isAutomatic
            ? 'The controller will water shortly'
            : 'Watering is due',
        tone: FarmTone.caution,
        why: advice.reasoning,
      ),
      IrrigationVerdict.holdForRain => FarmStatus(
        headline: 'Holding for rain',
        detail: 'Soil is dry, but rain is on the way',
        tone: FarmTone.settled,
        why: advice.reasoning,
      ),
      IrrigationVerdict.soilIsMoist => FarmStatus(
        headline: 'Soil is moist',
        detail: 'No watering needed',
        tone: FarmTone.settled,
        why: advice.reasoning,
      ),
      IrrigationVerdict.sensorUnknown => FarmStatus(
        headline: 'Waiting for the farm',
        detail: 'No reading has arrived yet',
        tone: FarmTone.fault,
        why: advice.reasoning,
      ),
    };
  }
}

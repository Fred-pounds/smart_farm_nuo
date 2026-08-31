import '../models/pump_command.dart';

/// The rules governing a pump command's journey from intent to confirmed
/// physical state.
///
/// Every transition is a pure function of the current state, the event, and
/// an injected `now`. No timers, no Firebase, no widgets — so the whole
/// lifecycle, including its timeouts, is unit-testable without fake async.
///
/// The caller (see `FarmProvider`) owns the clock and the side effects, and
/// feeds the outcomes back in here.
class PumpCommandMachine {
  const PumpCommandMachine._();

  /// How long the controller has to confirm a command the backend accepted.
  ///
  /// Sized from the firmware's own loop, not guessed. The ESP32 polls `/farm`
  /// every 3 s (`FIREBASE_READ_INTERVAL`) and publishes `pumpStatus` every
  /// 5 s (`FIREBASE_UPLOAD_INTERVAL`) on an independent timer, so a command
  /// landing just after a poll takes up to 8 s to be reflected, plus two
  /// round trips. Anything tighter would report healthy hardware as timed
  /// out; much looser and a real fault sits unreported.
  ///
  /// If those firmware intervals change, change this with them.
  static const Duration deviceTimeout = Duration(seconds: 15);

  /// How long a confirmation or rejection notice stays on screen before the
  /// UI settles back to plain device state.
  static const Duration noticeDuration = Duration(seconds: 4);

  /// Minimum gap between commands. This is the debounce that stops
  /// ON → OFF → ON → OFF being fired faster than the relay can follow.
  static const Duration cooldown = Duration(milliseconds: 1200);

  static const String automaticMessage =
      'The controller is running the pump automatically. Switch to manual '
      'mode to command it yourself.';
  static const String offlineMessage =
      'No connection to the farm controller, so the command was not sent.';
  static const String inFlightMessage =
      'A pump command is already on its way to the controller.';
  static const String cooldownMessage =
      'Give the controller a moment before sending another command.';

  /// Whether a new command may be issued right now.
  ///
  /// This is the command lock and the debounce in one place, so the button
  /// can disable itself using exactly the rule that would reject the tap.
  static bool canAccept({
    required PumpCommandState current,
    required DateTime now,
    required bool isAutomatic,
    required bool isConnected,
  }) {
    return refusalReason(
          current: current,
          now: now,
          isAutomatic: isAutomatic,
          isConnected: isConnected,
        ) ==
        null;
  }

  /// Why a command would be refused, or null if it would be accepted.
  ///
  /// Ordered by importance: automatic mode outranks everything, because
  /// letting a manual command through while the controller owns the pump is
  /// the one failure that could move water no one asked for.
  static String? refusalReason({
    required PumpCommandState current,
    required DateTime now,
    required bool isAutomatic,
    required bool isConnected,
  }) {
    if (isAutomatic) return automaticMessage;
    if (!isConnected) return offlineMessage;
    if (current.isInFlight) return inFlightMessage;

    final settledAt = current.settledAt;
    if (settledAt != null && now.difference(settledAt) < cooldown) {
      return cooldownMessage;
    }
    return null;
  }

  /// The user asked for the pump to change state.
  ///
  /// Returns the state to adopt: either a rejection carrying the reason, or
  /// `sending`, at which point the caller may write to the backend.
  static PumpCommandState request({
    required PumpCommandState current,
    required bool desired,
    required bool deviceState,
    required DateTime now,
    required bool isAutomatic,
    required bool isConnected,
  }) {
    final refusal = refusalReason(
      current: current,
      now: now,
      isAutomatic: isAutomatic,
      isConnected: isConnected,
    );

    if (refusal != null) {
      return PumpCommandState(
        phase: PumpCommandPhase.rejected,
        desired: desired,
        requestedAt: now,
        settledAt: now,
        message: refusal,
      );
    }

    return PumpCommandState(
      phase: PumpCommandPhase.sending,
      desired: desired,
      deviceStateAtRequest: deviceState,
      requestedAt: now,
    );
  }

  /// The backend accepted the write. The controller now has to act on it.
  ///
  /// If the pump was already in the requested state when we asked, there is
  /// no relay transition to wait for, so the command is done.
  static PumpCommandState writeSucceeded({
    required PumpCommandState current,
    required DateTime now,
  }) {
    if (current.phase != PumpCommandPhase.sending) return current;

    if (current.deviceStateAtRequest == current.desired) {
      return current.copyWith(
        phase: PumpCommandPhase.confirmed,
        settledAt: now,
      );
    }

    return current.copyWith(phase: PumpCommandPhase.awaitingDevice);
  }

  /// The write never landed. Nothing reached the controller.
  static PumpCommandState writeFailed({
    required PumpCommandState current,
    required DateTime now,
    required String error,
  }) {
    if (current.phase != PumpCommandPhase.sending) return current;

    return current.copyWith(
      phase: PumpCommandPhase.failed,
      settledAt: now,
      message:
          'The command could not be sent to the farm controller. '
          'The pump was not changed. ($error)',
    );
  }

  /// The controller published its actual pump state.
  ///
  /// Only a state the backend definitely holds can be confirmed this way, and
  /// only by observing the pump actually reach the requested state. A command
  /// that failed to send is never confirmed by a coincidental match — the
  /// farmer retries instead.
  ///
  /// A late report still resolves a timed-out command, which is the honest
  /// outcome: the controller was slow, not broken.
  static PumpCommandState deviceReported({
    required PumpCommandState current,
    required bool pumpStatus,
    required DateTime now,
  }) {
    final resolvable =
        current.phase == PumpCommandPhase.awaitingDevice ||
        current.phase == PumpCommandPhase.timedOut;
    if (!resolvable) return current;

    if (pumpStatus != current.desired) return current;

    return current.copyWith(
      phase: PumpCommandPhase.confirmed,
      settledAt: now,
      message: current.phase == PumpCommandPhase.timedOut
          ? 'The controller confirmed the change, later than expected.'
          : null,
    );
  }

  /// Advances time-based transitions. Call this on a ticker while the command
  /// is not idle.
  ///
  /// A command that outlives its deadline becomes [PumpCommandPhase.timedOut]
  /// rather than quietly succeeding. Confirmations and rejections fade back
  /// to idle; failures and timeouts persist, because an unresolved physical
  /// action should not disappear on its own.
  static PumpCommandState tick({
    required PumpCommandState current,
    required DateTime now,
  }) {
    switch (current.phase) {
      case PumpCommandPhase.awaitingDevice:
        final requestedAt = current.requestedAt;
        if (requestedAt != null &&
            now.difference(requestedAt) >= deviceTimeout) {
          return current.copyWith(
            phase: PumpCommandPhase.timedOut,
            settledAt: now,
            message:
                'The controller has not confirmed the change. The pump\'s '
                'actual state is unknown until it reports again.',
          );
        }
        return current;

      case PumpCommandPhase.confirmed:
      case PumpCommandPhase.rejected:
        final settledAt = current.settledAt;
        if (settledAt != null && now.difference(settledAt) >= noticeDuration) {
          return PumpCommandState.idle;
        }
        return current;

      case PumpCommandPhase.idle:
      case PumpCommandPhase.sending:
      case PumpCommandPhase.failed:
      case PumpCommandPhase.timedOut:
        return current;
    }
  }
}

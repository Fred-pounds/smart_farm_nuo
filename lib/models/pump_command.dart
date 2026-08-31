/// The lifecycle of a pump command, kept deliberately separate from the
/// pump's actual state.
///
/// Pressing a button creates *intent*. The pump only changes when the ESP32
/// receives the command, switches the relay, and reports back. Those are
/// different facts arriving at different times over an unreliable link, and
/// the app must never present the first as if it were the second.
///
/// Device truth lives in `FarmData.pumpStatus`. This type describes only how
/// far a request has travelled towards becoming true.
enum PumpCommandPhase {
  /// No request in flight. The device state is the whole truth.
  idle,

  /// Writing the command to the backend.
  sending,

  /// The backend accepted it; the controller has not reported back yet.
  awaitingDevice,

  /// The controller reported the state we asked for.
  confirmed,

  /// The command never reached the backend.
  failed,

  /// The backend has the command, but the controller never confirmed it.
  /// The pump's real state is unknown until it reports again.
  timedOut,

  /// Application rules refused the request. Nothing was written.
  rejected,
}

/// An immutable snapshot of the in-flight pump command, if any.
class PumpCommandState {
  final PumpCommandPhase phase;

  /// The state the user asked for. Null only when [phase] is idle.
  final bool? desired;

  /// What the pump was actually doing when the request was made.
  ///
  /// Kept so confirmation can require an observed *transition* into the
  /// requested state. Without it, commanding ON while the pump already reads
  /// ON would confirm itself off the very next report, having proved nothing.
  final bool? deviceStateAtRequest;

  /// When the request was made — the anchor for the confirmation deadline.
  final DateTime? requestedAt;

  /// When the command reached a terminal phase.
  final DateTime? settledAt;

  /// Plain-language explanation for the phases that need one.
  final String? message;

  const PumpCommandState({
    required this.phase,
    this.desired,
    this.deviceStateAtRequest,
    this.requestedAt,
    this.settledAt,
    this.message,
  });

  static const PumpCommandState idle = PumpCommandState(
    phase: PumpCommandPhase.idle,
  );

  /// A command is in flight while it can still change the pump. New requests
  /// must be refused during this window — that is the command lock.
  bool get isInFlight =>
      phase == PumpCommandPhase.sending ||
      phase == PumpCommandPhase.awaitingDevice;

  /// The command has finished travelling, successfully or not.
  bool get isSettled =>
      phase == PumpCommandPhase.confirmed ||
      phase == PumpCommandPhase.failed ||
      phase == PumpCommandPhase.timedOut ||
      phase == PumpCommandPhase.rejected;

  /// True when we asked for something and cannot vouch for the outcome.
  /// The UI must not claim the pump is in [desired] while this holds.
  bool get isUnresolved =>
      phase == PumpCommandPhase.failed || phase == PumpCommandPhase.timedOut;

  PumpCommandState copyWith({
    PumpCommandPhase? phase,
    bool? desired,
    bool? deviceStateAtRequest,
    DateTime? requestedAt,
    DateTime? settledAt,
    String? message,
  }) {
    return PumpCommandState(
      phase: phase ?? this.phase,
      desired: desired ?? this.desired,
      deviceStateAtRequest: deviceStateAtRequest ?? this.deviceStateAtRequest,
      requestedAt: requestedAt ?? this.requestedAt,
      settledAt: settledAt ?? this.settledAt,
      message: message ?? this.message,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farm/logic/pump_command_machine.dart';
import 'package:smart_farm/models/pump_command.dart';

/// The pump command lifecycle is the one place where a software mistake can
/// move water on a real farm, or tell a farmer water is moving when it is
/// not. Every transition is pinned here.
void main() {
  final t0 = DateTime(2026, 8, 12, 9, 0, 0);

  /// A command that has been accepted by the backend and is waiting on the
  /// controller, starting from a pump that was off.
  PumpCommandState awaiting({bool desired = true, DateTime? at}) {
    final requested = PumpCommandMachine.request(
      current: PumpCommandState.idle,
      desired: desired,
      deviceState: !desired,
      now: at ?? t0,
      isAutomatic: false,
      isConnected: true,
    );
    return PumpCommandMachine.writeSucceeded(current: requested, now: at ?? t0);
  }

  group('PumpCommandMachine acceptance rules', () {
    test('accepts a command in manual mode while connected', () {
      final state = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: false,
        now: t0,
        isAutomatic: false,
        isConnected: true,
      );

      expect(state.phase, PumpCommandPhase.sending);
      expect(state.desired, isTrue);
    });

    test('refuses manual control while the controller owns the pump', () {
      final state = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: false,
        now: t0,
        isAutomatic: true,
        isConnected: true,
      );

      expect(state.phase, PumpCommandPhase.rejected);
      expect(state.message, PumpCommandMachine.automaticMessage);
    });

    test('refuses to command a pump it cannot reach', () {
      final state = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: false,
        now: t0,
        isAutomatic: false,
        isConnected: false,
      );

      expect(state.phase, PumpCommandPhase.rejected);
      expect(state.message, PumpCommandMachine.offlineMessage);
    });

    test('automatic mode outranks every other refusal reason', () {
      final state = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: false,
        now: t0,
        isAutomatic: true,
        isConnected: false,
      );

      expect(state.message, PumpCommandMachine.automaticMessage);
    });

    test('locks out a second command while one is in flight', () {
      final inFlight = awaiting();

      final second = PumpCommandMachine.request(
        current: inFlight,
        desired: false,
        deviceState: false,
        now: t0.add(const Duration(milliseconds: 200)),
        isAutomatic: false,
        isConnected: true,
      );

      expect(second.phase, PumpCommandPhase.rejected);
      expect(second.message, PumpCommandMachine.inFlightMessage);
    });

    test('debounces ON/OFF hammering after a command settles', () {
      final confirmed = PumpCommandMachine.deviceReported(
        current: awaiting(),
        pumpStatus: true,
        now: t0.add(const Duration(seconds: 1)),
      );

      final tooSoon = PumpCommandMachine.request(
        current: confirmed,
        desired: false,
        deviceState: true,
        now: t0.add(const Duration(seconds: 1, milliseconds: 100)),
        isAutomatic: false,
        isConnected: true,
      );
      expect(tooSoon.phase, PumpCommandPhase.rejected);
      expect(tooSoon.message, PumpCommandMachine.cooldownMessage);

      final afterCooldown = PumpCommandMachine.request(
        current: confirmed,
        desired: false,
        deviceState: true,
        now: t0.add(const Duration(seconds: 3)),
        isAutomatic: false,
        isConnected: true,
      );
      expect(afterCooldown.phase, PumpCommandPhase.sending);
    });

    test('canAccept agrees with refusalReason', () {
      final inFlight = awaiting();
      const args = (isAutomatic: false, isConnected: true);

      expect(
        PumpCommandMachine.canAccept(
          current: inFlight,
          now: t0,
          isAutomatic: args.isAutomatic,
          isConnected: args.isConnected,
        ),
        isFalse,
      );
      expect(
        PumpCommandMachine.canAccept(
          current: PumpCommandState.idle,
          now: t0,
          isAutomatic: args.isAutomatic,
          isConnected: args.isConnected,
        ),
        isTrue,
      );
    });
  });

  group('PumpCommandMachine confirmation', () {
    test(
      'a sent command waits for the device rather than claiming success',
      () {
        final state = awaiting();

        expect(state.phase, PumpCommandPhase.awaitingDevice);
        expect(state.isInFlight, isTrue);
        expect(state.isSettled, isFalse);
      },
    );

    test('confirms only when the device reports the requested state', () {
      var state = awaiting();

      state = PumpCommandMachine.deviceReported(
        current: state,
        pumpStatus: false, // still off — nothing has happened yet
        now: t0.add(const Duration(seconds: 1)),
      );
      expect(state.phase, PumpCommandPhase.awaitingDevice);

      state = PumpCommandMachine.deviceReported(
        current: state,
        pumpStatus: true,
        now: t0.add(const Duration(seconds: 2)),
      );
      expect(state.phase, PumpCommandPhase.confirmed);
    });

    test('a redundant command settles without waiting for a transition', () {
      // Pump already running, user commands ON: there is no relay change to
      // observe, so waiting for one would hang until timeout.
      final requested = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: true,
        deviceState: true,
        now: t0,
        isAutomatic: false,
        isConnected: true,
      );
      final state = PumpCommandMachine.writeSucceeded(
        current: requested,
        now: t0,
      );

      expect(state.phase, PumpCommandPhase.confirmed);
    });

    test('a failed write is never confirmed by a coincidental match', () {
      final requested = PumpCommandMachine.request(
        current: PumpCommandState.idle,
        desired: false,
        deviceState: true,
        now: t0,
        isAutomatic: false,
        isConnected: true,
      );
      final failed = PumpCommandMachine.writeFailed(
        current: requested,
        now: t0,
        error: 'network unreachable',
      );

      final afterReport = PumpCommandMachine.deviceReported(
        current: failed,
        pumpStatus: false, // matches desired, but the command never landed
        now: t0.add(const Duration(seconds: 1)),
      );

      expect(afterReport.phase, PumpCommandPhase.failed);
      expect(afterReport.isUnresolved, isTrue);
    });
  });

  group('PumpCommandMachine timeouts', () {
    test('times out when the controller never confirms', () {
      final state = PumpCommandMachine.tick(
        current: awaiting(),
        now: t0.add(PumpCommandMachine.deviceTimeout),
      );

      expect(state.phase, PumpCommandPhase.timedOut);
      expect(state.isUnresolved, isTrue);
    });

    test('does not time out before the deadline', () {
      final state = PumpCommandMachine.tick(
        current: awaiting(),
        now: t0.add(
          PumpCommandMachine.deviceTimeout - const Duration(seconds: 1),
        ),
      );

      expect(state.phase, PumpCommandPhase.awaitingDevice);
    });

    test('a late report still resolves a timed-out command', () {
      final timedOut = PumpCommandMachine.tick(
        current: awaiting(),
        now: t0.add(PumpCommandMachine.deviceTimeout),
      );

      final resolved = PumpCommandMachine.deviceReported(
        current: timedOut,
        pumpStatus: true,
        now: t0.add(const Duration(seconds: 20)),
      );

      expect(resolved.phase, PumpCommandPhase.confirmed);
    });

    test('an unresolved command never fades on its own', () {
      final timedOut = PumpCommandMachine.tick(
        current: awaiting(),
        now: t0.add(PumpCommandMachine.deviceTimeout),
      );

      final muchLater = PumpCommandMachine.tick(
        current: timedOut,
        now: t0.add(const Duration(minutes: 10)),
      );

      expect(muchLater.phase, PumpCommandPhase.timedOut);
    });

    test('confirmations and rejections fade back to idle', () {
      final confirmed = PumpCommandMachine.deviceReported(
        current: awaiting(),
        pumpStatus: true,
        now: t0.add(const Duration(seconds: 1)),
      );

      expect(
        PumpCommandMachine.tick(
          current: confirmed,
          now: t0.add(const Duration(seconds: 2)),
        ).phase,
        PumpCommandPhase.confirmed,
      );

      expect(
        PumpCommandMachine.tick(
          current: confirmed,
          now: t0.add(
            const Duration(seconds: 1) + PumpCommandMachine.noticeDuration,
          ),
        ).phase,
        PumpCommandPhase.idle,
      );
    });
  });

  group('PumpCommandMachine ignores out-of-order events', () {
    test('a stale write result cannot revive a settled command', () {
      final timedOut = PumpCommandMachine.tick(
        current: awaiting(),
        now: t0.add(PumpCommandMachine.deviceTimeout),
      );

      expect(
        PumpCommandMachine.writeSucceeded(current: timedOut, now: t0).phase,
        PumpCommandPhase.timedOut,
      );
      expect(
        PumpCommandMachine.writeFailed(
          current: timedOut,
          now: t0,
          error: 'late',
        ).phase,
        PumpCommandPhase.timedOut,
      );
    });

    test('device reports do not disturb an idle app', () {
      final state = PumpCommandMachine.deviceReported(
        current: PumpCommandState.idle,
        pumpStatus: true,
        now: t0,
      );

      expect(state.phase, PumpCommandPhase.idle);
    });
  });
}

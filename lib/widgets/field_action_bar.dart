import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pump_command.dart';
import '../providers/farm_provider.dart';
import '../theme/theme.dart';

/// The pump control, parked permanently in the thumb zone above the navigation
/// bar.
///
/// Two rules govern what it says:
///
/// 1. **The button shows the request, never the outcome.** While a command is
///    unconfirmed it reads "Sending…" — not "Running". Only `pumpStatus`, the
///    state the controller measured, turns it into a stop button.
///
/// 2. **Automatic mode disables it rather than hiding it.** A control that
///    vanishes leaves a farmer wondering where it went; one that is present
///    and explains itself teaches who is in charge of the pump.
class FieldActionBar extends StatelessWidget {
  const FieldActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final data = provider.data;
    final command = provider.command;
    final colors = context.farmColors;

    final running = data.pumpStatus;
    final busy = command.isInFlight;
    final auto = data.isAutomatic;

    final (label, icon, background) = _button(
      auto: auto,
      running: running,
      busy: busy,
      connected: provider.isConnected,
      colors: colors,
    );

    final enabled = !auto && !busy && provider.canCommandPump;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space5,
        Tokens.space2,
        Tokens.space5,
        Tokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: enabled
                    ? () {
                        // The heaviest tap in the app. This one moves water.
                        Haptics.commandSent();
                        provider.requestPump(!running);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: background,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: colors.panelMuted,
                  disabledForegroundColor: colors.inkTertiary,
                ),
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, size: 20),
                label: Text(label),
              ),
            ),
          ),
          const SizedBox(width: Tokens.space3),
          // Mode is the one control that stays live in every state — it is how
          // a farmer takes the pump back from the controller.
          Tooltip(
            message: auto ? 'Switch to manual' : 'Switch to automatic',
            child: SizedBox(
              width: 52,
              height: 52,
              child: IconButton.filledTonal(
                onPressed: () {
                  Haptics.commandSent();
                  provider.setMode(auto ? 'manual' : 'automatic');
                },
                icon: Icon(
                  auto ? Icons.auto_mode_rounded : Icons.pan_tool_alt_outlined,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: auto
                      ? colors.growth.withValues(alpha: 0.14)
                      : colors.sun.withValues(alpha: 0.16),
                  foregroundColor: auto ? colors.growth : colors.sun,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (String, IconData, Color) _button({
    required bool auto,
    required bool running,
    required bool busy,
    required bool connected,
    required FarmColors colors,
  }) {
    if (busy) return ('Sending…', Icons.hourglass_top_rounded, colors.sun);
    // Offline reads as a state, not a colour: the label carries it, because a
    // greyed-out button alone does not say *why* it cannot be pressed.
    if (!connected) {
      return (
        'Controller offline',
        Icons.cloud_off_outlined,
        colors.panelMuted,
      );
    }
    if (auto) {
      return (
        running ? 'Watering automatically' : 'Automatic control',
        Icons.auto_mode_rounded,
        colors.panelMuted,
      );
    }
    return running
        ? ('Stop watering', Icons.stop_rounded, colors.alert)
        : ('Water now', Icons.play_arrow_rounded, colors.water);
  }
}

/// The single line beneath the action bar explaining why it cannot be used, or
/// what a command is doing.
///
/// Kept separate from the button so the button's label never has to carry a
/// caveat — a label that changes length on every state change is hard to aim
/// at, and this is the control that moves water.
class FieldActionNote extends StatelessWidget {
  const FieldActionNote({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final colors = context.farmColors;
    final command = provider.command;

    final (text, tone) = switch (command.phase) {
      PumpCommandPhase.sending || PumpCommandPhase.awaitingDevice => (
        'The pump usually answers within 15 seconds.',
        colors.inkTertiary,
      ),
      PumpCommandPhase.confirmed => (
        'The controller confirmed the change.',
        colors.growth,
      ),
      PumpCommandPhase.failed ||
      PumpCommandPhase.timedOut => (command.message ?? '', colors.alert),
      PumpCommandPhase.rejected => (command.message ?? '', colors.inkTertiary),
      PumpCommandPhase.idle =>
        provider.data.isAutomatic
            ? (
                'The controller decides when to water. Switch to manual to run '
                    'the pump yourself.',
                colors.inkTertiary,
              )
            : ('', colors.inkTertiary),
    };

    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.space5,
        0,
        Tokens.space5,
        Tokens.space2,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tone, fontSize: 11.5),
      ),
    );
  }
}

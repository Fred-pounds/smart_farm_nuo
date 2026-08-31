import 'package:flutter/material.dart';

import '../models/alert.dart';
import '../theme/theme.dart';

/// Shared alert styling, so severity and category mean the same thing
/// wherever an alert appears.
class AlertStyle {
  const AlertStyle._();

  static Color color(BuildContext context, AlertSeverity severity) {
    final colors = context.farmColors;
    return switch (severity) {
      AlertSeverity.critical => colors.alert,
      AlertSeverity.warning => colors.sun,
      AlertSeverity.info => colors.water,
    };
  }

  /// The category's mark. Rounded family throughout.
  static IconData icon(AlertCategory category) => switch (category) {
    AlertCategory.soil => Icons.grass_rounded,
    AlertCategory.pump => Icons.water_drop_rounded,
    AlertCategory.sensor => Icons.sensors_rounded,
    AlertCategory.weather => Icons.cloud_rounded,
    AlertCategory.crop => Icons.eco_rounded,
  };

  /// The severity in a word.
  ///
  /// Printed beside the coloured mark rather than left to colour alone —
  /// "critical" and "warning" differ only in hue otherwise, and that is the
  /// one distinction on this screen that must survive a colour vision
  /// deficiency.
  static String label(AlertSeverity severity) => switch (severity) {
    AlertSeverity.critical => 'Critical',
    AlertSeverity.warning => 'Warning',
    AlertSeverity.info => 'Info',
  };
}

/// One alert: what is wrong, what it means, and — where one exists — the
/// single tap that fixes it.
///
/// Critical alerts take the accent border. Warnings and info do not: if
/// everything is outlined in its own colour, the list flattens and the one
/// entry that needs action stops standing out.
class AlertTile extends StatelessWidget {
  final FarmAlert alert;
  final VoidCallback? onAction;

  const AlertTile({super.key, required this.alert, this.onAction});

  @override
  Widget build(BuildContext context) {
    final accent = AlertStyle.color(context, alert.severity);
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final critical = alert.severity == AlertSeverity.critical;

    return Panel(
      accentBorder: critical ? accent.withValues(alpha: 0.4) : null,
      tinted: critical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AlertStyle.icon(alert.category),
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(AlertStyle.label(alert.severity), color: accent),
                    const SizedBox(height: 4),
                    Text(alert.title, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          Text(
            alert.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.inkSecondary,
            ),
          ),
          if (alert.actionLabel != null && onAction != null) ...[
            const SizedBox(height: Tokens.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // The remedies here reach the controller — a stop command,
                  // a mode change — so they get the heavier tap, not the
                  // selection tick.
                  Haptics.commandSent();
                  onAction!();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.14),
                  foregroundColor: accent,
                  minimumSize: const Size(0, 46),
                ),
                child: Text(alert.actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

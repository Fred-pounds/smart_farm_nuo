import 'package:flutter/material.dart';

import '../logic/field_band.dart';
import '../theme/theme.dart';

/// Soil, air and rain as one panel of three.
///
/// Divided rather than boxed separately: they are one reading of the farm, and
/// three separate cards would imply three separate decisions.
///
/// The status *sentence* these used to sit under now lives on the dashboard's
/// `InsightCard`, so this row is purely the numbers behind it.
class ReadingsRow extends StatelessWidget {
  final List<Reading> readings;

  const ReadingsRow({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Panel(
      padding: const EdgeInsets.symmetric(
        vertical: Tokens.space5,
        horizontal: Tokens.space3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < readings.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 44, color: colors.panelBorder),
            Expanded(child: _Cell(reading: readings[i])),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Reading reading;

  const _Cell({required this.reading});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final accent = switch (reading.tone) {
      ReadingTone.dry => colors.soilDry,
      ReadingTone.wet => colors.soilWet,
      ReadingTone.hot => colors.sun,
      ReadingTone.water => colors.water,
      ReadingTone.fault => colors.alert,
      ReadingTone.neutral => colors.inkPrimary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space2),
      child: Column(
        children: [
          Eyebrow(reading.label),
          const SizedBox(height: Tokens.space2),
          Text(
            reading.value,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: accent, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            reading.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.inkTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two compact tiles under the insight card: alerts and today's tasks.
///
/// Counts rather than banners. A banner that is present most days stops being
/// read; a count that changes is noticed.
class FieldLinkTiles extends StatelessWidget {
  final int alertCount;
  final String alertSummary;
  final bool alertIsCritical;
  final VoidCallback onOpenAlerts;

  final int taskCount;
  final String taskSummary;
  final VoidCallback onOpenTasks;

  const FieldLinkTiles({
    super.key,
    required this.alertCount,
    required this.alertSummary,
    required this.alertIsCritical,
    required this.onOpenAlerts,
    required this.taskCount,
    required this.taskSummary,
    required this.onOpenTasks,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _Tile(
            icon: alertCount == 0
                ? Icons.verified_rounded
                : Icons.warning_rounded,
            accent: alertCount == 0
                ? colors.growth
                : alertIsCritical
                ? colors.alert
                : colors.sun,
            title: alertCount == 0
                ? 'All clear'
                : '$alertCount alert${alertCount == 1 ? "" : "s"}',
            subtitle: alertSummary,
            onTap: onOpenAlerts,
          ),
        ),
        const SizedBox(width: Tokens.space3),
        Expanded(
          child: _Tile(
            icon: Icons.task_alt_rounded,
            accent: taskCount == 0 ? colors.inkTertiary : colors.growth,
            title: taskCount == 0
                ? 'No tasks'
                : '$taskCount task${taskCount == 1 ? "" : "s"} today',
            subtitle: taskSummary,
            onTap: onOpenTasks,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return PressableScale(
      onTap: onTap,
      child: Panel(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space4,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.inkTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

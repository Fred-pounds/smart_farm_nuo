import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/crop.dart';
import '../providers/farm_provider.dart';
import 'add_planting_screen.dart';
import '../theme/theme.dart';

/// Everything the knowledge base holds about one crop, plus the two actions
/// that connect it to the hardware: apply its irrigation threshold, or log it
/// as planted.
class CropDetailScreen extends StatelessWidget {
  final CropRecommendation recommendation;

  const CropDetailScreen({super.key, required this.recommendation});

  Crop get crop => recommendation.crop;

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return GlassScaffold(
      title: crop.name,
      subtitle: 'Scored ${recommendation.score} of 100 for your farm',
      insideShell: false,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddPlantingScreen(preselectedCropId: crop.id),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plant this'),
      ),
      builder: (context, contentPadding) => ListView(
        padding: contentPadding,
        children: [
          _Header(recommendation: recommendation),
          const SizedBox(height: 12),
          _ScoreBreakdown(recommendation: recommendation),
          const SizedBox(height: 12),
          _RequirementsCard(crop: crop),
          const SizedBox(height: 12),
          _ThresholdCard(crop: crop),
          const SizedBox(height: 12),
          _StagesCard(crop: crop),
          const SizedBox(height: 12),
          _ListCard(
            title: 'Grower tips',
            icon: Icons.lightbulb_outline_rounded,
            color: colors.warning,
            items: crop.tips,
          ),
          const SizedBox(height: 12),
          _ListCard(
            title: 'Watch out for',
            icon: Icons.pest_control_outlined,
            color: colors.danger,
            items: crop.commonPests,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final CropRecommendation recommendation;

  const _Header({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final crop = recommendation.crop;
    final colors = context.farmColors;

    return Panel(
      child: Column(
        children: [
          Text(crop.emoji, style: const TextStyle(fontSize: 46)),
          const SizedBox(height: 8),
          Text(
            crop.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${crop.category} · ${crop.daysToHarvest} days to harvest',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            crop.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final CropRecommendation recommendation;

  const _ScoreBreakdown({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final score = recommendation.score;
    final accent = switch (score) {
      >= 80 => colors.success,
      >= 65 => colors.soilWet,
      >= 45 => colors.warning,
      _ => colors.muted,
    };

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suitability',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$score / 100 · ${recommendation.verdict}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 7,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 16),
          for (final positive in recommendation.positives)
            _Reason(
              icon: Icons.check_circle_outline_rounded,
              color: colors.success,
              text: positive,
            ),
          for (final concern in recommendation.concerns)
            _Reason(
              icon: Icons.error_outline_rounded,
              color: colors.warning,
              text: concern,
            ),
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Reason({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementsCard extends StatelessWidget {
  final Crop crop;

  const _RequirementsCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growing requirements',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _Spec(
            icon: Icons.thermostat_rounded,
            label: 'Ideal temperature',
            value: crop.tempRange,
          ),
          _Spec(
            icon: Icons.water_drop_outlined,
            label: 'Water need',
            value:
                '${crop.waterNeedLabel} · '
                '${crop.seasonalRainfallMm} mm per season',
          ),
          _Spec(
            icon: Icons.science_outlined,
            label: 'Soil pH',
            value: crop.phRange,
          ),
          _Spec(
            icon: Icons.terrain_outlined,
            label: 'Soil type',
            value: crop.soilType,
          ),
          _Spec(
            icon: Icons.wb_sunny_outlined,
            label: 'Sunlight',
            value: crop.sunNeed == SunNeed.fullSun
                ? 'Full sun'
                : 'Partial shade tolerated',
          ),
          _Spec(
            icon: Icons.grid_on_outlined,
            label: 'Spacing',
            value: crop.spacing,
          ),
          _Spec(
            icon: Icons.event_outlined,
            label: 'Planting months',
            value: crop.plantingMonths.map(_shortMonth).join(', '),
          ),
        ],
      ),
    );
  }

  static String _shortMonth(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][(m - 1).clamp(0, 11)];
}

class _Spec extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Spec({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.muted),
          const SizedBox(width: 11),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Writes this crop's recommended dry threshold straight to the ESP32.
class _ThresholdCard extends StatelessWidget {
  final Crop crop;

  const _ThresholdCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final colors = context.farmColors;
    final current = farm.data.threshold;
    final isApplied = current == crop.recommendedThreshold;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: colors.water),
              const SizedBox(width: 8),
              Text(
                'Irrigation preset',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This crop waters best at a dry threshold of '
            '${crop.recommendedThreshold}. Your controller is currently set '
            'to $current.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
          ),
          const SizedBox(height: Tokens.space4),
          SizedBox(
            width: double.infinity,
            child: isApplied
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Already applied'),
                  )
                : FilledButton.tonal(
                    onPressed: () async {
                      await farm.setThreshold(crop.recommendedThreshold);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Threshold set to ${crop.recommendedThreshold} '
                              'for ${crop.name}',
                            ),
                          ),
                        );
                      }
                    },
                    child: Text('Apply ${crop.name} threshold'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StagesCard extends StatelessWidget {
  final Crop crop;

  const _StagesCard({required this.crop});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth calendar',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < crop.stages.length; i++)
            _StageRow(
              stage: crop.stages[i],
              isLast: i == crop.stages.length - 1,
              primary: primary,
              muted: colors.muted,
            ),
        ],
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  final GrowthStage stage;
  final bool isLast;
  final Color primary;
  final Color muted;

  const _StageRow({
    required this.stage,
    required this.isLast,
    required this.primary,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: primary.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stage.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        'day ${stage.startDay}–${stage.endDay}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 10.5, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stage.focus,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 6),
                  for (final task in stage.tasks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '· ',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                          Expanded(
                            child: Text(
                              task,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  const _ListCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

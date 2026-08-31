import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/crop_database.dart';
import '../logic/crop_recommender.dart';
import '../models/crop.dart';
import '../models/planting.dart';
import '../providers/farm_provider.dart';
import '../providers/planting_provider.dart';
import '../providers/weather_provider.dart';
import 'add_planting_screen.dart';
import 'crop_detail_screen.dart';
import '../theme/theme.dart';

/// Two views on crops: what the conditions suggest you *should* plant, and
/// what you have actually planted.
///
/// The recommended tab is a catalogue, not a list — search and category
/// filters sit above it, because fourteen crops is enough that "where is
/// cassava" becomes a scroll rather than a glance, and a farmer who already
/// knows what they want should not have to read thirteen scores to find it.
class CropsScreen extends StatelessWidget {
  const CropsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        title: 'Crops',
        subtitle: 'Scored against your live soil and forecast',
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Recommended'),
            Tab(text: 'My Crops'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Haptics.selection();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddPlantingScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log planting'),
        ),
        builder: (context, contentPadding) => TabBarView(
          children: [
            _RecommendationsTab(contentPadding: contentPadding),
            _MyCropsTab(contentPadding: contentPadding),
          ],
        ),
      ),
    );
  }
}

class _RecommendationsTab extends StatefulWidget {
  final EdgeInsets contentPadding;

  const _RecommendationsTab({required this.contentPadding});

  @override
  State<_RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<_RecommendationsTab> {
  final _search = TextEditingController();
  String _query = '';
  String _category = 'All';

  /// "All" plus every category the database actually uses, so no crop can be
  /// filtered out of reach by a hard-coded list that has drifted.
  late final List<String> _categories = [
    'All',
    ...{for (final c in CropDatabase.crops) c.category}.toList()..sort(),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final weather = context.watch<WeatherProvider>();

    final all = CropRecommender.recommend(
      soilMoistureRaw: farm.data.soilMoisture,
      weather: weather.report,
    );

    final query = _query.trim().toLowerCase();
    final matches = all.where((r) {
      final inCategory =
          _category == 'All' || r.crop.category == _category;
      final inSearch =
          query.isEmpty ||
          r.crop.name.toLowerCase().contains(query) ||
          r.crop.category.toLowerCase().contains(query);
      return inCategory && inSearch;
    }).toList();

    return ListView(
      padding: widget.contentPadding,
      children: [
        _ConditionsSummary(
          soilMoisture: farm.data.soilMoisture,
          threshold: farm.data.threshold,
          hasWeather: weather.report != null,
          avgTemp: weather.report?.averageMaxTempNext7Days,
          rain7d: weather.report?.totalRainfallNext7Days,
        ),
        const SizedBox(height: Tokens.space4),

        SearchField(
          hint: 'Search crops',
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: Tokens.space3),

        FilterChipRow(
          options: _categories,
          selected: _category,
          onSelected: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: Tokens.space5),

        SectionHeader(
          title: query.isEmpty && _category == 'All'
              ? 'Best matches right now'
              : '${matches.length} crop${matches.length == 1 ? "" : "s"}',
          trailing: DateFormat('MMMM').format(DateTime.now()),
        ),

        if (matches.isEmpty)
          EmptyState(
            art: FarmArt.cropGrowth,
            title: 'No crops match',
            message:
                'Nothing in the catalogue matches "$_query" in that '
                'category. Try a different search, or switch to All.',
            action: OutlinedButton(
              onPressed: () => setState(() {
                _search.clear();
                _query = '';
                _category = 'All';
              }),
              child: const Text('Clear filters'),
            ),
          )
        else
          for (var i = 0; i < matches.length; i++) ...[
            if (i > 0) const SizedBox(height: Tokens.space3),
            FadeSlideIn(index: i, child: CropCard(recommendation: matches[i])),
          ],
      ],
    );
  }
}

/// The conditions every score on this screen is derived from.
///
/// Placed above the list rather than inside each card: the three numbers are
/// the same for every crop, and repeating them fourteen times would bury the
/// one figure that actually differs.
class _ConditionsSummary extends StatelessWidget {
  final int soilMoisture;
  final int threshold;
  final bool hasWeather;
  final double? avgTemp;
  final double? rain7d;

  const _ConditionsSummary({
    required this.soilMoisture,
    required this.threshold,
    required this.hasWeather,
    this.avgTemp,
    this.rain7d,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final isDry = soilMoisture > threshold;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 16, color: colors.growth),
              const SizedBox(width: Tokens.space2),
              Text(
                'Scored against your conditions',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space5),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Soil',
                  value: soilMoisture > 0
                      ? '${SoilScale.percent(soilMoisture)}%'
                      : '—',
                  caption: soilMoisture > 0
                      ? (isDry ? 'dry' : 'moist')
                      : 'no reading',
                  accent: isDry ? colors.soilDry : colors.soilWet,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Avg high',
                  value: avgTemp != null ? '${avgTemp!.round()}°C' : '—',
                  caption: hasWeather ? 'next 7 d' : 'no data',
                  accent: colors.sun,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Rain',
                  value: rain7d != null ? '${rain7d!.round()} mm' : '—',
                  caption: hasWeather ? 'next 7 d' : 'no data',
                  accent: colors.water,
                ),
              ),
            ],
          ),
          if (!hasWeather) ...[
            const SizedBox(height: Tokens.space3),
            Text(
              'Weather is unavailable, so scores are based on soil moisture '
              'and planting season only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One crop in the catalogue.
///
/// Reads left to right as picture, name, reason, score. The score ring is on
/// the right rather than the left so the eye lands on the crop's name first —
/// a farmer scanning for tomatoes should not have to read fourteen numbers to
/// find them.
class CropCard extends StatelessWidget {
  final CropRecommendation recommendation;

  const CropCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final crop = recommendation.crop;
    final accent = accentFor(recommendation.score, colors);

    final reason = recommendation.positives.isNotEmpty
        ? recommendation.positives.first
        : recommendation.concerns.isNotEmpty
        ? recommendation.concerns.first
        : crop.description;

    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CropDetailScreen(recommendation: recommendation),
        ),
      ),
      child: Panel(
        padding: const EdgeInsets.all(Tokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CropImage(
                  cropId: crop.id,
                  emoji: crop.emoji,
                  accent: accent,
                  size: 60,
                ),
                const SizedBox(width: Tokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        recommendation.verdict,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                ScoreRing(
                  score: recommendation.score,
                  accent: accent,
                  size: 54,
                ),
              ],
            ),
            const SizedBox(height: Tokens.space4),
            Row(
              children: [
                _Meta(
                  icon: Icons.calendar_month_rounded,
                  label: plantingWindow(crop),
                ),
                const SizedBox(width: Tokens.space4),
                _Meta(
                  icon: Icons.water_drop_rounded,
                  label: crop.waterNeedLabel,
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.inkTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The score band, as a colour. Shared with the detail screen so a crop
  /// does not change colour when it is opened.
  static Color accentFor(int score, FarmColors c) => switch (score) {
    >= 80 => c.growth,
    >= 65 => c.soilWet,
    >= 45 => c.sun,
    _ => c.inkTertiary,
  };

  /// "Plant now", or the next month the crop's window opens.
  ///
  /// A bare list of month numbers is unreadable on a card, and the only thing
  /// a farmer wants from it is whether they can plant today.
  static String plantingWindow(Crop crop) {
    if (crop.plantingMonths.isEmpty) return 'Any month';

    final month = DateTime.now().month;
    if (crop.plantingMonths.contains(month)) return 'Plant now';

    // The next month in the window, wrapping into next year.
    final sorted = [...crop.plantingMonths]..sort();
    final next = sorted.firstWhere((m) => m > month, orElse: () => sorted.first);
    return 'From ${DateFormat('MMM').format(DateTime(2000, next))}';
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.inkTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
      ],
    );
  }
}

class _MyCropsTab extends StatelessWidget {
  final EdgeInsets contentPadding;

  const _MyCropsTab({required this.contentPadding});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantingProvider>();

    if (!provider.isLoaded) {
      return ListView(
        padding: contentPadding,
        children: const [ListSkeleton(count: 3, thumbSize: 60)],
      );
    }

    if (provider.isEmpty) {
      return ListView(
        padding: contentPadding,
        children: [
          EmptyState(
            art: FarmArt.cropGrowth,
            title: 'Nothing logged yet',
            message:
                'Log what you have planted and the app will track growth '
                'stages, generate a task schedule, and size your water use.',
            action: FilledButton.icon(
              onPressed: () {
                Haptics.selection();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddPlantingScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Log a planting'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: contentPadding,
      itemCount: provider.plantings.length,
      separatorBuilder: (_, _) => const SizedBox(height: Tokens.space3),
      itemBuilder: (context, index) {
        final planting = provider.plantings[index];
        return FadeSlideIn(
          index: index,
          child: _PlantingCard(
            planting: planting,
            crop: provider.cropFor(planting),
            stage: provider.stageFor(planting),
            onDelete: () => _confirmDelete(context, provider, planting),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlantingProvider provider,
    Planting planting,
  ) async {
    Haptics.warn();
    final crop = provider.cropFor(planting);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove planting?'),
        content: Text(
          'This removes ${crop?.name ?? "this crop"} in ${planting.fieldName} '
          'from your log, along with its generated tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.farmColors.alert,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) await provider.remove(planting.id);
  }
}

/// One logged planting: how far through the season it is, and what the
/// current stage asks for.
class _PlantingCard extends StatelessWidget {
  final Planting planting;
  final Crop? crop;
  final GrowthStage? stage;
  final VoidCallback onDelete;

  const _PlantingCard({
    required this.planting,
    required this.crop,
    required this.stage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    if (crop == null) {
      return Panel(
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded, color: colors.inkTertiary),
            const SizedBox(width: Tokens.space3),
            Expanded(
              child: Text(
                'Crop id "${planting.cropId}" is no longer in the catalogue.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Remove',
              onPressed: onDelete,
            ),
          ],
        ),
      );
    }

    final daysLeft = planting.daysToHarvestFrom(crop!.daysToHarvest);
    final progress = planting.progressFor(crop!.daysToHarvest);
    final ready = daysLeft <= 0;
    final accent = ready ? colors.growth : colors.water;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CropImage(
                cropId: crop!.id,
                emoji: crop!.emoji,
                accent: accent,
                size: 56,
              ),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop!.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '${planting.fieldName} · '
                      '${planting.areaSqm.round()} m² · planted '
                      '${DateFormat('d MMM').format(planting.plantedOn)}',
                      maxLines: 2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: colors.inkTertiary,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: Tokens.space5),
          Row(
            children: [
              StatusPill(
                label: stage?.name ?? 'Growing',
                color: colors.growth,
              ),
              const Spacer(),
              Text(
                daysLeft > 0
                    ? '$daysLeft days to harvest'
                    : daysLeft == 0
                    ? 'Harvest today'
                    : 'Ready — ${-daysLeft} days past',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: ready ? colors.growth : colors.inkSecondary,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          MeterBar(value: progress, accent: accent, height: 8),
          if (stage != null) ...[
            const SizedBox(height: Tokens.space4),
            PanelWell(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.flag_rounded, size: 14, color: colors.growth),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: Text(
                      stage!.focus,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/alert_builder.dart';
import '../models/alert.dart';
import '../logic/farm_status.dart';
import '../logic/field_band.dart';
import '../logic/irrigation_advisor.dart';
import '../logic/rain_outlook.dart';
import '../providers/farm_profile_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/history_provider.dart';
import '../providers/planting_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/theme.dart';
import '../widgets/analytics_cards.dart';
import '../widgets/farm_header.dart';
import '../widgets/field_band_widgets.dart';
import '../widgets/hero_field_card.dart';
import '../widgets/moisture_chart_card.dart';
import 'alerts_screen.dart';
import 'assistant_screen.dart';
import 'settings_screen.dart';

/// The Farm screen.
///
/// Reads top to bottom as one answer to "what is happening and do I need to
/// act":
///
/// 1. **Who and where** — the header, plus today's weather and one status
///    word.
/// 2. **The reading** — the hero gauge, the pump, and who commands it.
/// 3. **The decision** — one insight card, with the reasoning a tap away.
/// 4. **What needs you** — alerts and today's tasks, as counts.
/// 5. **The record** — moisture, water and temperature over time.
///
/// The pump's start/stop lives in the thumb zone above the navigation bar
/// (`FieldActionBar`), not in this list, because it is the one control a
/// farmer reaches for while standing in a field with one hand full.
class DashboardScreen extends StatelessWidget {
  /// Switches the shell to another tab.
  final ValueChanged<int> onOpenTab;

  const DashboardScreen({super.key, required this.onOpenTab});

  static const double _headerHeight = 58;

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final weather = context.watch<WeatherProvider>();
    final history = context.watch<HistoryProvider>();
    final plantings = context.watch<PlantingProvider>();
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<FarmProfileProvider>();

    final alerts = AlertBuilder.build(
      farm: farm.data,
      isConnected: farm.isConnected,
      weather: weather.report,
      history: history.readings,
      tasks: plantings.tasks,
      command: farm.command,
    );

    final hasLiveData =
        history.readings.isNotEmpty || farm.data.soilMoisture > 0;

    final advice = IrrigationAdvisor.advise(
      farm: farm.data,
      weather: weather.report,
      fieldAreaSqm: settings.fieldAreaSqm,
      hasLiveData: hasLiveData,
    );

    final status = FarmStatusReporter.of(
      farm: farm.data,
      isConnected: farm.isConnected,
      advice: advice,
    );

    final band = FieldBand.of(
      farmName: profile.displayName,
      farm: farm.data,
      isConnected: farm.isConnected,
      command: farm.command,
      status: status,
      advice: advice,
    );

    final outlook = RainForecaster.forecast(weather.report);
    final readings = Reading.from(
      farm: farm.data,
      rainMm: outlook.isKnown ? outlook.millimetres : null,
      rainProbability: outlook.probability,
      rainWhen: _rainWhen(outlook),
    );

    final dueToday = plantings.tasks
        .where((t) => t.isOverdue || _isToday(t.dueDate))
        .toList();

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    // Until the first reading lands there is nothing to draw a gauge from, so
    // the hero shows its skeleton rather than an arc at zero — which a farmer
    // would correctly read as bone-dry soil.
    final awaitingFirstReading = !hasLiveData && !farm.isConnected;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            Haptics.selection();
            await weather.refresh();
          },
          edgeOffset: topInset + _headerHeight,
          child: ListView(
            padding: EdgeInsets.only(
              top: topInset + _headerHeight + Tokens.space5,
              left: Tokens.space5,
              right: Tokens.space5,
              // Clears the navigation bar *and* the action bar sitting on it.
              bottom: media.padding.bottom + 150,
            ),
            children: [
              FadeSlideIn(
                index: 0,
                child: ConditionsStrip(
                  weather: weather.report,
                  tone: band.tone,
                  statusLabel: _statusLabel(band.tone),
                  onOpenWeather: () => onOpenTab(1),
                ),
              ),
              const SizedBox(height: Tokens.space4),

              FadeSlideIn(
                index: 1,
                child: awaitingFirstReading
                    ? const HeroCardSkeleton()
                    : const HeroFieldCard(),
              ),
              const SizedBox(height: Tokens.space3),

              FadeSlideIn(
                index: 2,
                child: InsightCard(
                  headline: band.headline,
                  detail: band.detail,
                  accent: _toneColor(band.tone, context.farmColors),
                  icon: _toneIcon(band.tone),
                  onWhy: band.why == null
                      ? null
                      : () => _showWhy(context, band),
                ),
              ),
              const SizedBox(height: Tokens.space3),

              FadeSlideIn(
                index: 3,
                child: FieldLinkTiles(
                  alertCount: alerts.length,
                  alertSummary: _alertSummary(alerts),
                  alertIsCritical: alerts.any(
                    (a) => a.severity == AlertSeverity.critical,
                  ),
                  onOpenAlerts: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  ),
                  taskCount: dueToday.length,
                  taskSummary: dueToday.isEmpty
                      ? 'nothing due'
                      : '${dueToday.first.cropName}: ${dueToday.first.title}',
                  onOpenTasks: () => onOpenTab(4),
                ),
              ),
              const SizedBox(height: Tokens.space6),

              const SectionHeader(title: 'Conditions'),
              FadeSlideIn(index: 4, child: ReadingsRow(readings: readings)),
              const SizedBox(height: Tokens.space6),

              const SectionHeader(title: 'Analytics'),
              const FadeSlideIn(index: 5, child: MoistureChartCard()),
              const SizedBox(height: Tokens.space3),
              const FadeSlideIn(index: 6, child: WaterUsageCard()),
              const SizedBox(height: Tokens.space3),
              const FadeSlideIn(index: 7, child: TemperatureTrendCard()),
            ],
          ),
        ),
        FarmHeader(
          farmName: profile.displayName,
          farmerName: settings.farmerName,
          height: _headerHeight,
          topInset: topInset,
          onOpenAssistant: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AssistantScreen())),
          onOpenSettings: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ],
    );
  }

  /// One or two words for the status badge beside the weather.
  ///
  /// Derived from the tone rather than from the status headline, because the
  /// headline is a sentence and this is a pill — truncating "Controller
  /// offline, readings are not updating" into a badge loses exactly the half
  /// that matters.
  static String _statusLabel(FarmTone tone) => switch (tone) {
    FarmTone.settled => 'All good',
    FarmTone.working => 'Watering',
    FarmTone.caution => 'Check soon',
    FarmTone.fault => 'Needs you',
  };

  static Color _toneColor(FarmTone tone, FarmColors c) => switch (tone) {
    FarmTone.settled => c.growth,
    FarmTone.working => c.water,
    FarmTone.caution => c.sun,
    FarmTone.fault => c.alert,
  };

  /// The mark on the insight card. Distinct per tone, so the card is
  /// recognisable before it is read — colour alone would not survive a
  /// colour-vision deficiency.
  static IconData _toneIcon(FarmTone tone) => switch (tone) {
    FarmTone.settled => Icons.check_circle_rounded,
    FarmTone.working => Icons.water_drop_rounded,
    FarmTone.caution => Icons.error_rounded,
    FarmTone.fault => Icons.warning_rounded,
  };

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _rainWhen(RainOutlook outlook) {
    final hour = outlook.firstRainHour;
    if (hour == null) return '${outlook.probability}% chance';
    final hours = hour.time.difference(DateTime.now()).inHours;
    if (hours <= 0) return 'within the hour';
    return 'in about ${hours}h';
  }

  static String _alertSummary(List<FarmAlert> alerts) {
    if (alerts.isEmpty) return 'nothing needs attention';
    if (alerts.length == 1) return alerts.first.title;
    return alerts.take(2).map((a) => a.title.toLowerCase()).join(', ');
  }

  void _showWhy(BuildContext context, FieldBand band) {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // The sheet explains a decision the farmer may act on, so it gets a
      // proper scrim: it darkens the dashboard behind the text instead of
      // leaving it showing through as competing detail.
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (_) => _WhySheet(band: band),
    );
  }
}

/// The explanation behind the insight card.
///
/// Painted on the **opaque** panel colour, not [GlassSurface]. This is prose
/// the farmer reads and acts on, and `GlassSurface`'s own contract restricts
/// it to chrome for exactly this reason: a paragraph over a live blur of
/// whatever happened to be scrolled underneath is the first thing that stops
/// being readable in daylight.
class _WhySheet extends StatelessWidget {
  final FieldBand band;

  const _WhySheet({required this.band});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Tokens.radiusXl),
        ),
        border: Border(top: BorderSide(color: colors.panelBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.space5,
            Tokens.space3,
            Tokens.space5,
            Tokens.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle: says "drag me down" without a line of text.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: Tokens.space5),
                  decoration: BoxDecoration(
                    color: colors.inkTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(band.headline, style: theme.textTheme.titleLarge),
              const SizedBox(height: Tokens.space3),
              // Body copy at primary ink, not secondary. Secondary is sized
              // for labels beside a value that carries the meaning; here the
              // sentence *is* the meaning.
              Text(
                band.why ?? band.detail,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.inkPrimary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: Tokens.space6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

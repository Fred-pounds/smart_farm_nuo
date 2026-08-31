import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../logic/rain_outlook.dart';
import '../logic/weather_advice.dart';
import '../models/weather.dart';
import '../providers/farm_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/sky_backdrop.dart';
import '../widgets/weather_icon.dart';
import 'settings_screen.dart';
import '../theme/theme.dart';

/// Full forecast, framed around farming decisions rather than generic weather.
///
/// This is the **one screen where glass carries content**. Everywhere else a
/// reading sits on an opaque [Panel], because the app is read outdoors and
/// text over a blur is the first thing to fail in daylight. Here the
/// exception is earned: the screen paints its own sky gradient, so what sits
/// under the blur is known and bounded rather than arbitrary, and the subject
/// genuinely is atmosphere.
///
/// The decisions come first. A farmer opening this screen wants to know
/// whether to irrigate, spray or scout — not the dew point — so the four
/// signal cards sit directly under the temperature, above the hour-by-hour
/// detail that justifies them.
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();
    final report = provider.report;

    return GlassScaffold(
      title: 'Weather',
      subtitle: report?.locationName,
      onRefresh: provider.refresh,
      actions: [
        IconButton(
          tooltip: 'Change location',
          icon: const Icon(Icons.place_rounded, size: 21),
          onPressed: () {
            Haptics.selection();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
        ),
      ],
      builder: (context, contentPadding) {
        final body = switch (provider.status) {
          WeatherStatus.error when report == null => ListView(
            padding: contentPadding,
            children: [
              _ErrorState(
                message: provider.error ?? 'Weather unavailable',
                onRetry: provider.refresh,
              ),
            ],
          ),
          _ when report == null => ListView(
            padding: contentPadding,
            children: const [
              ChartSkeleton(height: 180),
              SizedBox(height: Tokens.space3),
              ListSkeleton(count: 3, thumbSize: 40),
            ],
          ),
          _ => _Forecast(
            report: report,
            contentPadding: contentPadding,
            usingFallback: provider.usingFallbackLocation,
          ),
        };

        // The sky sits behind the content and behind the glass header, so the
        // blur has a real gradient to pick up rather than flat canvas.
        return Stack(
          children: [
            Positioned.fill(
              child: SkyBackdrop(
                condition: report?.current.condition,
                isDay: report?.current.isDay ?? true,
              ),
            ),
            body,
          ],
        );
      },
    );
  }
}

class _Forecast extends StatelessWidget {
  final WeatherReport report;
  final EdgeInsets contentPadding;
  final bool usingFallback;

  const _Forecast({
    required this.report,
    required this.contentPadding,
    required this.usingFallback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final heat = WeatherAdvisor.heatNote(report);

    return ListView(
      padding: contentPadding,
      children: [
        FadeSlideIn(
          index: 0,
          child: _CurrentPanel(report: report, usingFallback: usingFallback),
        ),
        const SizedBox(height: Tokens.space6),

        const SectionHeader(title: 'What this means for the farm'),
        FadeSlideIn(index: 1, child: _SignalGrid(report: report)),

        if (heat != null) ...[
          const SizedBox(height: Tokens.space3),
          FadeSlideIn(
            index: 2,
            child: InsightCard(
              headline: 'Heat stress',
              detail: heat,
              accent: colors.sun,
              icon: Icons.wb_sunny_rounded,
            ),
          ),
        ],
        const SizedBox(height: Tokens.space3),
        const FadeSlideIn(index: 3, child: ControllerHandoffRow()),
        const SizedBox(height: Tokens.space6),

        const SectionHeader(title: 'Next 24 hours'),
        FadeSlideIn(index: 4, child: _HourlyStrip(report: report)),
        const SizedBox(height: Tokens.space6),

        SectionHeader(
          title: 'Seven days',
          trailing: '${report.totalRainfallNext7Days.round()} mm',
        ),
        FadeSlideIn(index: 5, child: _DailyForecastCard(report: report)),
        const SizedBox(height: Tokens.space3),
        Text(
          WeatherAdvisor.weekNote(report),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
        const SizedBox(height: Tokens.space4),
        _AttributionRow(fetchedAt: report.fetchedAt),
      ],
    );
  }
}

/// The hero: condition, temperature, and the four ambient figures.
class _CurrentPanel extends StatelessWidget {
  final WeatherReport report;
  final bool usingFallback;

  const _CurrentPanel({required this.report, required this.usingFallback});

  @override
  Widget build(BuildContext context) {
    final current = report.current;
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return WeatherGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space5,
        vertical: Tokens.space6,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.place_rounded, size: 13, color: colors.inkTertiary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  report.locationName,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (usingFallback) ...[
            const SizedBox(height: 4),
            Text(
              'Default location — set your farm in Settings',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                color: colors.sun,
              ),
            ),
          ],
          const SizedBox(height: Tokens.space5),
          WeatherIcon(
            condition: current.condition,
            isDay: current.isDay,
            size: 72,
          ),
          const SizedBox(height: Tokens.space4),
          Text(
            '${current.temperatureC.round()}°',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 56,
              letterSpacing: -2.5,
            ),
          ),
          Text(
            current.condition.label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.inkSecondary,
            ),
          ),
          const SizedBox(height: Tokens.space6),
          Row(
            children: [
              _Stat(
                icon: Icons.thermostat_rounded,
                label: 'Feels like',
                value: '${current.feelsLikeC.round()}°',
              ),
              _Stat(
                icon: Icons.water_rounded,
                label: 'Humidity',
                value: '${current.humidity.round()}%',
              ),
              _Stat(
                icon: Icons.air_rounded,
                label: 'Wind',
                value: '${current.windKph.round()} km/h',
              ),
              _Stat(
                icon: Icons.grain_rounded,
                label: 'Rain now',
                value: '${current.precipitationMm.toStringAsFixed(1)} mm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The four farming decisions, as a 2×2 grid.
///
/// A grid rather than the bullet list this replaced. The four cards are
/// always present and always in the same order, so their positions become
/// learnable — a farmer checking whether to spray looks bottom-right without
/// reading the other three.
class _SignalGrid extends StatelessWidget {
  final WeatherReport report;

  const _SignalGrid({required this.report});

  @override
  Widget build(BuildContext context) {
    final signals = WeatherAdvisor.signals(report);

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: Tokens.space3),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SignalCard(signal: signals[row * 2])),
                const SizedBox(width: Tokens.space3),
                Expanded(child: _SignalCard(signal: signals[row * 2 + 1])),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  final FarmingSignal signal;

  const _SignalCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final accent = _accent(signal.level, colors);

    return WeatherGlassCard(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(signal.title), size: 14, color: accent),
              const SizedBox(width: 5),
              Flexible(child: Eyebrow(signal.title)),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          Text(
            signal.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(color: accent),
          ),
          const SizedBox(height: Tokens.space2),
          Text(
            signal.detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.inkSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Level drives the colour, and the icon is fixed per card — so the two
  /// signals never collapse into one. Colour alone would leave a farmer with
  /// a colour vision deficiency reading four identical boxes.
  static Color _accent(SignalLevel level, FarmColors c) => switch (level) {
    SignalLevel.good => c.growth,
    SignalLevel.watch => c.water,
    SignalLevel.act => c.sun,
  };

  static IconData _icon(String title) => switch (title) {
    'Irrigation' => Icons.water_drop_rounded,
    'Rain' => Icons.umbrella_rounded,
    'Disease risk' => Icons.coronavirus_rounded,
    _ => Icons.sanitizer_rounded,
  };
}

class _HourlyStrip extends StatelessWidget {
  final WeatherReport report;

  const _HourlyStrip({required this.report});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final upcoming = report.hourly
        .where((h) => h.time.isAfter(now.subtract(const Duration(hours: 1))))
        .take(24)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return WeatherGlassCard(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space5),
      child: SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space5),
          itemCount: upcoming.length,
          separatorBuilder: (_, _) => const SizedBox(width: Tokens.space5),
          itemBuilder: (context, index) {
            final hour = upcoming[index];
            final isNow = index == 0;
            final wet = hour.precipitationProbability >= 50;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isNow ? 'Now' : DateFormat('HH:mm').format(hour.time),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    color: isNow ? colors.growth : colors.inkTertiary,
                    fontWeight: isNow ? FontWeight.w700 : FontWeight.w600,
                    fontVariations: [FontVariation('wght', isNow ? 700 : 600)],
                  ),
                ),
                const SizedBox(height: Tokens.space3),
                WeatherIcon(condition: hour.condition, size: 24),
                const SizedBox(height: Tokens.space3),
                Text(
                  '${hour.temperatureC.round()}°',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  '${hour.precipitationProbability}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10.5,
                    color: wet ? colors.water : colors.inkTertiary,
                    fontWeight: wet ? FontWeight.w700 : FontWeight.w400,
                    fontVariations: [FontVariation('wght', wet ? 700 : 400)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DailyForecastCard extends StatelessWidget {
  final WeatherReport report;

  const _DailyForecastCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    if (report.daily.isEmpty) return const SizedBox.shrink();

    // One shared temperature scale, so the bars are comparable across rows —
    // a per-row scale would make every day look equally warm.
    final allMax = report.daily
        .map((d) => d.maxTempC)
        .reduce((a, b) => a > b ? a : b);
    final allMin = report.daily
        .map((d) => d.minTempC)
        .reduce((a, b) => a < b ? a : b);
    final span = (allMax - allMin).abs() < 1 ? 1.0 : allMax - allMin;

    return WeatherGlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space5,
        vertical: Tokens.space4,
      ),
      child: Column(
        children: [
          for (final day in report.daily)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      _dayLabel(day.date),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  WeatherIcon(condition: day.condition, size: 20),
                  const SizedBox(width: Tokens.space3),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '${day.precipitationMm.toStringAsFixed(0)} mm',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10.5,
                        color: day.precipitationMm > 0
                            ? colors.water
                            : colors.inkTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _TempBar(
                      min: day.minTempC,
                      max: day.maxTempC,
                      scaleMin: allMin,
                      scaleSpan: span,
                    ),
                  ),
                  const SizedBox(width: Tokens.space3),
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${day.minTempC.round()}° ${day.maxTempC.round()}°',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFeatures: Tokens.tabular,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime date) {
    final today = DateTime.now();
    if (date.day == today.day && date.month == today.month) return 'Today';
    return DateFormat('EEE').format(date);
  }
}

/// A day's temperature range, positioned on the week's shared scale.
class _TempBar extends StatelessWidget {
  final double min;
  final double max;
  final double scaleMin;
  final double scaleSpan;

  const _TempBar({
    required this.min,
    required this.max,
    required this.scaleMin,
    required this.scaleSpan,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final startFraction = ((min - scaleMin) / scaleSpan).clamp(0.0, 1.0);
    final endFraction = ((max - scaleMin) / scaleSpan).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = width * startFraction;
        final barWidth = (width * (endFraction - startFraction)).clamp(
          8.0,
          width,
        );

        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.inkTertiary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const SizedBox(width: double.infinity, height: 6),
              ),
              Positioned(
                left: left.clamp(0.0, width - 8),
                child: Container(
                  width: barWidth,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.waterBright, colors.sunBright],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 17, color: colors.inkTertiary),
          const SizedBox(height: Tokens.space2),
          Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: Tokens.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10.5,
              color: colors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttributionRow extends StatelessWidget {
  final DateTime fetchedAt;

  const _AttributionRow({required this.fetchedAt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Open-Meteo · updated ${DateFormat('HH:mm').format(fetchedAt)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10.5,
          color: context.farmColors.inkTertiary,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      art: FarmArt.offline,
      title: 'Weather unavailable',
      message: message,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Try again'),
      ),
    );
  }
}

/// What the app actually told the controller about rain.
///
/// The ESP32 cannot fetch a forecast; it acts on the two values the app
/// publishes. Showing them next to the forecast makes the handoff visible, so
/// a weather layer that has silently stopped working is noticeable rather
/// than assumed to be fine.
class ControllerHandoffRow extends StatelessWidget {
  const ControllerHandoffRow({super.key});

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final holding = farm.data.rainExpected;
    final accent = holding ? colors.water : colors.inkTertiary;
    final note = farm.weatherPublicationNote;

    return WeatherGlassCard(
      padding: const EdgeInsets.all(Tokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            holding
                ? Icons.pause_circle_rounded
                : Icons.play_circle_outline_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding
                      ? 'Irrigation on hold — ${farm.data.rainProbability}% '
                            'rain sent to the controller'
                      : 'Controller watering on soil readings alone',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
                if (note != null && note != WeatherPublisher.upToDate) ...[
                  const SizedBox(height: 3),
                  Text(
                    note,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.inkTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

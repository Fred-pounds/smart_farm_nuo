import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sensor_reading.dart';
import '../models/weather.dart';
import '../providers/history_provider.dart';
import '../providers/weather_provider.dart';
import '../theme/theme.dart';

/// Water actually used, in litres.
///
/// The controller reports pump runtime, not volume. Litres here are runtime ×
/// the flow rate configured in Settings, which is an estimate and is labelled
/// as one — a farmer planning against a water budget needs to know the number
/// is derived, not metered.
class WaterUsageCard extends StatelessWidget {
  const WaterUsageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<HistoryProvider>().stats;
    final colors = context.farmColors;
    final theme = Theme.of(context);

    // Today as a share of the week, so the bar answers "is today heavy?"
    // rather than restating a number that is already printed above it.
    final share = stats.litresThisWeek > 0
        ? (stats.litresToday / stats.litresThisWeek).clamp(0.0, 1.0)
        : 0.0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_rounded, size: 16, color: colors.water),
              const SizedBox(width: Tokens.space2),
              Text('Water used', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: Tokens.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedCount(
                value: stats.litresToday,
                decimals: stats.litresToday < 10 ? 1 : 0,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: colors.water,
                ),
              ),
              const SizedBox(width: Tokens.space2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'litres today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          MeterBar(value: share, accent: colors.waterBright),
          const SizedBox(height: Tokens.space4),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Cycles',
                  value: '${stats.cyclesToday}',
                  caption: 'today',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Runtime',
                  value: _duration(stats.runtimeToday),
                  caption: 'today',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'This week',
                  value: '${stats.litresThisWeek.round()} L',
                  caption: _duration(stats.runtimeThisWeek),
                ),
              ),
            ],
          ),
          if (stats.litresThisWeek == 0) ...[
            const SizedBox(height: Tokens.space3),
            Text(
              'No irrigation recorded yet this week.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _duration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}

/// The next 24 hours of air temperature, as a sparkline.
///
/// Paired with the moisture chart rather than shown on the Weather tab
/// because it is the reason moisture will move: a farmer reading a falling
/// soil curve wants the day's heat in the same glance.
class TemperatureTrendCard extends StatelessWidget {
  const TemperatureTrendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider>();
    final colors = context.farmColors;
    final theme = Theme.of(context);

    final now = DateTime.now();
    final hours = (weather.report?.hourly ?? const <HourlyForecast>[])
        .where((h) => h.time.isAfter(now.subtract(const Duration(hours: 1))))
        .take(24)
        .toList();

    if (hours.length < 3) {
      return Panel(
        child: Row(
          children: [
            const FarmIllustration(
              art: FarmArt.weather,
              size: 56,
              showBackdrop: false,
            ),
            const SizedBox(width: Tokens.space4),
            Expanded(
              child: Text(
                'Temperature trend appears once a forecast has been '
                'downloaded.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkTertiary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final temps = hours.map((h) => h.temperatureC).toList();
    final min = temps.reduce((a, b) => a < b ? a : b);
    final max = temps.reduce((a, b) => a > b ? a : b);
    final peak = hours[temps.indexOf(max)];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.thermostat_rounded, size: 16, color: colors.sun),
              const SizedBox(width: Tokens.space2),
              Text('Temperature', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                'next 24 h',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space4),
          SizedBox(
            height: 72,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Tokens.motionGauge,
              curve: Tokens.curveGauge,
              builder: (context, progress, _) => CustomPaint(
                painter: _SparklinePainter(
                  values: temps,
                  progress: progress,
                  line: colors.sunBright,
                  fill: colors.sunBright.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Low',
                  value: '${min.round()}°C',
                  accent: colors.water,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'High',
                  value: '${max.round()}°C',
                  accent: colors.sun,
                  caption: 'at ${DateFormat('HH:mm').format(peak.time)}',
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Now',
                  value:
                      '${weather.report!.current.temperatureC.round()}°C',
                  caption:
                      'feels ${weather.report!.current.feelsLikeC.round()}°',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A filled sparkline that draws itself left to right.
///
/// No axes and no gridlines: at this size they would cost more legibility
/// than they add, and the three figures printed beneath the chart carry the
/// actual values.
class _SparklinePainter extends CustomPainter {
  final List<double> values;

  /// 0–1 draw-on progress.
  final double progress;

  final Color line;
  final Color fill;

  const _SparklinePainter({
    required this.values,
    required this.progress,
    required this.line,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    // A flat forecast would otherwise divide by zero and draw at the top
    // edge; 1° of span keeps it centred.
    final span = (max - min).abs() < 1 ? 1.0 : max - min;

    final count = (values.length * progress).ceil().clamp(2, values.length);
    final step = size.width / (values.length - 1);

    Offset pointAt(int i) => Offset(
      i * step,
      size.height - ((values[i] - min) / span) * (size.height - 8) - 4,
    );

    final path = Path()..moveTo(0, pointAt(0).dy);
    for (var i = 1; i < count; i++) {
      final p = pointAt(i);
      final prev = pointAt(i - 1);
      // Horizontal control points give a smooth curve without letting it
      // overshoot past a local maximum, which on a temperature chart would
      // invent a peak that is not in the forecast.
      path.cubicTo(
        prev.dx + step / 2,
        prev.dy,
        p.dx - step / 2,
        p.dy,
        p.dx,
        p.dy,
      );
    }

    final area = Path.from(path)
      ..lineTo(pointAt(count - 1).dx, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(area, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // A dot on the leading edge, so the eye lands on "now" first.
    canvas.drawCircle(pointAt(0), 3.5, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.progress != progress || old.values != values || old.line != line;
}

/// Compact irrigation figures for anywhere that is not the dashboard.
class IrrigationStatsRow extends StatelessWidget {
  final IrrigationStats stats;

  const IrrigationStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Today',
            value: '${stats.litresToday.round()} L',
            accent: colors.water,
            caption: '${stats.cyclesToday} cycles',
          ),
        ),
        Expanded(
          child: StatTile(
            label: 'This week',
            value: '${stats.litresThisWeek.round()} L',
            accent: colors.water,
          ),
        ),
      ],
    );
  }
}

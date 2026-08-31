import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/sensor_reading.dart';
import '../providers/farm_provider.dart';
import '../providers/history_provider.dart';
import '../theme/theme.dart';

/// Soil moisture over time, with the dry threshold drawn as a reference line
/// and irrigation events shaded underneath.
class MoistureChartCard extends StatefulWidget {
  const MoistureChartCard({super.key});

  @override
  State<MoistureChartCard> createState() => _MoistureChartCardState();
}

class _MoistureChartCardState extends State<MoistureChartCard> {
  static const _ranges = {'24 h': 24, '3 d': 72, '7 d': 168};
  String _selected = '24 h';

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final threshold = context.watch<FarmProvider>().data.threshold;
    final colors = context.farmColors;

    final readings = history.recent(_ranges[_selected]!);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 16, color: colors.soilWet),
              const SizedBox(width: Tokens.space2),
              Expanded(
                child: Text(
                  'Soil moisture',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _RangeToggle(
                options: _ranges.keys.toList(),
                selected: _selected,
                onChanged: (value) => setState(() => _selected = value),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space5),
          SizedBox(
            height: 180,
            child: readings.length < 2
                ? _EmptyChart(range: _selected)
                : _Chart(
                    readings: readings,
                    threshold: threshold,
                    colors: colors,
                  ),
          ),
          const SizedBox(height: Tokens.space3),
          Row(
            children: [
              _Legend(color: colors.soilWet, label: 'Soil moisture'),
              const SizedBox(width: 16),
              _Legend(
                color: colors.soilDry,
                label: 'Dry threshold',
                dashed: true,
              ),
              const Spacer(),
              Text(
                '${readings.length} samples',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: colors.inkTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  final List<SensorReading> readings;
  final int threshold;
  final FarmColors colors;

  const _Chart({
    required this.readings,
    required this.threshold,
    required this.colors,
  });

  /// Axis labels sit at the very bottom of the type scale — they are a
  /// reference the eye returns to, never something read first.
  static TextStyle _axisStyle(BuildContext context, FarmColors colors) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 9.5,
        color: colors.inkTertiary,
        fontFeatures: Tokens.tabular,
      );

  @override
  Widget build(BuildContext context) {
    final firstMs = readings.first.timestamp.millisecondsSinceEpoch.toDouble();
    final lastMs = readings.last.timestamp.millisecondsSinceEpoch.toDouble();

    final spots = readings
        .map(
          (r) => FlSpot(
            r.timestamp.millisecondsSinceEpoch.toDouble(),
            r.soilMoisture.toDouble(),
          ),
        )
        .toList();

    final values = readings.map((r) => r.soilMoisture).toList();
    final rawMin = values.reduce((a, b) => a < b ? a : b).toDouble();
    final rawMax = values.reduce((a, b) => a > b ? a : b).toDouble();

    // Keep the threshold line inside the visible band, with a little padding.
    final minY = ((rawMin < threshold ? rawMin : threshold.toDouble()) - 150)
        .clamp(0.0, 4095.0);
    final maxY = ((rawMax > threshold ? rawMax : threshold.toDouble()) + 150)
        .clamp(0.0, 4200.0);

    return LineChart(
      LineChartData(
        minX: firstMs,
        maxX: lastMs,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.panelBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.round().toString(),
                style: _axisStyle(context, colors),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: ((lastMs - firstMs) / 3).clamp(1.0, double.infinity),
              getTitlesWidget: (value, meta) {
                final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                final span = lastMs - firstMs;
                final format = span > const Duration(days: 2).inMilliseconds
                    ? DateFormat('d MMM')
                    : DateFormat('HH:mm');
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    format.format(time),
                    style: _axisStyle(context, colors),
                  ),
                );
              },
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: threshold.toDouble(),
              color: colors.soilDry,
              strokeWidth: 1.5,
              dashArray: [6, 4],
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((spot) {
              final time = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
              return LineTooltipItem(
                '${spot.y.round()}\n${DateFormat('d MMM HH:mm').format(time)}',
                Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: colors.soilWet,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 2,
            color: colors.soilWet,
            dotData: FlDotData(
              show: readings.length <= 30,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 2.5,
                color: colors.soilWet,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.soilWet.withValues(alpha: 0.25),
                  colors.soilWet.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String range;

  const _EmptyChart({required this.range});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FarmIllustration(art: FarmArt.soilSensor, size: 84),
          const SizedBox(height: Tokens.space3),
          Text(
            'Not enough data for the last $range',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: Tokens.space1),
          Text(
            'Readings are logged every 10 minutes while the app is open.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
          ),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RangeToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    // Same construction as the hero card's mode switch: a recessed track with
    // one raised segment. Two segmented controls built differently is the
    // kind of drift that makes an app feel assembled rather than designed.
    return Container(
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.panelMuted,
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final isSelected = option == selected;
          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              Haptics.selection();
              onChanged(option);
            },
            child: AnimatedContainer(
              duration: Tokens.motionFast,
              curve: Tokens.curveStandard,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors.panel : Colors.transparent,
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
                boxShadow: isSelected
                    ? Tokens.restingShadow(colors.panelShadow)
                    : null,
              ),
              child: Text(
                option,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 11,
                  color: isSelected ? colors.soilWet : colors.inkTertiary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontVariations: [
                    FontVariation('wght', isSelected ? 700 : 600),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 2.5,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 1.25) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            color: context.farmColors.inkTertiary,
          ),
        ),
      ],
    );
  }
}

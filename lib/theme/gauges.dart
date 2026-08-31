import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';

/// Converts a raw capacitive-probe reading into something a person can read.
///
/// The probe reads *higher when drier* on a 12-bit ADC, which is the single
/// most confusing fact about this system. Every gauge in the app routes
/// through here so the inversion is applied in exactly one place — a screen
/// that does the arithmetic inline is one refactor away from drawing a full
/// gauge for bone-dry soil.
class SoilScale {
  const SoilScale._();

  /// Full ADC span. Not the *plausible* span that `FarmData` guards against,
  /// but the physical one the arc is drawn against.
  static const double adcMax = 4095;

  /// Wetness as 0–1, where 1 is saturated. Inverts the probe's sense.
  static double wetness(int raw) => (1 - (raw / adcMax)).clamp(0.0, 1.0);

  /// The same value as a whole percentage, for display.
  static int percent(int raw) => (wetness(raw) * 100).round();
}

/// The dashboard's hero: soil moisture as an animated 270° arc.
///
/// Three things are drawn, in increasing order of how often a farmer needs
/// them:
///
/// * the **arc**, filled to current wetness and tinted by state,
/// * a **tick** at the irrigation threshold, so "how close am I to watering"
///   is a glance rather than a subtraction,
/// * the **reading** in the middle, with the raw sensor value beneath it for
///   anyone cross-checking against the controller.
///
/// The arc animates from its previous value on every update, at
/// [Tokens.curveGauge] — decelerating, never overshooting. A live measurement
/// that springs past its value and settles back reads as the sensor itself
/// being unstable.
class MoistureGauge extends StatelessWidget {
  /// Raw probe reading, higher when drier.
  final int raw;

  /// Raw threshold the controller waters at.
  final int threshold;

  /// False when the probe is disconnected or out of range. The arc empties
  /// and the readout says so rather than reporting 100% wet, which is what a
  /// shorted probe would otherwise look like.
  final bool isPlausible;

  /// Softly pulses the arc's glow while the pump is actually running.
  final bool irrigating;

  final double size;

  const MoistureGauge({
    super.key,
    required this.raw,
    required this.threshold,
    this.isPlausible = true,
    this.irrigating = false,
    this.size = 210,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    final isDry = raw > threshold;
    final accent = !isPlausible
        ? colors.inkTertiary
        : isDry
        ? colors.soilDry
        : colors.soilWet;

    final target = isPlausible ? SoilScale.wetness(raw) : 0.0;
    final tick = SoilScale.wetness(threshold);

    return Semantics(
      // The label carries the state in words, because the arc's meaning is
      // carried by colour and length — neither of which reaches a screen
      // reader.
      label: isPlausible
          ? 'Soil moisture ${SoilScale.percent(raw)} percent, '
                '${isDry ? "dry, below" : "moist, above"} the irrigation '
                'threshold'
          : 'Soil moisture unavailable, sensor reading out of range',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: Tokens.motionGauge,
          curve: Tokens.curveGauge,
          builder: (context, value, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _Pulse(
                  active: irrigating && isPlausible,
                  color: accent,
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _GaugePainter(
                      value: value,
                      tick: tick,
                      accent: accent,
                      track: colors.panelMuted,
                      tickColor: colors.inkTertiary,
                      strokeWidth: size * 0.075,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPlausible ? '${(value * 100).round()}' : '—',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: size * 0.26,
                        color: colors.inkPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPlausible
                          ? isDry
                                ? '% · needs water'
                                : '% · moist'
                          : 'sensor offline',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    if (isPlausible) ...[
                      const SizedBox(height: Tokens.space2),
                      Text(
                        'raw $raw · waters at $threshold',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10.5,
                          color: colors.inkTertiary,
                          fontFeatures: Tokens.tabular,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A slow breath of glow behind the gauge while water is actually moving.
///
/// Only ever driven by `pumpStatus` — the state the controller measured — so
/// it can never imply the pump is running because a command was sent.
class _Pulse extends StatefulWidget {
  final bool active;
  final Color color;
  final Widget child;

  const _Pulse({
    required this.active,
    required this.color,
    required this.child,
  });

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.10 + 0.14 * _controller.value,
                ),
                blurRadius: 30 + 20 * _controller.value,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final double tick;
  final Color accent;
  final Color track;
  final Color tickColor;
  final double strokeWidth;

  /// A 270° dial, opening at the bottom. The gap is where the caption sits,
  /// and an unbroken ring would make the readout feel boxed in.
  static const double _start = math.pi * 0.75;
  static const double _sweep = math.pi * 1.5;

  const _GaugePainter({
    required this.value,
    required this.tick,
    required this.accent,
    required this.track,
    required this.tickColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      arcRect,
      _start,
      _sweep,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (value > 0) {
      // Swept gradient so the arc gains density as it fills, rather than
      // reading as a flat band of colour laid on the track.
      canvas.drawArc(
        arcRect,
        _start,
        _sweep * value,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: _start,
            endAngle: _start + _sweep,
            colors: [accent.withValues(alpha: 0.55), accent],
            transform: GradientRotation(_start),
          ).createShader(arcRect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // The threshold mark. Drawn over the arc so it stays visible whichever
    // side of it the reading has landed on.
    final angle = _start + _sweep * tick.clamp(0.0, 1.0);
    final inner = radius - strokeWidth * 0.75;
    final outer = radius + strokeWidth * 0.75;
    canvas.drawLine(
      center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
      center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
      Paint()
        ..color = tickColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.tick != tick ||
      old.accent != accent ||
      old.track != track;
}

/// A crop suitability score as an animated ring with the number inside.
///
/// Used on every crop card. The ring exists because a bare "72" invites the
/// question "out of what" — a ring three-quarters filled answers it before
/// the number is read.
class ScoreRing extends StatelessWidget {
  /// 0–100.
  final int score;
  final Color accent;
  final double size;

  /// Small caption under the number. Omitted on compact rings.
  final String? label;

  const ScoreRing({
    super.key,
    required this.score,
    required this.accent,
    this.size = 56,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final compact = size < 60;

    return Semantics(
      label: '$score out of 100',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (score / 100).clamp(0.0, 1.0)),
          duration: Tokens.motionGauge,
          curve: Tokens.curveGauge,
          builder: (context, value, _) => Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _RingPainter(
                  value: value,
                  accent: accent,
                  track: colors.panelMuted,
                  strokeWidth: size * 0.1,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: size * (compact ? 0.32 : 0.3),
                      color: accent,
                      height: 1,
                    ),
                  ),
                  if (label != null && !compact)
                    Text(
                      label!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 8.5,
                        color: colors.inkTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color accent;
  final Color track;
  final double strokeWidth;

  const _RingPainter({
    required this.value,
    required this.accent,
    required this.track,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (value <= 0) return;

    // Starts at twelve o'clock, which is the only start angle people read as
    // "zero" without being told.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.accent != accent || old.track != track;
}

/// A horizontal capacity bar with an optional threshold mark.
///
/// The flat cousin of [MoistureGauge], for rows where a ring would be too
/// heavy — planting progress, water budget, a crop's score inside a dense
/// list.
class MeterBar extends StatelessWidget {
  /// 0–1.
  final double value;
  final Color accent;
  final double height;

  /// Optional 0–1 mark drawn across the track.
  final double? mark;

  const MeterBar({
    super.key,
    required this.value,
    required this.accent,
    this.height = 8,
    this.mark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.panelMuted,
                  borderRadius: BorderRadius.circular(height),
                ),
                child: const SizedBox(width: double.infinity),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                duration: Tokens.motionGauge,
                curve: Tokens.curveGauge,
                builder: (context, v, _) => Container(
                  width: width * v,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent.withValues(alpha: 0.72), accent],
                    ),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
              if (mark != null)
                Positioned(
                  left: (width * mark!.clamp(0.0, 1.0)) - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: colors.inkTertiary),
                ),
            ],
          ),
        );
      },
    );
  }
}

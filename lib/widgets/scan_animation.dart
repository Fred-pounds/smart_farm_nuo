import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The photo being classified, under a moving scan line and a reticle.
///
/// Showing the farmer's own image rather than a generic animation is the
/// point: it confirms the app is working on the leaf they framed, and a
/// badly-cropped or blurred photo becomes obvious while there is still time
/// to retake it.
///
/// The sweep is a plain [AnimationController] on a gradient — no shader, no
/// second texture — so it stays cheap while the CPU is busy running
/// inference.
class ScanFrame extends StatefulWidget {
  final File photo;
  final double size;

  const ScanFrame({super.key, required this.photo, this.size = 240});

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final radius = BorderRadius.circular(Tokens.radiusXl);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.photo, fit: BoxFit.cover),
                  // Darkened slightly so the scan line and brackets stay
                  // visible over a bright daylight photograph.
                  ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
                  if (!MediaQuery.of(context).disableAnimations)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        painter: _ScanLinePainter(
                          progress: _controller.value,
                          color: colors.waterBright,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // The reticle sits outside the clip so its corners read as an
          // instrument framing the photo, not as marks printed on it.
          Positioned.fill(
            child: CustomPaint(
              painter: _ReticlePainter(color: colors.waterBright),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  /// 0–1, ping-ponged by the controller.
  final double progress;
  final Color color;

  const _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    // A short gradient trailing the line, so the sweep has a direction.
    canvas.drawRect(
      Rect.fromLTWH(0, y - 44, size.width, 44),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.32)],
        ).createShader(Rect.fromLTWH(0, y - 44, size.width, 44)),
    );

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

class _ReticlePainter extends CustomPainter {
  final Color color;

  const _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const arm = 26.0;
    const inset = 2.0;
    final w = size.width - inset;
    final h = size.height - inset;

    for (final (x, y, sx, sy) in [
      (inset, inset, 1.0, 1.0),
      (w, inset, -1.0, 1.0),
      (inset, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + arm * sx, y), paint);
      canvas.drawLine(Offset(x, y), Offset(x, y + arm * sy), paint);
    }
  }

  @override
  bool shouldRepaint(_ReticlePainter old) => old.color != color;
}

/// The three stages of a diagnosis, lighting up in turn.
///
/// These are **timed, not measured**. `DiseaseService` runs decode, resize and
/// inference as one call and reports no intermediate progress, so hooking
/// these to real events would mean restructuring the service for the sake of
/// an animation. They are labelled as what the app is doing rather than as a
/// percentage for that reason — a fake progress bar that reaches 90% and
/// stops is worse than no bar, but naming the work is honest and tells the
/// farmer roughly how long is left.
class ScanStages extends StatefulWidget {
  const ScanStages({super.key});

  @override
  State<ScanStages> createState() => _ScanStagesState();
}

class _ScanStagesState extends State<ScanStages>
    with SingleTickerProviderStateMixin {
  static const _stages = ['Reading image', 'Matching patterns', 'Scoring'];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = (_controller.value * _stages.length).floor().clamp(
          0,
          _stages.length - 1,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _stages.length; i++) ...[
              if (i > 0) const SizedBox(width: Tokens.space3),
              AnimatedContainer(
                duration: Tokens.motionBase,
                curve: Tokens.curveStandard,
                padding: const EdgeInsets.symmetric(
                  horizontal: Tokens.space3,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: i <= active
                      ? colors.water.withValues(alpha: 0.14)
                      : colors.panelMuted,
                  borderRadius: BorderRadius.circular(Tokens.radiusPill),
                ),
                child: Text(
                  _stages[i],
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    color: i <= active ? colors.water : colors.inkTertiary,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

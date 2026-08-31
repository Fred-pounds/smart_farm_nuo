import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The illustration set.
///
/// ## Why these are painted rather than imported
///
/// Storyset / unDraw / Lottie assets were the obvious route and were
/// deliberately not taken. Three reasons, in order of weight:
///
/// * **They cannot follow the theme.** A flat SVG or Lottie ships its own
///   palette. Dropped into dark mode it either glows white or disappears, and
///   the usual fix — two copies of every asset — doubles the set and still
///   misses the accent colours, which here carry meaning.
/// * **They cannot be tinted by state.** The diagnose hero is green while
///   idle and amber while scanning; the empty-tasks art picks up whichever
///   accent the screen is already using. A raster or a baked vector can do
///   neither.
/// * **Weight and licence.** This is an offline-first field app. Seven
///   painters are a few kilobytes of Dart with no attribution obligations and
///   no `lottie` runtime, against roughly a megabyte of JSON and images.
///
/// Each piece is drawn in a normalised unit square and scaled to fit, so one
/// illustration reads correctly at 72px in an empty state and at 220px as a
/// screen hero.
enum FarmArt {
  /// A probe in the ground, reporting. For sensor and connection states.
  soilSensor,

  /// Water arriving on a planted bed. For irrigation and water usage.
  irrigation,

  /// Sun behind cloud with rain. For weather and forecast states.
  weather,

  /// A leaf inside a scanning frame. For the diagnose flow.
  aiScan,

  /// A seedling on a soil line. For crops and planting.
  cropGrowth,

  /// A calendar page. For the tasks screen.
  calendar,

  /// Rolling fields under a sun. The general-purpose farm scene.
  farmScene,

  /// A struck-through cloud. For offline and no-data states.
  offline,
}

/// Draws one piece from the set, tinted from the active theme.
///
/// [accent] overrides the illustration's own primary hue — used where the
/// surrounding screen already carries a state colour and the art should agree
/// with it rather than compete.
class FarmIllustration extends StatelessWidget {
  final FarmArt art;
  final double size;
  final Color? accent;

  /// The soft blob behind the subject. Turned off inside dense cards, where
  /// it reads as a smudge rather than as grounding.
  final bool showBackdrop;

  const FarmIllustration({
    super.key,
    required this.art,
    this.size = 140,
    this.accent,
    this.showBackdrop = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArtPainter(
          art: art,
          growth: accent ?? colors.growthBright,
          water: colors.waterBright,
          sun: colors.sunBright,
          neutral: colors.inkTertiary,
          soft: colors.panelMuted,
          showBackdrop: showBackdrop,
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final FarmArt art;
  final Color growth;
  final Color water;
  final Color sun;
  final Color neutral;
  final Color soft;
  final bool showBackdrop;

  const _ArtPainter({
    required this.art,
    required this.growth,
    required this.water,
    required this.sun,
    required this.neutral,
    required this.soft,
    required this.showBackdrop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is authored in a 100×100 square and scaled once here,
    // so the coordinates in each piece stay readable.
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);

    if (showBackdrop) {
      canvas.drawCircle(
        const Offset(50, 52),
        44,
        Paint()..color = growth.withValues(alpha: 0.09),
      );
    }

    switch (art) {
      case FarmArt.soilSensor:
        _soilSensor(canvas);
      case FarmArt.irrigation:
        _irrigation(canvas);
      case FarmArt.weather:
        _weather(canvas);
      case FarmArt.aiScan:
        _aiScan(canvas);
      case FarmArt.cropGrowth:
        _cropGrowth(canvas);
      case FarmArt.calendar:
        _calendar(canvas);
      case FarmArt.farmScene:
        _farmScene(canvas);
      case FarmArt.offline:
        _offline(canvas);
    }

    canvas.restore();
  }

  // ===========================================================================
  // SHARED SHAPES
  // ===========================================================================

  Paint _fill(Color c, [double alpha = 1]) =>
      Paint()..color = c.withValues(alpha: alpha);

  Paint _stroke(Color c, double width, [double alpha = 1]) => Paint()
    ..color = c.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// A soil band with a gently curved top edge, sitting at [y].
  void _ground(Canvas canvas, double y, Color color) {
    final path = Path()
      ..moveTo(8, y + 4)
      ..quadraticBezierTo(50, y - 6, 92, y + 4)
      ..lineTo(92, y + 14)
      ..quadraticBezierTo(50, y + 6, 8, y + 14)
      ..close();
    canvas.drawPath(path, _fill(color, 0.35));
  }

  /// A leaf pointing straight up from the origin, then rotated into place.
  void _leaf(
    Canvas canvas,
    Offset base,
    double length,
    double width,
    double radians,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(radians);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(width, -length * 0.4, 0, -length)
      ..quadraticBezierTo(-width, -length * 0.4, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// A teardrop centred on [c], with body radius [r].
  Path _droplet(Offset c, double r) {
    return Path()
      ..moveTo(c.dx, c.dy - r * 1.75)
      ..cubicTo(
        c.dx + r * 0.95,
        c.dy - r * 0.5,
        c.dx + r,
        c.dy - r * 0.1,
        c.dx + r,
        c.dy + r * 0.1,
      )
      ..arcToPoint(
        Offset(c.dx - r, c.dy + r * 0.1),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..cubicTo(
        c.dx - r,
        c.dy - r * 0.1,
        c.dx - r * 0.95,
        c.dy - r * 0.5,
        c.dx,
        c.dy - r * 1.75,
      )
      ..close();
  }

  /// Three overlapping lobes on a flat base. Filled as one path so the
  /// overlaps disappear.
  Path _cloud(Offset c, double w) {
    final h = w * 0.52;
    return Path()
      ..addOval(
        Rect.fromCircle(center: Offset(c.dx - w * 0.24, c.dy), radius: h * 0.5),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx + w * 0.04, c.dy - h * 0.22),
          radius: h * 0.66,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx + w * 0.3, c.dy + h * 0.04),
          radius: h * 0.46,
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - w * 0.42, c.dy, w * 0.84, h * 0.5),
          Radius.circular(h * 0.25),
        ),
      );
  }

  /// A sun disc with short rays.
  void _sun(Canvas canvas, Offset c, double r, {bool rays = true}) {
    canvas.drawCircle(c, r, _fill(sun));
    if (!rays) return;
    final paint = _stroke(sun, 2.6, 0.75);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 4), c + d * (r + 9), paint);
    }
  }

  // ===========================================================================
  // PIECES
  // ===========================================================================

  void _soilSensor(Canvas canvas) {
    _ground(canvas, 66, growth);

    // The probe: a stake in the soil with a housing on top.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(46.5, 52, 7, 32),
        const Radius.circular(3.5),
      ),
      _fill(neutral, 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 36, 24, 18),
        const Radius.circular(6),
      ),
      _fill(growth),
    );
    canvas.drawCircle(const Offset(50, 45), 3.4, _fill(Colors.white, 0.92));

    // Signal arcs, widening upward — the sensor reporting home.
    for (var i = 0; i < 3; i++) {
      final r = 12.0 + i * 7;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(50, 34), radius: r),
        math.pi * 1.18,
        math.pi * 0.64,
        false,
        _stroke(water, 2.4, 0.75 - i * 0.2),
      );
    }
  }

  void _irrigation(Canvas canvas) {
    _ground(canvas, 70, growth);

    // A short row of seedlings taking the water.
    for (final x in const [30.0, 50.0, 70.0]) {
      canvas.drawLine(
        Offset(x, 72),
        Offset(x, 60),
        _stroke(growth, 2.6, 0.9),
      );
      _leaf(canvas, Offset(x, 64), 11, 5.5, -0.7, _fill(growth, 0.85));
      _leaf(canvas, Offset(x, 64), 11, 5.5, 0.7, _fill(growth, 0.6));
    }

    // Falling water, staggered so it reads as motion rather than a row.
    canvas.drawPath(_droplet(const Offset(34, 34), 6), _fill(water));
    canvas.drawPath(_droplet(const Offset(52, 24), 7.5), _fill(water, 0.9));
    canvas.drawPath(_droplet(const Offset(68, 38), 5), _fill(water, 0.75));
  }

  void _weather(Canvas canvas) {
    _sun(canvas, const Offset(64, 34), 13);
    canvas.drawPath(_cloud(const Offset(45, 46), 52), _fill(soft));
    canvas.drawPath(
      _cloud(const Offset(45, 46), 52),
      _stroke(neutral, 1.6, 0.28),
    );

    // Rain, sloped so the group has a direction.
    final rain = _stroke(water, 3, 0.85);
    for (var i = 0; i < 4; i++) {
      final x = 28.0 + i * 12;
      final drop = 4.0 * (i.isEven ? 1 : 0);
      canvas.drawLine(
        Offset(x, 62 + drop),
        Offset(x - 3, 72 + drop),
        rain,
      );
    }
  }

  void _aiScan(Canvas canvas) {
    // The subject: one leaf, centred and upright.
    _leaf(canvas, const Offset(50, 74), 42, 20, 0, _fill(growth, 0.9));
    canvas.drawLine(
      const Offset(50, 74),
      const Offset(50, 38),
      _stroke(Colors.white, 2, 0.5),
    );
    for (var i = 0; i < 3; i++) {
      final y = 46.0 + i * 9;
      canvas.drawLine(
        Offset(50, y),
        Offset(50 + 9 - i * 1.5, y - 6),
        _stroke(Colors.white, 1.4, 0.4),
      );
      canvas.drawLine(
        Offset(50, y),
        Offset(50 - 9 + i * 1.5, y - 6),
        _stroke(Colors.white, 1.4, 0.4),
      );
    }

    // Reticle corners, not a full frame — the gap is what makes it read as
    // an instrument rather than a picture border.
    final bracket = _stroke(water, 3);
    const l = 20.0, r = 80.0, t = 22.0, b = 82.0, arm = 11.0;
    for (final (cx, cy, sx, sy) in [
      (l, t, 1.0, 1.0),
      (r, t, -1.0, 1.0),
      (l, b, 1.0, -1.0),
      (r, b, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(cx, cy), Offset(cx + arm * sx, cy), bracket);
      canvas.drawLine(Offset(cx, cy), Offset(cx, cy + arm * sy), bracket);
    }

    // The scan line.
    canvas.drawLine(
      const Offset(24, 52),
      const Offset(76, 52),
      _stroke(water, 2.4, 0.9),
    );
  }

  void _cropGrowth(Canvas canvas) {
    _ground(canvas, 74, growth);
    _sun(canvas, const Offset(74, 26), 10, rays: false);

    // Three plants at three ages, left to right — the growth itself is the
    // subject, so it is shown as a sequence rather than a single stem.
    final stages = [
      (28.0, 12.0, 0.55),
      (50.0, 24.0, 0.78),
      (72.0, 36.0, 1.0),
    ];
    for (final (x, height, alpha) in stages) {
      canvas.drawLine(
        Offset(x, 76),
        Offset(x, 76 - height),
        _stroke(growth, 2.8, alpha),
      );
      _leaf(
        canvas,
        Offset(x, 76 - height * 0.55),
        height * 0.62,
        height * 0.3,
        -0.85,
        _fill(growth, alpha * 0.9),
      );
      _leaf(
        canvas,
        Offset(x, 76 - height * 0.8),
        height * 0.55,
        height * 0.27,
        0.85,
        _fill(growth, alpha * 0.65),
      );
    }
  }

  void _calendar(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 26, 60, 56),
        const Radius.circular(9),
      ),
      _fill(soft),
    );
    // Header band.
    canvas.drawPath(
      Path()
        ..addRRect(
          RRect.fromRectAndCorners(
            const Rect.fromLTWH(20, 26, 60, 15),
            topLeft: const Radius.circular(9),
            topRight: const Radius.circular(9),
          ),
        ),
      _fill(growth),
    );
    // Binder rings.
    for (final x in const [34.0, 66.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, 20, 4, 12),
          const Radius.circular(2),
        ),
        _fill(neutral, 0.7),
      );
    }
    // Day grid, with today marked.
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        final c = Offset(29.5 + col * 13.5, 50.0 + row * 12);
        final isToday = row == 1 && col == 2;
        canvas.drawCircle(
          c,
          isToday ? 4.6 : 2.6,
          _fill(isToday ? water : neutral, isToday ? 1 : 0.4),
        );
      }
    }
  }

  void _farmScene(Canvas canvas) {
    _sun(canvas, const Offset(72, 28), 11);

    // Two hills, the far one lighter, so the field has depth without a
    // horizon line.
    canvas.drawPath(
      Path()
        ..moveTo(0, 72)
        ..quadraticBezierTo(28, 46, 58, 68)
        ..quadraticBezierTo(80, 82, 100, 66)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..close(),
      _fill(growth, 0.22),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 84)
        ..quadraticBezierTo(34, 66, 66, 82)
        ..quadraticBezierTo(84, 91, 100, 84)
        ..lineTo(100, 100)
        ..lineTo(0, 100)
        ..close(),
      _fill(growth, 0.5),
    );

    // Crop rows on the near hill.
    for (var i = 0; i < 5; i++) {
      final x = 18.0 + i * 16;
      final y = 84.0 - math.sin(i * 0.7) * 4;
      canvas.drawLine(Offset(x, y), Offset(x, y - 9), _stroke(growth, 2.2));
      _leaf(canvas, Offset(x, y - 5), 7, 3.5, -0.8, _fill(growth, 0.85));
    }
  }

  void _offline(Canvas canvas) {
    canvas.drawPath(_cloud(const Offset(50, 46), 54), _fill(soft));
    canvas.drawPath(
      _cloud(const Offset(50, 46), 54),
      _stroke(neutral, 1.8, 0.35),
    );
    // The strike-through, drawn twice so it stays visible over both the
    // cloud and the backdrop.
    canvas.drawLine(
      const Offset(26, 74),
      const Offset(74, 26),
      _stroke(soft, 6),
    );
    canvas.drawLine(
      const Offset(26, 74),
      const Offset(74, 26),
      _stroke(neutral, 3, 0.8),
    );
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.art != art ||
      old.growth != growth ||
      old.water != water ||
      old.sun != sun ||
      old.soft != soft ||
      old.showBackdrop != showBackdrop;
}

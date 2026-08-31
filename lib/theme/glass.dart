import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';

/// The painted canvas behind every screen.
///
/// A vertical gradient plus three soft colour fields. The fields exist so the
/// glass chrome has something to refract — blur over a flat colour produces
/// flat colour, and the effect collapses into grey.
///
/// Deliberately **not** a photograph or image. Glass is only guaranteed
/// legible when what sits behind it is known and bounded; an arbitrary image
/// puts unpredictable contrast under the navigation labels.
///
/// Cheap to render: gradients only, no [BackdropFilter].
class AmbientBackground extends StatelessWidget {
  final Widget child;

  const AmbientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.farmColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.canvasTop, c.canvasMid, c.canvasBottom],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          // Kept faint and pushed to the corners. Turned up, these read as
          // smudges on the page rather than as depth behind it — the effect
          // only has to give the glass something to pick up, and the panels
          // sitting on top cover most of it anyway.
          _Aura(
            alignment: const Alignment(-1.4, -1.0),
            diameter: 380,
            color: c.auraGrowth,
            opacity: 0.16,
          ),
          _Aura(
            alignment: const Alignment(1.5, -0.75),
            diameter: 320,
            color: c.auraWater,
            opacity: 0.13,
          ),
          child,
        ],
      ),
    );
  }
}

class _Aura extends StatelessWidget {
  final Alignment alignment;
  final double diameter;
  final Color color;
  final double opacity;

  const _Aura({
    required this.alignment,
    required this.diameter,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
              stops: const [0, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent, blurred surface — **for app chrome only**.
///
/// Use for navigation bars, floating headers, sheets and overlays: surfaces
/// that sit above scrolling content and carry no readings of their own.
///
/// Do not use for data. Two reasons, both load-bearing:
///
/// * **Legibility.** This app is read outdoors in daylight. A number over a
///   blurred, shifting backdrop is the first thing that becomes unreadable,
///   and an unreadable reading is worse than no reading — the farmer acts on
///   a guess. Readings belong on [Panel].
///
/// * **Cost.** [BackdropFilter] forces the layer beneath it to be rendered to
///   a texture and blurred, every frame it is visible. Two or three on screen
///   is comfortable; one per row in a scrolling list will drop frames on the
///   mid-range Android hardware this app targets.
///
/// Falls back to an opaque surface when the platform asks for high contrast,
/// or when [forceSolid] is set.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius borderRadius;

  /// Uses the heavier fill. For chrome that content scrolls directly beneath,
  /// where the extra density keeps labels readable.
  final bool strong;

  /// Skip the blur and paint an opaque surface instead.
  final bool forceSolid;

  const GlassSurface({
    super.key,
    required this.child,
    this.blur = Tokens.blurChrome,
    BorderRadius? borderRadius,
    this.strong = false,
    this.forceSolid = false,
  }) : borderRadius = borderRadius ?? const BorderRadius.all(Radius.zero);

  @override
  Widget build(BuildContext context) {
    final c = context.farmColors;
    final solid = forceSolid || MediaQuery.of(context).highContrast;

    if (solid) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.chromeSolid,
          borderRadius: borderRadius,
          border: Border.all(color: c.panelBorder),
        ),
        child: child,
      );
    }

    // RepaintBoundary keeps the blur from being re-rasterised because
    // something unrelated elsewhere in the tree repainted.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: strong ? c.glassFillStrong : c.glassFill,
              borderRadius: borderRadius,
              border: Border.all(color: c.glassBorder, width: 1),
              // The bright upper edge is what reads as "glass" rather than
              // "translucent grey". Without it the surface looks like a
              // lowered opacity, not a material.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.glassHighlight.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0, 0.45],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A solid data surface. **This is where readings live.**
///
/// Opaque fill, hairline border, and a shadow only deep enough to lift it off
/// the canvas. Every number, status and label a farmer acts on is painted
/// here at full contrast.
///
/// Drop-in replacement for [Card]: takes the same `child` and applies the
/// standard panel padding unless [padding] says otherwise.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// Draws the border in an accent colour. For panels that are themselves the
  /// alert — a fault, a critical reading — not for ordinary emphasis.
  final Color? accentBorder;

  /// A soft wash of [accentBorder]'s colour behind the content. For the one
  /// panel on a screen that is genuinely the subject.
  final bool tinted;

  /// Lifts the panel onto the deeper shadow. Reserve it for the hero card —
  /// if two things on a screen are raised, neither is.
  final bool raised;

  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.accentBorder,
    this.tinted = false,
    this.raised = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.farmColors;
    final radius = borderRadius ?? BorderRadius.circular(Tokens.radiusLg);

    final content = Padding(
      padding: padding ?? Tokens.panelPadding,
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tinted && accentBorder != null
            ? Color.alphaBlend(accentBorder!.withValues(alpha: 0.05), c.panel)
            : c.panel,
        borderRadius: radius,
        border: Border.all(
          color: accentBorder ?? c.panelBorder,
          width: accentBorder != null ? 1.4 : 1,
        ),
        boxShadow: raised
            ? Tokens.raisedShadow(c.panelShadow)
            : Tokens.restingShadow(c.panelShadow),
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );
  }
}

/// A recessed well inside a [Panel] — chart backgrounds, inputs, read-only
/// value slots. One step down in the hierarchy, never a step up.
class PanelWell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PanelWell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Tokens.space3),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.farmColors;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.panelMuted,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
      ),
      child: child,
    );
  }
}

/// The small uppercase label that names a value.
///
/// Exists as a component because an eyebrow set by hand drifts — one screen
/// uses 11px semibold, the next 12px bold, and the grid stops feeling
/// machined.
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? context.farmColors.inkTertiary,
      ),
    );
  }
}

/// A small status pill: a dot and a word.
///
/// The dot carries the colour, the word carries the meaning. Colour alone is
/// never the only signal — around 1 in 12 men has some colour vision
/// deficiency, and this app distinguishes dry from wet soil for a living.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool glowing;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.glowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Tokens.motionBase,
            curve: Tokens.curveData,
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: glowing
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: Tokens.space2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

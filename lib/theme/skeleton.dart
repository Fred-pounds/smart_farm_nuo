import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';
import 'glass.dart';

/// A shimmering placeholder group.
///
/// Wrap a subtree of [SkeletonBox] / [SkeletonLine] shapes in one [Shimmer].
/// The sweep is applied once, to the whole group, by a single [ShaderMask]
/// driven by a single ticker — so a list of twelve placeholder rows costs one
/// animation, not twelve. Per-row shimmers also sweep out of phase with each
/// other, which reads as noise rather than as one surface loading.
///
/// Why skeletons at all, rather than a spinner: a spinner says "something is
/// happening", a skeleton says "a reading is about to appear *here*". On a
/// dashboard the second is the useful message, and it stops the layout
/// jumping when data lands.
///
/// Honours the platform's reduce-motion setting by falling back to a static
/// fill. A sweeping gradient is exactly the kind of repeating motion that
/// setting exists to suppress.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Tokens.motionShimmer,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    if (MediaQuery.of(context).disableAnimations) return widget.child;

    final highlight = colors.inkPrimary.withValues(alpha: 0.06);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // The sweep travels from fully off one edge to fully off the
            // other, so the band never appears to pop into existence.
            final dx = bounds.width * (_controller.value * 3 - 1.5);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                highlight,
                highlight,
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(dx, 0, bounds.width, bounds.height),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One rectangular placeholder shape.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = Tokens.radiusSm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.farmColors.panelMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A placeholder line of text.
///
/// [widthFactor] keeps a stack of lines from reading as a solid block — real
/// paragraphs have a ragged right edge, and placeholders that do too settle
/// into the layout more convincingly.
class SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor.clamp(0.0, 1.0),
      child: SkeletonBox(height: height, radius: height / 2),
    );
  }
}

/// A circular placeholder — an avatar, a crop thumbnail, a score ring.
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.farmColors.panelMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// The placeholder for the dashboard hero, matched to the real card's height
/// so nothing reflows when the reading arrives.
class HeroCardSkeleton extends StatelessWidget {
  const HeroCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Panel(
        padding: const EdgeInsets.all(Tokens.space6),
        child: Column(
          children: [
            const SkeletonLine(widthFactor: 0.45, height: 11),
            const SizedBox(height: Tokens.space6),
            const SkeletonCircle(size: 210),
            const SizedBox(height: Tokens.space6),
            Row(
              children: const [
                Expanded(child: SkeletonLine(widthFactor: 0.7)),
                SizedBox(width: Tokens.space4),
                Expanded(child: SkeletonLine(widthFactor: 0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A generic list placeholder: [count] rows of thumbnail plus two lines.
class ListSkeleton extends StatelessWidget {
  final int count;
  final double thumbSize;

  const ListSkeleton({super.key, this.count = 4, this.thumbSize = 52});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(height: Tokens.space3),
            Panel(
              child: Row(
                children: [
                  SkeletonBox(
                    width: thumbSize,
                    height: thumbSize,
                    radius: Tokens.radiusMd,
                  ),
                  const SizedBox(width: Tokens.space4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLine(widthFactor: 0.5, height: 13),
                        SizedBox(height: Tokens.space2),
                        SkeletonLine(widthFactor: 0.85, height: 10),
                        SizedBox(height: 6),
                        SkeletonLine(widthFactor: 0.35, height: 10),
                      ],
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

/// A placeholder for a chart panel.
class ChartSkeleton extends StatelessWidget {
  final double height;

  const ChartSkeleton({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLine(widthFactor: 0.35, height: 11),
            const SizedBox(height: Tokens.space4),
            SkeletonBox(height: height, radius: Tokens.radiusMd),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';

/// Haptics, named for what they mean rather than how strong they are.
///
/// Call sites say `Haptics.commandSent()`, not `HapticFeedback.mediumImpact()`.
/// The mapping then lives in one place, which matters because the intensities
/// are not interchangeable: this app can start a pump, and the tap that does
/// that should not feel the same as the tap that switches a tab.
///
/// Nothing here is load-bearing. Haptics are off on many devices and absent
/// on the web, so they only ever confirm feedback the screen already gives.
class Haptics {
  const Haptics._();

  /// Moving between tabs, chips, list selections.
  static void selection() => HapticFeedback.selectionClick();

  /// A command left the app for the controller — pump start/stop, mode
  /// change, threshold write. The heaviest tap in the app, because these are
  /// the taps that move water.
  static void commandSent() => HapticFeedback.mediumImpact();

  /// A destructive or irreversible confirmation.
  static void warn() => HapticFeedback.heavyImpact();

  /// A capture, a completed scan, a saved record.
  static void success() => HapticFeedback.lightImpact();

  /// A control that was pressed but cannot act — pump in automatic mode,
  /// controller offline.
  static void refused() => HapticFeedback.vibrate();
}

/// Fades and lifts a child into place on first build.
///
/// Used to stagger a screen's sections so content arrives in reading order
/// instead of appearing as one block. The movement is small — 12 logical
/// pixels — because this is entrance polish, not a transition; anything
/// larger and the page reads as still settling when the farmer starts
/// scanning it.
///
/// Skipped entirely when the platform asks to reduce motion.
class FadeSlideIn extends StatefulWidget {
  final Widget child;

  /// Position in the stagger. Each step adds 60ms.
  final int index;

  /// Distance travelled, in logical pixels.
  final double offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 12,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Tokens.motionSlow,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Tokens.curveStandard,
  );

  @override
  void initState() {
    super.initState();
    // Capped so a long list never ends up waiting a second and a half for its
    // last row.
    final delay = Duration(milliseconds: (widget.index * 60).clamp(0, 420));
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// A number that animates to its new value instead of snapping.
///
/// Only for values that change meaningfully and infrequently — a litre total,
/// a task count, a score. Deliberately **not** used for the live soil reading:
/// a sensor value that visibly counts is a value the farmer has to wait to
/// read, and the gauge already carries the movement.
class AnimatedCount extends StatelessWidget {
  final num value;
  final TextStyle? style;

  /// Decimal places. 0 renders an integer.
  final int decimals;

  final String suffix;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Tokens.motionGauge,
      curve: Tokens.curveGauge,
      builder: (context, v, _) => Text(
        '${v.toStringAsFixed(decimals)}$suffix',
        style: style,
      ),
    );
  }
}

/// Scales a child down slightly while it is held.
///
/// Applied to cards that navigate. Material's ink ripple reads well on a flat
/// list row, but on a large rounded panel it mostly happens out of sight under
/// the finger; a press that shrinks the whole card is legible on any surface
/// size.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Fires [Haptics.selection] on tap. Off where the caller wants a heavier
  /// tap of its own.
  final bool haptic;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) Haptics.selection();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: Tokens.motionFast,
        curve: Tokens.curveStandard,
        child: widget.child,
      ),
    );
  }
}

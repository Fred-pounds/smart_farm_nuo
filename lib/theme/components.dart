import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';
import 'glass.dart';
import 'illustrations.dart';
import 'motion.dart';

/// A section title with an optional action on the right.
///
/// The 20px tier of the scale. Sits directly on the canvas above a group of
/// panels — never inside one, or the hierarchy inverts.
class SectionHeader extends StatelessWidget {
  final String title;

  /// A short trailing word — "See all", "3 due", a date. Tappable when
  /// [onTap] is given.
  final String? trailing;

  final VoidCallback? onTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: Tokens.space1,
        right: Tokens.space1,
        bottom: Tokens.space3,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (trailing != null)
            GestureDetector(
              onTap: onTap == null
                  ? null
                  : () {
                      Haptics.selection();
                      onTap!();
                    },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
                child: Row(
                  children: [
                    Text(
                      trailing!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onTap != null
                            ? colors.growth
                            : colors.inkTertiary,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colors.growth,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The AI insight card: one sentence of advice, and the reasoning behind it.
///
/// The app's most important piece of copy, so it gets the app's only tinted
/// panel and a leading mark that is not a generic lightbulb — the advice is
/// derived from the farm's own numbers, and the card should read as the
/// system reporting rather than as a tip of the day.
///
/// [headline] is the decision. [detail] is why. Never merge them: a farmer
/// scanning at arm's length reads the first line and nothing else, so the
/// action has to survive alone.
class InsightCard extends StatelessWidget {
  final String headline;
  final String detail;

  /// Colours the mark, the border and the tint. Pass the state's colour —
  /// water for "hold irrigation", sun for heat, alert for a fault.
  final Color accent;

  final IconData icon;

  /// An optional one-tap remedy.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Opens the full reasoning.
  final VoidCallback? onWhy;

  const InsightCard({
    super.key,
    required this.headline,
    required this.detail,
    required this.accent,
    this.icon = Icons.auto_awesome_rounded,
    this.actionLabel,
    this.onAction,
    this.onWhy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Panel(
      accentBorder: accent.withValues(alpha: 0.35),
      tinted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm * 0.65),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Farm insight'),
                    const SizedBox(height: 5),
                    Text(headline, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.space3),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.inkSecondary,
            ),
          ),
          if (onAction != null || onWhy != null) ...[
            const SizedBox(height: Tokens.space4),
            Row(
              children: [
                if (onAction != null && actionLabel != null)
                  FilledButton(
                    onPressed: () {
                      Haptics.commandSent();
                      onAction!();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(actionLabel!),
                  ),
                if (onAction != null && onWhy != null)
                  const SizedBox(width: Tokens.space3),
                if (onWhy != null)
                  TextButton(onPressed: onWhy, child: const Text('Why?')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact metric: eyebrow, value, caption.
///
/// The unit of the dashboard's analytics row and the weather screen's stat
/// grid. Values use the tabular numeric styles, so a row of these stays
/// aligned as the numbers change.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final Color? accent;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final tint = accent ?? colors.inkPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: colors.inkTertiary),
              const SizedBox(width: 5),
            ],
            Flexible(child: Eyebrow(label)),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 20,
            color: tint,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colors.inkTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// A search input.
///
/// Filled rather than outlined, because it sits on the canvas above a list
/// and an outline at that position competes with the cards beneath it.
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final hasText = controller?.text.isNotEmpty ?? false;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: colors.panel,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: colors.inkTertiary,
        ),
        suffixIcon: hasText
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear',
                onPressed: () {
                  controller?.clear();
                  onChanged('');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: Tokens.space4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          borderSide: BorderSide(color: colors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          borderSide: BorderSide(color: colors.panelBorder),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of single-select filters.
///
/// Scrolls rather than wraps: a wrapping row changes height as options
/// change, and a list that shifts down when a filter is applied loses the
/// user's place.
class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: Tokens.space2),
        itemBuilder: (context, i) {
          final option = options[i];
          final active = option == selected;

          return GestureDetector(
            onTap: () {
              Haptics.selection();
              onSelected(option);
            },
            child: AnimatedContainer(
              duration: Tokens.motionFast,
              curve: Tokens.curveStandard,
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? colors.growth
                    : colors.panel,
                borderRadius: BorderRadius.circular(Tokens.radiusPill),
                border: Border.all(
                  color: active ? colors.growth : colors.panelBorder,
                ),
              ),
              child: Text(
                option,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active
                      ? Theme.of(context).colorScheme.onPrimary
                      : colors.inkSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  fontVariations: [
                    FontVariation('wght', active ? 700 : 600),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One entry on the tasks timeline.
///
/// The rail down the left is what makes a list of dates read as a schedule
/// rather than as a stack of cards. [isFirst] and [isLast] trim the rail so
/// it does not float above the first node or hang below the last.
class TimelineEntry extends StatelessWidget {
  final Widget child;
  final Color accent;
  final bool isFirst;
  final bool isLast;

  /// Fills the node. For a task that needs attention now; an open node reads
  /// as "scheduled", a filled one as "due".
  final bool filled;

  const TimelineEntry({
    super.key,
    required this.child,
    required this.accent,
    this.isFirst = false,
    this.isLast = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                SizedBox(
                  height: 22,
                  child: isFirst
                      ? null
                      : Center(
                          child: Container(
                            width: 2,
                            color: colors.panelBorder,
                          ),
                        ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: filled ? accent : colors.panel,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(
                          child: Container(
                            width: 2,
                            color: colors.panelBorder,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Tokens.space3),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent card **for the weather screen only**.
///
/// This is the one deliberate exception to "glass is the housing, never the
/// dial". It earns the exception because the weather screen paints its own
/// gradient sky behind these cards — so what sits under the blur is known,
/// bounded, and thematically the point. Everywhere else, a reading over a
/// blur is unreadable in daylight and expensive on mid-range hardware.
///
/// Falls back to an opaque panel under high contrast, exactly as
/// [GlassSurface] does.
class WeatherGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const WeatherGlassCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final radius = BorderRadius.circular(Tokens.radiusLg);
    final content = Padding(
      padding: padding ?? Tokens.panelPadding,
      child: child,
    );

    if (MediaQuery.of(context).highContrast) {
      return Panel(padding: padding, child: child);
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: Tokens.blurPanel,
            sigmaY: Tokens.blurPanel,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassFillStrong,
              borderRadius: radius,
              border: Border.all(color: colors.glassBorder),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.glassHighlight.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0, 0.5],
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// A crop's picture, with a painted fallback for every crop that has none.
///
/// The app ships **no** crop photography. Licensed, consistently lit, uniform
/// aspect photographs of fourteen West African crops are a procurement job,
/// not a code one, and a card that renders a broken-image box is worse than a
/// card that never promised a photo.
///
/// So this is an image *slot*: drop `assets/crops/<crop id>.jpg` in and it
/// appears, with no code change. Until then every crop gets a tinted plate
/// carrying its emoji, which stays legible, follows the theme, and keeps the
/// grid's rhythm identical to how it will look with photographs in place.
class CropImage extends StatelessWidget {
  /// Crop id — `maize`, `tomato`, `cassava`. Names the asset file.
  final String cropId;

  /// Shown on the fallback plate.
  final String emoji;

  final double size;
  final Color accent;
  final BorderRadius? borderRadius;

  const CropImage({
    super.key,
    required this.cropId,
    required this.emoji,
    required this.accent,
    this.size = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(Tokens.radiusMd);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        // Both extensions are tried before giving up. Photographs arrive from
        // phones and stock sites as either, and a card that renders an emoji
        // because the file said `.jpeg` is a bug no one would think to look
        // for. Missing assets are the expected case here, not an error path.
        child: Image.asset(
          'assets/crops/$cropId.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Image.asset(
            'assets/crops/$cropId.jpeg',
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => _Fallback(
              emoji: emoji,
              accent: accent,
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String emoji;
  final Color accent;
  final double size;

  const _Fallback({
    required this.emoji,
    required this.accent,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.42)),
      ),
    );
  }
}

/// A banner-height illustration, for the top of a screen that has one job.
///
/// Sized as a band rather than a square so it introduces the screen without
/// pushing the first control below the fold.
class IllustrationBanner extends StatelessWidget {
  final FarmArt art;
  final String title;
  final String message;
  final Color? accent;

  const IllustrationBanner({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Row(
      children: [
        FarmIllustration(art: art, size: 96, accent: accent),
        const SizedBox(width: Tokens.space4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: Tokens.space2),
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

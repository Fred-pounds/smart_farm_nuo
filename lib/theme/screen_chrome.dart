import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'design_tokens.dart';
import 'glass.dart';
import 'illustrations.dart';

/// The standard screen frame: ambient canvas, floating glass header, content
/// scrolling beneath it.
///
/// Every screen other than the dashboard uses this, so the chrome is defined
/// once. Screens that build their own [AppBar] drift — different heights,
/// different title weights, a shadow here and not there — and the app stops
/// feeling like one product.
///
/// The header is the screen's only blurred surface. Together with the
/// navigation bar that keeps the app at two, which is the budget
/// [GlassSurface] documents.
class GlassScaffold extends StatelessWidget {
  final String title;

  /// Optional second line — a location, a count, a state. Kept short.
  final String? subtitle;

  final List<Widget> actions;

  /// Shown at the far left in place of the automatic back button.
  final Widget? leading;

  /// Scrolling content. Receives the padding needed to clear the header and
  /// the navigation bar, so callers never compute insets themselves.
  final Widget Function(BuildContext context, EdgeInsets contentPadding)
  builder;

  /// Set when the screen sits inside the bottom navigation shell, so content
  /// clears the nav bar too. False for pushed routes, which cover it.
  final bool insideShell;

  final Future<void> Function()? onRefresh;

  final Widget? floatingActionButton;

  /// Rendered inside the glass, beneath the title row — a [TabBar] or a
  /// segmented control. Its height is added to the content inset
  /// automatically, so callers still never compute padding.
  final PreferredSizeWidget? bottom;

  const GlassScaffold({
    super.key,
    required this.title,
    required this.builder,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.insideShell = true,
    this.onRefresh,
    this.floatingActionButton,
    this.bottom,
  });

  static const double headerHeight = 62;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final canPop = Navigator.of(context).canPop();
    final showLeading = leading != null || canPop;

    final bottomHeight = bottom?.preferredSize.height ?? 0;

    final contentPadding = EdgeInsets.only(
      top: topInset + headerHeight + bottomHeight + Tokens.space4,
      left: Tokens.space5,
      right: Tokens.space5,
      bottom: media.padding.bottom + (insideShell ? 96 : Tokens.space8),
    );

    Widget content = builder(context, contentPadding);
    if (onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: onRefresh!,
        edgeOffset: topInset + headerHeight,
        child: content,
      );
    }

    final body = Stack(
      children: [
        content,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlassSurface(
            strong: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: topInset + headerHeight,
                  padding: EdgeInsets.only(
                    top: topInset,
                    left: showLeading ? Tokens.space2 : Tokens.space5,
                    right: Tokens.space2,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    children: [
                      if (showLeading)
                        leading ??
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 22,
                              ),
                              tooltip: 'Back',
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: context.farmColors.inkTertiary,
                                      fontSize: 11.5,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ],
    );

    // Pushed routes paint their own canvas; screens inside the shell inherit
    // the one already behind the navigation stack.
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: insideShell ? body : AmbientBackground(child: body),
    );
  }
}

/// A titled group of panels.
///
/// Screens that are long lists of settings or facts need a rhythm above the
/// panel level, or they read as an undifferentiated stack of boxes.
class Section extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const Section({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: Tokens.space1,
            bottom: Tokens.space2,
          ),
          child: Eyebrow(title),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(
              left: Tokens.space1,
              bottom: Tokens.space3,
              right: Tokens.space4,
            ),
            child: Text(
              description!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
            ),
          ),
        ...children,
      ],
    );
  }
}

/// An empty state that explains rather than apologises.
///
/// A blank screen with a shrug icon tells the farmer nothing. Every empty
/// state here says what would fill it and, where there is one, offers the
/// action that does.
///
/// The illustration is the payload, not decoration: an empty Tasks screen
/// showing a calendar is instantly placeable, where the same screen showing a
/// grey circle could be an error, a permission prompt or a network failure.
class EmptyState extends StatelessWidget {
  /// The piece of the illustration set that names what is missing.
  final FarmArt art;

  final String title;
  final String message;
  final Widget? action;

  /// Tints the illustration. Defaults to the growth accent.
  final Color? accent;

  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FarmIllustration(art: art, size: 148, accent: accent),
          const SizedBox(height: Tokens.space5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Tokens.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space5),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: Tokens.space6),
            action!,
          ],
        ],
      ),
    );
  }
}

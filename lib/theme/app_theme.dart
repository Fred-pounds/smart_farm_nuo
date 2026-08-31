import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// The Smart Farm theme.
///
/// ## Design philosophy
///
/// The farm is loud, physical and unpredictable. The interface answering for
/// it should be the opposite: calm, precise, and quiet enough that a change on
/// screen means something changed on the farm.
///
/// Five rules produce that:
///
/// 1. **Glass is the instrument housing, never the dial.** Blur belongs to
///    navigation, headers, sheets, and the weather screen — where the subject
///    genuinely is atmosphere. Every value a farmer acts on is painted opaque
///    on a solid panel. The app is read outdoors in daylight; translucency
///    under a number is the first thing to fail there.
///
/// 2. **One accent per meaning.** Water is always Sky Blue, dry soil always
///    warm ochre, an alert always red. Colour is a data channel here, so
///    decorative colour is not available.
///
/// 3. **Brand hues fill; ink hues label.** See [Palette] — the brand accents
///    are chosen for gauges and charts, and most of them fail AA as text.
///
/// 4. **Depth is earned, not applied.** A surface is raised only when it
///    genuinely sits above another. Uniform drop shadows on everything
///    flatten the hierarchy they are meant to express.
///
/// 5. **Motion reports, it does not perform.** Nothing bounces or overshoots.
///    A live reading that springs on arrival reads as the measurement itself
///    being unstable.
///
/// Neither brightness is generated from the other, and neither uses
/// `ColorScheme.fromSeed` for its accents.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final farm = isDark ? FarmColors.dark : FarmColors.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: farm.growth,
      onPrimary: isDark ? const Color(0xFF06170D) : Colors.white,
      primaryContainer: farm.growth.withValues(alpha: isDark ? 0.22 : 0.12),
      onPrimaryContainer: farm.growth,
      secondary: farm.water,
      onSecondary: isDark ? const Color(0xFF04141C) : Colors.white,
      secondaryContainer: farm.water.withValues(alpha: isDark ? 0.22 : 0.12),
      onSecondaryContainer: farm.water,
      tertiary: farm.sun,
      onTertiary: Colors.white,
      error: farm.alert,
      onError: Colors.white,
      errorContainer: farm.alert.withValues(alpha: isDark ? 0.22 : 0.12),
      onErrorContainer: farm.alert,
      surface: farm.panel,
      onSurface: farm.inkPrimary,
      surfaceContainerHighest: farm.panelMuted,
      onSurfaceVariant: farm.inkSecondary,
      outline: farm.panelBorder,
      outlineVariant: farm.panelBorder,
      shadow: farm.panelShadow,
    );

    final text = Tokens.textTheme(farm.inkPrimary, farm.inkSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: Tokens.fontFamily,
      // The canvas is painted by AmbientBackground, not by the Scaffold, so
      // the gradient and its colour fields sit behind every route.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory,
      // Fade-through on every push, replacing the platform slide. A dashboard
      // that slides sideways to a detail view reads as a different app; a
      // cross-fade reads as the same surface changing subject.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: farm.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusLg),
          side: BorderSide(color: farm.panelBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: farm.inkPrimary, size: 22),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // Transparent so the glass plate behind it does the work.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: farm.growth.withValues(alpha: isDark ? 0.22 : 0.13),
        indicatorShape: const StadiumBorder(),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium!.copyWith(
            fontSize: 11.5,
            color: selected ? farm.growth : farm.inkTertiary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontVariations: [FontVariation('wght', selected ? 700 : 500)],
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? farm.growth : farm.inkTertiary,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: farm.growth,
        unselectedLabelColor: farm.inkTertiary,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          fontVariations: const [FontVariation('wght', 500)],
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
          borderSide: BorderSide(color: farm.growth, width: 2.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: farm.panelBorder,
        thickness: 1,
        space: Tokens.space6,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: farm.panelMuted,
        selectedColor: farm.growth.withValues(alpha: isDark ? 0.22 : 0.12),
        side: BorderSide(color: farm.panelBorder),
        labelStyle: text.labelMedium!,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space3,
          vertical: Tokens.space2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusPill),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space6),
          textStyle: text.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: farm.inkPrimary,
          side: BorderSide(color: farm.panelBorder),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: farm.growth,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: farm.growth,
        foregroundColor: isDark ? const Color(0xFF06170D) : Colors.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge?.copyWith(
          color: isDark ? const Color(0xFF06170D) : Colors.white,
        ),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: farm.chromeSolid,
        contentTextStyle: text.bodyMedium!.copyWith(color: farm.inkPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: farm.panel,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: farm.panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Tokens.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: farm.panelMuted,
        hintStyle: text.bodyMedium!.copyWith(color: farm.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          borderSide: BorderSide(color: farm.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          borderSide: BorderSide(color: farm.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          borderSide: BorderSide(color: farm.growth, width: 1.6),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: farm.growth,
        linearTrackColor: farm.panelMuted,
        circularTrackColor: farm.panelMuted,
        linearMinHeight: 6,
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        iconColor: farm.inkTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
        ),
      ),
      extensions: [farm],
    );
  }
}

/// Cross-fade with a small scale, in place of the platform slide.
///
/// A slide implies lateral movement through a hierarchy. Most pushes in this
/// app change the *subject* rather than the level — Farm to Alerts, Crops to
/// one crop — and a fade-through says that more honestly. The 2% scale is
/// what keeps it from reading as a dissolve.
class _FadeThroughTransitionBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Tokens.curveStandard,
      reverseCurve: Tokens.curveStandard.flipped,
    );

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

/// Every semantic colour in the app, resolved per brightness.
///
/// Widgets read colour through `context.farmColors` and never through
/// `Colors.*`. A hard-coded `Colors.blue` looks acceptable in one theme and
/// breaks in the other, and worse, it silently detaches a value from its
/// meaning — "water" stops being one colour across the app.
///
/// ## Ink versus bright
///
/// [growth], [water], [sun] and [alert] are contrast-checked for **text and
/// icons**. [growthBright], [waterBright], [sunBright] and [alertBright] are
/// the brand hues, for **fills** — gauge arcs, chart strokes, gradients,
/// illustration shapes, chip backgrounds. Reaching for a bright value to
/// colour a word is the one way to break the palette's accessibility floor.
@immutable
class FarmColors extends ThemeExtension<FarmColors> {
  // --- Meaning, text-safe --------------------------------------------------
  /// Crops, health, confirmation. The app's primary accent.
  final Color growth;

  /// Water, irrigation, rain. Never used decoratively.
  final Color water;

  /// Heat, caution, "look at this soon".
  final Color sun;

  /// Faults and states that need action now.
  final Color alert;

  /// Dry soil, above the irrigation threshold.
  final Color soilDry;

  /// Moist soil, below the threshold.
  final Color soilWet;

  // --- Meaning, brand fills ------------------------------------------------
  /// Fill-only counterparts. Fails AA as text in light mode — see the class
  /// doc.
  final Color growthBright;
  final Color waterBright;
  final Color sunBright;
  final Color alertBright;

  // --- Ink -----------------------------------------------------------------
  /// Values, headings — anything that must survive daylight.
  final Color inkPrimary;

  /// Supporting prose.
  final Color inkSecondary;

  /// Captions, units, disabled states. The lightest text permitted; still
  /// contrast-checked against the panel fill.
  final Color inkTertiary;

  // --- Surfaces ------------------------------------------------------------
  /// Solid data panel. Opaque by design: readings sit here.
  final Color panel;

  /// A recessed well inside a panel — inputs, chips, chart backgrounds.
  final Color panelMuted;

  final Color panelBorder;

  /// Shadow beneath a raised panel.
  final Color panelShadow;

  // --- Glass (chrome and weather only) -------------------------------------
  final Color glassFill;
  final Color glassFillStrong;
  final Color glassBorder;

  /// The bright top edge that makes a translucent surface read as glass
  /// rather than as a flat tint.
  final Color glassHighlight;

  /// Opaque replacement for glass when transparency is switched off.
  final Color chromeSolid;

  // --- Canvas --------------------------------------------------------------
  final Color canvasTop;
  final Color canvasMid;
  final Color canvasBottom;

  /// Soft colour fields behind the glass. Without something to refract, a
  /// blurred surface is just grey.
  final Color auraGrowth;
  final Color auraWater;
  final Color auraSun;

  const FarmColors({
    required this.growth,
    required this.water,
    required this.sun,
    required this.alert,
    required this.soilDry,
    required this.soilWet,
    required this.growthBright,
    required this.waterBright,
    required this.sunBright,
    required this.alertBright,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.panel,
    required this.panelMuted,
    required this.panelBorder,
    required this.panelShadow,
    required this.glassFill,
    required this.glassFillStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.chromeSolid,
    required this.canvasTop,
    required this.canvasMid,
    required this.canvasBottom,
    required this.auraGrowth,
    required this.auraWater,
    required this.auraSun,
  });

  // Aliases kept so existing widgets keep compiling and keep meaning the same
  // thing.
  Color get warning => sun;
  Color get danger => alert;
  Color get success => growth;
  Color get muted => inkTertiary;

  static const FarmColors light = FarmColors(
    growth: Palette.lightGrowth,
    water: Palette.lightWater,
    sun: Palette.lightSun,
    alert: Palette.lightAlert,
    soilDry: Palette.lightSoilDry,
    soilWet: Palette.lightSoilWet,
    growthBright: Palette.brandFreshGreen,
    waterBright: Palette.brandSkyBlue,
    sunBright: Palette.brandWarning,
    alertBright: Palette.brandDanger,
    inkPrimary: Palette.lightInkPrimary,
    inkSecondary: Palette.lightInkSecondary,
    inkTertiary: Palette.lightInkTertiary,
    panel: Color(0xFFFFFFFF),
    panelMuted: Color(0xFFF1F5F2),
    panelBorder: Color(0x141B1B1B),
    panelShadow: Color(0x14243028),
    glassFill: Palette.lightGlassFill,
    glassFillStrong: Palette.lightGlassFillStrong,
    glassBorder: Palette.lightGlassBorder,
    glassHighlight: Palette.lightGlassHighlight,
    chromeSolid: Palette.lightSolidSurface,
    canvasTop: Color(0xFFF7FAF7),
    canvasMid: Color(0xFFEFF5F0),
    canvasBottom: Color(0xFFF7FAF7),
    auraGrowth: Palette.lightAuraGrowth,
    auraWater: Palette.lightAuraWater,
    auraSun: Palette.lightAuraSun,
  );

  static const FarmColors dark = FarmColors(
    growth: Palette.darkGrowth,
    water: Palette.darkWater,
    sun: Palette.darkSun,
    alert: Palette.darkAlert,
    soilDry: Palette.darkSoilDry,
    soilWet: Palette.darkSoilWet,
    // On a near-black panel the brand hues already clear AA, so the two
    // tiers converge and nothing has to be re-tinted for fills.
    growthBright: Palette.darkGrowth,
    waterBright: Palette.brandSkyBlue,
    sunBright: Palette.darkSun,
    alertBright: Palette.darkAlert,
    inkPrimary: Palette.darkInkPrimary,
    inkSecondary: Palette.darkInkSecondary,
    inkTertiary: Palette.darkInkTertiary,
    panel: Color(0xFF1A211D),
    panelMuted: Color(0xFF212A25),
    panelBorder: Color(0x1FFFFFFF),
    panelShadow: Color(0x73000000),
    glassFill: Palette.darkGlassFill,
    glassFillStrong: Palette.darkGlassFillStrong,
    glassBorder: Palette.darkGlassBorder,
    glassHighlight: Palette.darkGlassHighlight,
    chromeSolid: Palette.darkSolidSurface,
    canvasTop: Color(0xFF101412),
    canvasMid: Color(0xFF151B18),
    canvasBottom: Color(0xFF0C100E),
    auraGrowth: Palette.darkAuraGrowth,
    auraWater: Palette.darkAuraWater,
    auraSun: Palette.darkAuraSun,
  );

  @override
  FarmColors copyWith({
    Color? growth,
    Color? water,
    Color? sun,
    Color? alert,
    Color? soilDry,
    Color? soilWet,
    Color? growthBright,
    Color? waterBright,
    Color? sunBright,
    Color? alertBright,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? panel,
    Color? panelMuted,
    Color? panelBorder,
    Color? panelShadow,
    Color? glassFill,
    Color? glassFillStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? chromeSolid,
    Color? canvasTop,
    Color? canvasMid,
    Color? canvasBottom,
    Color? auraGrowth,
    Color? auraWater,
    Color? auraSun,
  }) {
    return FarmColors(
      growth: growth ?? this.growth,
      water: water ?? this.water,
      sun: sun ?? this.sun,
      alert: alert ?? this.alert,
      soilDry: soilDry ?? this.soilDry,
      soilWet: soilWet ?? this.soilWet,
      growthBright: growthBright ?? this.growthBright,
      waterBright: waterBright ?? this.waterBright,
      sunBright: sunBright ?? this.sunBright,
      alertBright: alertBright ?? this.alertBright,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      panel: panel ?? this.panel,
      panelMuted: panelMuted ?? this.panelMuted,
      panelBorder: panelBorder ?? this.panelBorder,
      panelShadow: panelShadow ?? this.panelShadow,
      glassFill: glassFill ?? this.glassFill,
      glassFillStrong: glassFillStrong ?? this.glassFillStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      chromeSolid: chromeSolid ?? this.chromeSolid,
      canvasTop: canvasTop ?? this.canvasTop,
      canvasMid: canvasMid ?? this.canvasMid,
      canvasBottom: canvasBottom ?? this.canvasBottom,
      auraGrowth: auraGrowth ?? this.auraGrowth,
      auraWater: auraWater ?? this.auraWater,
      auraSun: auraSun ?? this.auraSun,
    );
  }

  @override
  FarmColors lerp(ThemeExtension<FarmColors>? other, double t) {
    if (other is! FarmColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FarmColors(
      growth: l(growth, other.growth),
      water: l(water, other.water),
      sun: l(sun, other.sun),
      alert: l(alert, other.alert),
      soilDry: l(soilDry, other.soilDry),
      soilWet: l(soilWet, other.soilWet),
      growthBright: l(growthBright, other.growthBright),
      waterBright: l(waterBright, other.waterBright),
      sunBright: l(sunBright, other.sunBright),
      alertBright: l(alertBright, other.alertBright),
      inkPrimary: l(inkPrimary, other.inkPrimary),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkTertiary: l(inkTertiary, other.inkTertiary),
      panel: l(panel, other.panel),
      panelMuted: l(panelMuted, other.panelMuted),
      panelBorder: l(panelBorder, other.panelBorder),
      panelShadow: l(panelShadow, other.panelShadow),
      glassFill: l(glassFill, other.glassFill),
      glassFillStrong: l(glassFillStrong, other.glassFillStrong),
      glassBorder: l(glassBorder, other.glassBorder),
      glassHighlight: l(glassHighlight, other.glassHighlight),
      chromeSolid: l(chromeSolid, other.chromeSolid),
      canvasTop: l(canvasTop, other.canvasTop),
      canvasMid: l(canvasMid, other.canvasMid),
      canvasBottom: l(canvasBottom, other.canvasBottom),
      auraGrowth: l(auraGrowth, other.auraGrowth),
      auraWater: l(auraWater, other.auraWater),
      auraSun: l(auraSun, other.auraSun),
    );
  }
}

extension FarmColorsX on BuildContext {
  FarmColors get farmColors =>
      Theme.of(this).extension<FarmColors>() ?? FarmColors.light;
}

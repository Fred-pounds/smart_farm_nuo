import 'package:flutter/material.dart';

/// The raw design scale for Smart Farm.
///
/// Every colour, size, radius, blur, duration and text style in the app
/// resolves to a value in this file. Widgets never invent one. A screen that
/// needs a value that is not here is a signal that the scale is incomplete,
/// not a licence to hard-code.
///
/// ## The two rules
///
/// **1. Glass is the instrument housing, never the dial.**
///
/// Translucency belongs to structure — navigation, headers, sheets — and to
/// the weather screen, where the subject genuinely is atmosphere. The values a
/// farmer acts on (a moisture reading, a pump state, an alert) are painted at
/// full opacity on a solid [Panel].
///
/// The app is read outdoors, in daylight, on mid-range phones. Text floated at
/// partial opacity over a blurred backdrop is the first thing to become
/// unreadable in the field, and a farmer who cannot read the number cannot
/// trust the system. `BackdropFilter` is also the single most expensive thing
/// on screen: it re-rasterises everything beneath it every frame.
///
/// **2. Every semantic colour has an ink pair and a bright pair.**
///
/// The brand accents (Fresh Green `#4CAF50`, Sky Blue `#4FC3F7`, Warning
/// `#FB8C00`) are chosen for *fills* — gauges, charts, gradients, chips. Most
/// of them fail WCAG AA as text on a white card: Sky Blue on white is 1.9:1,
/// where 4.5:1 is the floor for body copy.
///
/// So each meaning carries two values. `growth` / `water` / `sun` / `alert`
/// are contrast-checked and safe for text and icons. `growthBright` /
/// `waterBright` / `sunBright` / `alertBright` are the brand hues, used only
/// where the colour is a shape rather than a glyph. In dark mode the two
/// converge, because a mid-tone accent on a near-black panel already clears
/// AA.
class Tokens {
  const Tokens._();

  // ===========================================================================
  // TYPEFACE
  // ===========================================================================

  /// Plus Jakarta Sans, bundled as a variable font (weight axis 200–800).
  ///
  /// Bundled rather than fetched. `google_fonts` downloads at first paint,
  /// and this app has to render a moisture reading in a field with no signal.
  /// One 176 KB file covers every weight the app uses.
  static const String fontFamily = 'PlusJakartaSans';

  // ===========================================================================
  // SPACING — 4pt grid
  // ===========================================================================

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space14 = 56;

  /// Standard page gutter.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: space5,
  );

  /// Inner padding for a panel.
  static const EdgeInsets panelPadding = EdgeInsets.all(space5);

  // ===========================================================================
  // RADII
  // ===========================================================================
  //
  // The house style is soft: 20–24 on anything panel-sized. Nothing in the app
  // has a sharp corner except a full-bleed edge.

  /// Chips, inputs, small buttons.
  static const double radiusSm = 16;

  /// Wells, tiles, secondary surfaces.
  static const double radiusMd = 20;

  /// The default panel radius. Most cards land here.
  static const double radiusLg = 24;

  /// Hero surfaces and bottom sheets.
  static const double radiusXl = 28;

  static const double radiusPill = 999;

  // ===========================================================================
  // ELEVATION
  // ===========================================================================
  //
  // Depth is earned. A surface is raised only when it genuinely sits above
  // another; uniform drop shadows on everything flatten the hierarchy they
  // are meant to express.

  /// A resting card lifted just off the canvas.
  static List<BoxShadow> restingShadow(Color shadow) => [
    BoxShadow(
      color: shadow,
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: -10,
    ),
  ];

  /// The hero card, and anything the user has picked up.
  static List<BoxShadow> raisedShadow(Color shadow) => [
    BoxShadow(
      color: shadow,
      blurRadius: 40,
      offset: const Offset(0, 16),
      spreadRadius: -14,
    ),
  ];

  // ===========================================================================
  // BLUR TIERS
  // ===========================================================================
  //
  // Three deliberate steps. Blur sigma dominates the cost of a
  // BackdropFilter, and an app where every surface picks its own value looks
  // incoherent and profiles unpredictably.

  /// Chrome that sits above scrolling content: nav bar, headers, sheets.
  static const double blurChrome = 30;

  /// Weather cards — the one place glass carries content, because the
  /// content is sky.
  static const double blurPanel = 18;

  /// Inset elements: chips, pressed states, small wells.
  static const double blurInset = 10;

  // ===========================================================================
  // MOTION
  // ===========================================================================
  //
  // Nothing bounces. This is an instrument, and overshoot on a live reading
  // reads as the value itself wobbling.

  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionBase = Duration(milliseconds: 240);
  static const Duration motionSlow = Duration(milliseconds: 380);

  /// Gauges, rings and charts filling for the first time. Long enough to be
  /// legible as movement, short enough not to delay the reading.
  static const Duration motionGauge = Duration(milliseconds: 900);

  /// One full sweep of a shimmer placeholder.
  static const Duration motionShimmer = Duration(milliseconds: 1400);

  /// For state changes the user caused — taps, toggles, expansion.
  static const Curve curveStandard = Curves.easeOutCubic;

  /// For values arriving from the farm on their own. Slower in and out, so a
  /// sensor update reads as settling rather than snapping.
  static const Curve curveData = Curves.easeInOutCubic;

  /// Gauge sweeps and score rings: decelerating, never overshooting.
  static const Curve curveGauge = Curves.easeOutQuart;

  // ===========================================================================
  // TYPE SCALE
  // ===========================================================================

  /// Live numerals use tabular figures so a changing reading does not shift
  /// width character by character. On a real-time dashboard, proportional
  /// digits make every update look like a layout glitch.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Builds one style against the bundled variable font.
  ///
  /// Both [FontWeight] and [FontVariation] are set: the variation drives the
  /// real weight axis, and the weight keeps matching sane if the font ever
  /// fails to load and the platform face substitutes in.
  static TextStyle _style({
    required double size,
    required double height,
    required int weight,
    required double tracking,
    required Color color,
    bool numeric = false,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: tracking,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: [FontVariation('wght', weight.toDouble())],
      fontFeatures: numeric ? tabular : null,
    );
  }

  /// The scale, in five sizes plus a numeric readout tier.
  ///
  /// Display 28–32 · Section title 20 · Card title 16 · Body 14 · Label 12.
  /// Bold is used sparingly — hierarchy comes from size and colour first,
  /// weight last.
  static TextTheme textTheme(Color primary, Color secondary) {
    return TextTheme(
      // --- Display: the hero readout. One per screen at most. ---------------
      displayLarge: _style(
        size: 32,
        height: 1.05,
        weight: 600,
        tracking: -1.0,
        color: primary,
        numeric: true,
      ),
      displayMedium: _style(
        size: 28,
        height: 1.1,
        weight: 600,
        tracking: -0.8,
        color: primary,
        numeric: true,
      ),
      // Kept for numeric cells that sit mid-hierarchy.
      displaySmall: _style(
        size: 22,
        height: 1.15,
        weight: 600,
        tracking: -0.5,
        color: primary,
        numeric: true,
      ),

      // --- Section titles ---------------------------------------------------
      headlineSmall: _style(
        size: 20,
        height: 1.25,
        weight: 600,
        tracking: -0.4,
        color: primary,
      ),
      titleLarge: _style(
        size: 20,
        height: 1.25,
        weight: 600,
        tracking: -0.4,
        color: primary,
      ),

      // --- Card titles ------------------------------------------------------
      titleMedium: _style(
        size: 16,
        height: 1.3,
        weight: 600,
        tracking: -0.2,
        color: primary,
      ),
      titleSmall: _style(
        size: 14,
        height: 1.3,
        weight: 600,
        tracking: -0.1,
        color: primary,
      ),

      // --- Body -------------------------------------------------------------
      bodyLarge: _style(
        size: 15,
        height: 1.5,
        weight: 400,
        tracking: 0,
        color: primary,
      ),
      bodyMedium: _style(
        size: 14,
        height: 1.5,
        weight: 400,
        tracking: 0,
        color: secondary,
      ),
      bodySmall: _style(
        size: 12,
        height: 1.45,
        weight: 400,
        tracking: 0,
        color: secondary,
      ),

      // --- Labels -----------------------------------------------------------
      // Eyebrows. Uppercased at the call site by `Eyebrow`.
      labelSmall: _style(
        size: 11,
        height: 1.2,
        weight: 700,
        tracking: 0.8,
        color: secondary,
      ),
      labelMedium: _style(
        size: 12,
        height: 1.2,
        weight: 600,
        tracking: 0.1,
        color: secondary,
      ),
      labelLarge: _style(
        size: 14,
        height: 1.2,
        weight: 600,
        tracking: 0,
        color: primary,
      ),
    );
  }
}

/// The palette, in two fully specified sets.
///
/// Neither theme is derived from the other by inverting, and neither uses
/// `ColorScheme.fromSeed` for its accents. Generated schemes drift toward
/// Material's own personality and produce accents that are *almost* right —
/// which on a farm dashboard means "dry" and "wet" stop being instantly
/// distinguishable. Both sets are chosen by hand and contrast-checked.
///
/// ## Brand versus ink
///
/// The `*Bright` values are the brand hues. They are for fills: gauge arcs,
/// chart strokes, gradients, chip backgrounds, illustration shapes. The plain
/// values are the same meanings pushed to at least 4.5:1 against their
/// surface, and are the only ones permitted for text and icons in light mode.
class Palette {
  const Palette._();

  // ===========================================================================
  // BRAND — the source hues, identical in both themes
  // ===========================================================================

  /// Deep Green. The signature colour.
  static const Color brandDeepGreen = Color(0xFF2E7D32);

  /// Fresh Green. Fills and healthy states.
  static const Color brandFreshGreen = Color(0xFF4CAF50);

  /// Sky Blue. Water, rain, irrigation — never decorative.
  static const Color brandSkyBlue = Color(0xFF4FC3F7);

  static const Color brandSuccess = Color(0xFF43A047);
  static const Color brandWarning = Color(0xFFFB8C00);
  static const Color brandDanger = Color(0xFFE53935);

  // ===========================================================================
  // LIGHT — the default experience
  // ===========================================================================

  /// The canvas. A near-white with a green cast, so white cards read as
  /// raised rather than as holes.
  static const List<Color> lightCanvas = [
    Color(0xFFF7FAF7),
    Color(0xFFEFF5F0),
    Color(0xFFF7FAF7),
  ];

  /// Soft colour fields behind the glass chrome. Without something to
  /// refract, a blurred surface is just grey.
  static const Color lightAuraGrowth = Color(0xFF8FD9A8);
  static const Color lightAuraWater = Color(0xFF9BD9F5);
  static const Color lightAuraSun = Color(0xFFF6D9A6);

  /// Three ink steps, all at or above 4.5:1 on white.
  /// `#1B1B1B` 16.1:1 · `#4B5563` 7.6:1 · `#6B7280` 4.8:1.
  static const Color lightInkPrimary = Color(0xFF1B1B1B);
  static const Color lightInkSecondary = Color(0xFF4B5563);
  static const Color lightInkTertiary = Color(0xFF6B7280);

  static const Color lightGlassFill = Color(0xA6FFFFFF);
  static const Color lightGlassFillStrong = Color(0xCCFFFFFF);
  static const Color lightGlassBorder = Color(0xC4FFFFFF);
  static const Color lightGlassHighlight = Color(0xF2FFFFFF);
  static const Color lightSolidSurface = Color(0xFFFFFFFF);

  /// Text-safe accents. Each is the brand hue darkened to clear AA on white.
  static const Color lightGrowth = brandDeepGreen; // 6.4:1
  static const Color lightWater = Color(0xFF0277BD); // 5.6:1
  static const Color lightSun = Color(0xFFB45C09); // 4.7:1
  static const Color lightAlert = Color(0xFFC62828); // 6.1:1

  /// Soil is the one reading a farmer must never misread, so it uses the
  /// most colour-vision-safe pair available: warm orange against cool blue.
  static const Color lightSoilDry = Color(0xFFB45C09);
  static const Color lightSoilWet = Color(0xFF0277BD);

  // ===========================================================================
  // DARK — near-black with a green cast
  // ===========================================================================

  static const List<Color> darkCanvas = [
    Color(0xFF101412),
    Color(0xFF151B18),
    Color(0xFF0C100E),
  ];

  static const Color darkAuraGrowth = Color(0xFF1F6B44);
  static const Color darkAuraWater = Color(0xFF14526B);
  static const Color darkAuraSun = Color(0xFF6B4A1A);

  static const Color darkInkPrimary = Color(0xFFECF1ED);
  static const Color darkInkSecondary = Color(0xFFB4BDB7);
  static const Color darkInkTertiary = Color(0xFF8D978F);

  static const Color darkGlassFill = Color(0x12FFFFFF);
  static const Color darkGlassFillStrong = Color(0x1AFFFFFF);
  static const Color darkGlassBorder = Color(0x1FFFFFFF);
  static const Color darkGlassHighlight = Color(0x26FFFFFF);
  static const Color darkSolidSurface = Color(0xFF1A211D);

  /// On a near-black panel the brand hues already clear AA, so ink and
  /// bright converge — only the deep green has to be lifted, because
  /// `#2E7D32` on `#1A211D` is 2.6:1.
  static const Color darkGrowth = Color(0xFF66BB6A);
  static const Color darkWater = brandSkyBlue;
  static const Color darkSun = Color(0xFFFFA726);
  static const Color darkAlert = Color(0xFFEF5350);

  static const Color darkSoilDry = Color(0xFFFFA726);
  static const Color darkSoilWet = brandSkyBlue;
}

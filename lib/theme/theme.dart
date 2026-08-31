/// The design system, in one import.
///
/// Screens and widgets take `import '../theme/theme.dart';` rather than
/// reaching into individual files, so adding a component or token does not
/// mean touching every call site.
///
/// The layers, from the bottom up:
///
/// * `design_tokens` — the raw scale. Colours, spacing, radii, type, motion.
/// * `app_theme` — those tokens bound into a `ThemeData` and a `FarmColors`
///   extension. `context.farmColors` is how every widget reads colour.
/// * `glass` — the surface primitives: the canvas, glass chrome, `Panel`.
/// * `components` — everything built from those: insight cards, stat tiles,
///   search, filters, timeline, the crop image slot.
/// * `gauges` — animated circular and linear readouts.
/// * `illustrations` — the painted art set.
/// * `skeleton` — shimmer and loading placeholders.
/// * `motion` — haptics, entrance animations, animated counters.
/// * `screen_chrome` — the screen frame every route is built inside.
library;

export 'app_theme.dart';
export 'components.dart';
export 'design_tokens.dart';
export 'gauges.dart';
export 'glass.dart';
export 'illustrations.dart';
export 'motion.dart';
export 'screen_chrome.dart';
export 'skeleton.dart';

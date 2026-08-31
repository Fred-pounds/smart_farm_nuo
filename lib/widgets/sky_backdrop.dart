import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../theme/theme.dart';

/// A gradient sky, tinted by the current condition.
///
/// Two jobs, in this order:
///
/// 1. **It makes the glass work.** `WeatherGlassCard` is the app's one
///    content-bearing translucent surface, and a blur over a flat colour
///    produces flat colour. The gradient is what the cards refract.
/// 2. **It reports the weather before a word is read.** Overcast is grey,
///    rain is blue, clear is warm, night is deep. A farmer who glances at the
///    tab knows roughly what they are about to read.
///
/// Deliberately **not** a photograph. Glass is only guaranteed legible when
/// what sits behind it is known and bounded, and a photographic sky puts
/// unpredictable contrast under readings. Gradients also cost almost nothing
/// to paint, which matters on a screen that already carries several blurs.
///
/// Every pairing is tinted from the theme's own canvas rather than from raw
/// sky colours, so the light and dark themes stay recognisably the same app.
class SkyBackdrop extends StatelessWidget {
  /// Null before the first forecast lands — falls back to the plain canvas.
  final WeatherCondition? condition;

  final bool isDay;

  const SkyBackdrop({super.key, this.condition, this.isDay = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final tint = _tint(condition, isDay, colors);

    return AnimatedContainer(
      duration: Tokens.motionSlow,
      curve: Tokens.curveData,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            // The tint is strongest at the top, where the sky would be, and
            // fades into the app's normal canvas by the bottom of the screen
            // so the nav bar sits on familiar ground.
            Color.alphaBlend(
              tint.withValues(alpha: dark ? 0.30 : 0.34),
              colors.canvasTop,
            ),
            Color.alphaBlend(
              tint.withValues(alpha: dark ? 0.14 : 0.16),
              colors.canvasMid,
            ),
            colors.canvasBottom,
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }

  /// The hue for a condition. Night overrides everything except storms —
  /// after dark, "partly cloudy" and "clear" look the same from a doorway.
  static Color _tint(
    WeatherCondition? condition,
    bool isDay,
    FarmColors colors,
  ) {
    if (condition == null) return colors.auraGrowth;

    if (!isDay) {
      return switch (condition) {
        WeatherCondition.thunderstorm ||
        WeatherCondition.heavyRain ||
        WeatherCondition.rain ||
        WeatherCondition.drizzle => colors.auraWater,
        _ => colors.auraWater.withValues(alpha: 0.6),
      };
    }

    return switch (condition) {
      WeatherCondition.clear => colors.auraSun,
      WeatherCondition.partlyCloudy => colors.auraSun.withValues(alpha: 0.55),
      WeatherCondition.cloudy || WeatherCondition.fog => colors.inkTertiary,
      WeatherCondition.drizzle ||
      WeatherCondition.rain ||
      WeatherCondition.heavyRain ||
      WeatherCondition.snow => colors.auraWater,
      // A storm should not look like ordinary rain.
      WeatherCondition.thunderstorm => colors.auraSun.withValues(alpha: 0.4),
      WeatherCondition.unknown => colors.auraGrowth,
    };
  }
}

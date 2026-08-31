import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../theme/theme.dart';

/// Maps a [WeatherCondition] to a Material icon and a sensible tint, so every
/// screen renders the same condition the same way.
class WeatherIcon extends StatelessWidget {
  final WeatherCondition condition;
  final double size;
  final bool isDay;
  final Color? color;

  const WeatherIcon({
    super.key,
    required this.condition,
    this.size = 24,
    this.isDay = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    final (icon, tint) = switch (condition) {
      WeatherCondition.clear => (
        isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
        isDay ? colors.warning : colors.muted,
      ),
      WeatherCondition.partlyCloudy => (
        isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined,
        colors.muted,
      ),
      WeatherCondition.cloudy => (Icons.cloud_rounded, colors.muted),
      WeatherCondition.fog => (Icons.foggy, colors.muted),
      WeatherCondition.drizzle => (Icons.grain_rounded, colors.water),
      WeatherCondition.rain => (Icons.water_drop_rounded, colors.water),
      WeatherCondition.heavyRain => (Icons.thunderstorm_outlined, colors.water),
      WeatherCondition.thunderstorm => (Icons.flash_on_rounded, colors.warning),
      WeatherCondition.snow => (Icons.ac_unit_rounded, colors.water),
      WeatherCondition.unknown => (Icons.help_outline_rounded, colors.muted),
    };

    return Icon(icon, size: size, color: color ?? tint);
  }
}

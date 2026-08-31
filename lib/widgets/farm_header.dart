import 'package:flutter/material.dart';

import '../logic/farm_status.dart';
import '../models/weather.dart';
import '../theme/theme.dart';
import 'weather_icon.dart';

/// The dashboard's floating header: who, where, and two ways out.
///
/// Modelled on a banking app's account header rather than a Material app bar.
/// The farm's name and the time of day are identity, not navigation, so they
/// get the left edge and the visual weight; the two destinations that are not
/// tabs — the assistant and settings — sit at the right as icons.
///
/// One of only two blurred surfaces in the app, and it carries no reading.
class FarmHeader extends StatelessWidget {
  final String farmName;

  /// The person to greet. Empty falls back to greeting the farm itself, so
  /// the header never reads "Good morning," with nothing after the comma.
  final String farmerName;
  final double height;
  final double topInset;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenSettings;

  const FarmHeader({
    super.key,
    required this.farmName,
    required this.farmerName,
    required this.height,
    required this.topInset,
    required this.onOpenAssistant,
    required this.onOpenSettings,
  });

  /// "Good morning" / "Good afternoon" / "Good evening".
  ///
  /// Farming days start early and run late, so the boundaries are pushed out
  /// from the usual 12/18: at 5am a farmer is already working, and greeting
  /// them with "good evening" at 6pm while there is still light is wrong.
  static String greetingFor(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GlassSurface(
        strong: true,
        child: Container(
          height: topInset + height,
          padding: EdgeInsets.only(
            top: topInset,
            left: Tokens.space5,
            right: Tokens.space2,
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmerName.isEmpty
                          ? greetingFor(DateTime.now())
                          : '${greetingFor(DateTime.now())}, $farmerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      farmName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Ask about your farm',
                icon: const Icon(Icons.forum_rounded, size: 21),
                onPressed: () {
                  Haptics.selection();
                  onOpenAssistant();
                },
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune_rounded, size: 21),
                onPressed: () {
                  Haptics.selection();
                  onOpenSettings();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The strip directly under the header: today's weather on the left, the
/// farm's overall state on the right.
///
/// Deliberately not a panel. It is a caption for the hero card below it, and
/// boxing it would make the screen open with two cards competing for the
/// first read.
class ConditionsStrip extends StatelessWidget {
  final WeatherReport? weather;
  final FarmTone tone;
  final String statusLabel;

  /// Opens the Weather tab.
  final VoidCallback onOpenWeather;

  const ConditionsStrip({
    super.key,
    required this.weather,
    required this.tone,
    required this.statusLabel,
    required this.onOpenWeather,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final theme = Theme.of(context);
    final current = weather?.current;

    final accent = switch (tone) {
      FarmTone.settled => colors.growth,
      FarmTone.working => colors.water,
      FarmTone.caution => colors.sun,
      FarmTone.fault => colors.alert,
    };

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Haptics.selection();
              onOpenWeather();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                if (current != null)
                  WeatherIcon(
                    condition: current.condition,
                    isDay: current.isDay,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 20,
                    color: colors.inkTertiary,
                  ),
                const SizedBox(width: Tokens.space2),
                Flexible(
                  child: Text(
                    current == null
                        ? 'Weather unavailable'
                        : '${current.temperatureC.round()}°C · '
                              '${weather!.locationName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Tokens.space3),
        StatusPill(
          label: statusLabel,
          color: accent,
          glowing: tone == FarmTone.working,
        ),
      ],
    );
  }
}

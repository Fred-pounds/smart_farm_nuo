import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/alert_builder.dart';
import '../models/alert.dart';
import '../providers/farm_provider.dart';
import '../providers/history_provider.dart';
import '../providers/planting_provider.dart';
import '../providers/weather_provider.dart';
import '../widgets/alert_widgets.dart';
import '../theme/theme.dart';

/// Full alert list. Alerts are recomputed from live state on every rebuild,
/// so resolving the underlying condition clears the entry automatically.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final weather = context.watch<WeatherProvider>();
    final history = context.watch<HistoryProvider>();
    final plantings = context.watch<PlantingProvider>();

    final alerts = AlertBuilder.build(
      farm: farm.data,
      isConnected: farm.isConnected,
      weather: weather.report,
      history: history.readings,
      tasks: plantings.tasks,
      command: farm.command,
    );

    return GlassScaffold(
      title: 'Alerts',
      subtitle: alerts.isEmpty
          ? 'Nothing needs attention'
          : '${alerts.length} active',
      insideShell: false,
      builder: (context, contentPadding) {
        if (alerts.isEmpty) {
          return ListView(
            padding: contentPadding,
            children: [
              EmptyState(
                art: FarmArt.farmScene,
                title: 'Everything looks good',
                message:
                    'No soil, pump, sensor or weather problems detected right '
                    'now. Alerts appear here the moment a condition is met.',
              ),
            ],
          );
        }

        return ListView.separated(
          padding: contentPadding,
          itemCount: alerts.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space3),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return AlertTile(
              alert: alert,
              onAction: _actionFor(context, alert, farm),
            );
          },
        );
      },
    );
  }

  /// Wires the alert's inline remedy to the matching provider call.
  VoidCallback? _actionFor(
    BuildContext context,
    FarmAlert alert,
    FarmProvider farm,
  ) {
    return switch (alert.id) {
      'pump_stuck' => () async {
        await farm.setMode('manual');
        await farm.requestPump(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              // Deliberately describes what was sent, not what happened:
              // the pump is off only once the controller says so.
              content: Text(
                'Switched to manual mode and sent a stop command — '
                'watch the pump card for confirmation',
              ),
            ),
          );
        }
      },
      'soil_dry' when !farm.data.isAutomatic => () => farm.requestPump(true),
      _ => null,
    };
  }
}

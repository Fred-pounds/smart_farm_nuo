import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/alert_builder.dart';
import '../logic/farm_brief.dart';
import '../providers/assistant_provider.dart';
import '../providers/farm_profile_provider.dart';
import '../providers/planting_provider.dart';
import '../providers/farm_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import 'crops_screen.dart';
import 'dashboard_screen.dart';
import 'diagnose_screen.dart';
import 'tasks_screen.dart';
import 'weather_screen.dart';
import '../theme/theme.dart';
import '../widgets/field_action_bar.dart';

/// Bottom-navigation shell. Keeps every tab alive via [IndexedStack] so the
/// weather forecast and diagnosis results survive tab switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Wire the cross-provider side effects once the first frame is up:
    // sensor readings feed the history log, and the configured pump flow
    // rate feeds the litre estimates.
    WidgetsBinding.instance.addPostFrameCallback((_) => _wireProviders());
  }

  void _wireProviders() {
    if (!mounted) return;
    final farm = context.read<FarmProvider>();
    final history = context.read<HistoryProvider>();
    final settings = context.read<SettingsProvider>();

    final weather = context.read<WeatherProvider>();
    final profile = context.read<FarmProfileProvider>();
    final plantings = context.read<PlantingProvider>();
    final assistant = context.read<AssistantProvider>();

    void syncFarm() => history.onFarmData(farm.data);
    void syncFlow() => history.setPumpFlow(settings.pumpFlowLpm);

    // The controller cannot reach a weather service, so the app is the only
    // thing that can tell it rain is coming. Without this, the third layer of
    // the irrigation decision never fires.
    void publishWeather() => farm.publishRainOutlook(weather.report);

    // The assistant reaches the pump through exactly one path: the same
    // requestPump the on-screen button uses. It is handed a reporter for the
    // real outcome, so it can never infer success from having asked.
    assistant.attach(
      pumpCommander: (start) async {
        await farm.requestPump(start);
        return PumpOutcome.describe(
          requestedStart: start,
          command: farm.command,
          farm: farm.data,
        );
      },
      farmState: () => FarmBrief.build(
        profile: profile.profile,
        farm: farm.data,
        isConnected: farm.isConnected,
        command: farm.command,
        weather: weather.report,
        alerts: AlertBuilder.build(
          farm: farm.data,
          isConnected: farm.isConnected,
          weather: weather.report,
          history: history.readings,
          tasks: plantings.tasks,
          command: farm.command,
        ),
        history: history.readings,
      ),
    );

    farm.addListener(syncFarm);
    settings.addListener(syncFlow);
    weather.addListener(publishWeather);
    syncFarm();
    syncFlow();
    publishWeather();
  }

  void _onTabSelected(int index) {
    if (index != _index) Haptics.selection();
    setState(() => _index = index);
    // The forecast is only refreshed when the user actually looks at it.
    if (index == 1) {
      context.read<WeatherProvider>().refreshIfStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: Scaffold(
        // Content runs beneath the navigation bar so the glass has something
        // moving under it. Glass over an empty gutter is just a grey strip.
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onOpenTab: _onTabSelected),
            const WeatherScreen(),
            const CropsScreen(),
            const DiagnoseScreen(),
            const TasksScreen(),
          ],
        ),
        bottomNavigationBar: _GlassNavBar(
          index: _index,
          onSelected: _onTabSelected,
        ),
      ),
    );
  }
}

/// The navigation bar, floating on glass.
///
/// One of only two blurred surfaces in the app — see [GlassSurface] for why
/// that count is kept deliberately low.
class _GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;

  const _GlassNavBar({required this.index, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return GlassSurface(
      strong: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.glassBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The pump sits directly above the tabs, in the thumb zone — a
            // farmer should never have to navigate to stop water.
            if (index == 0) ...[
              const SizedBox(height: Tokens.space2),
              const FieldActionNote(),
              const FieldActionBar(),
            ],
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onSelected,
              // Rounded icon family throughout, outlined at rest and filled
              // when selected. The weight change carries the selection as
              // well as the indicator does, which keeps the bar readable for
              // anyone who cannot separate the tint from the background.
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Farm',
                ),
                NavigationDestination(
                  icon: Icon(Icons.wb_cloudy_outlined),
                  selectedIcon: Icon(Icons.cloud_rounded),
                  label: 'Weather',
                ),
                NavigationDestination(
                  icon: Icon(Icons.eco_outlined),
                  selectedIcon: Icon(Icons.eco_rounded),
                  label: 'Crops',
                ),
                NavigationDestination(
                  icon: Icon(Icons.center_focus_weak_rounded),
                  selectedIcon: Icon(Icons.center_focus_strong_rounded),
                  label: 'Diagnose',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note_rounded),
                  label: 'Tasks',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

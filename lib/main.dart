import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/assistant_provider.dart';
import 'providers/farm_profile_provider.dart';
import 'providers/farm_provider.dart';
import 'providers/history_provider.dart';
import 'providers/planting_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/farm_setup_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartFarmApp());
}

class SmartFarmApp extends StatelessWidget {
  const SmartFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => FarmProfileProvider()),
        ChangeNotifierProvider(create: (_) => FarmProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => PlantingProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Smart Farm',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const _Root(),
          );
        },
      ),
    );
  }
}

/// Sends a farmer who has not set up their farm to setup first.
///
/// The location decides what forecast is fetched, and therefore whether the
/// controller ever holds irrigation back for rain. Reaching the dashboard
/// without it means the third layer of the irrigation decision is silently
/// pointed at a default town.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<FarmProfileProvider>();

    if (!profile.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (profile.needsSetup) {
      return const FarmSetupScreen(isOnboarding: true);
    }

    return const HomeShell();
  }
}

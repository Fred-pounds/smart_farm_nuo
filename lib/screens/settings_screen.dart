import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/farm_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/farm_profile_provider.dart';
import '../widgets/farm_header.dart';
import 'farm_setup_screen.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Settings',
      insideShell: false,
      builder: (context, contentPadding) => ListView(
        padding: contentPadding,
        children: const [
          _YouSection(),
          SizedBox(height: 12),
          _FarmSection(),
          SizedBox(height: 12),
          _IrrigationSection(),
          SizedBox(height: 12),
          _ThresholdSection(),
          SizedBox(height: 12),
          _AppearanceSection(),
          SizedBox(height: 12),
          _DataSection(),
          SizedBox(height: 12),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.muted),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Who the dashboard greets.
///
/// Separate from the Farm section below, and deliberately first: the farm has
/// a name, a location and an area, and a person's name is none of those. It is
/// stored on the device rather than in the farm's record, so two people
/// sharing one farm do not have to agree on a first name.
class _YouSection extends StatefulWidget {
  const _YouSection();

  @override
  State<_YouSection> createState() => _YouSectionState();
}

class _YouSectionState extends State<_YouSection> {
  TextEditingController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = context.farmColors;

    // Built once the stored value has actually loaded, so the field is not
    // seeded with an empty string and then fight the user for the cursor.
    _controller ??= TextEditingController(text: settings.farmerName);

    return _Section(
      title: 'You',
      icon: Icons.person_outline_rounded,
      children: [
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'Leave empty to greet the farm instead',
          ),
          onChanged: (value) =>
              context.read<SettingsProvider>().setFarmerName(value),
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          settings.farmerName.isEmpty
              ? 'The dashboard will greet you with your farm\'s name.'
              : 'The dashboard greets you as '
                    '"${FarmHeader.greetingFor(DateTime.now())}, '
                    '${settings.farmerName}".',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
      ],
    );
  }
}

/// The farm's identity, and the way into editing it.
///
/// Name and location live in one place — the setup screen — so there is never
/// a second, competing answer to "where is my farm".
class _FarmSection extends StatelessWidget {
  const _FarmSection();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<FarmProfileProvider>().profile;
    final colors = context.farmColors;

    return _Section(
      title: 'Farm',
      icon: Icons.agriculture_outlined,
      children: [
        Panel(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space4,
            vertical: Tokens.space3,
          ),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FarmSetupScreen())),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.isConfigured ? profile.name : 'Name your farm',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.location.name} · ${profile.areaLabel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.inkTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IrrigationSection extends StatelessWidget {
  const _IrrigationSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colors = context.farmColors;

    return _Section(
      title: 'Irrigation setup',
      icon: Icons.water_drop_outlined,
      children: [
        _SliderRow(
          label: 'Pump flow rate',
          value: settings.pumpFlowLpm,
          min: 1,
          max: 60,
          divisions: 59,
          display: '${settings.pumpFlowLpm.round()} L/min',
          onChanged: settings.setPumpFlowLpm,
        ),
        Text(
          'Turns pump runtime into litres on the dashboard. Check your pump\'s '
          'rating plate, or time how long it takes to fill a 20 L bucket.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
        const SizedBox(height: Tokens.space5),
        _SliderRow(
          label: 'Default field area',
          value: settings.fieldAreaSqm,
          min: 10,
          max: 2000,
          divisions: 199,
          display: '${settings.fieldAreaSqm.round()} m²',
          onChanged: settings.setFieldAreaSqm,
        ),
        Text(
          'Used for water-saving estimates when you have not logged any '
          'plantings. Logged plantings override this.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
      ],
    );
  }
}

/// Direct control of the ESP32 dry threshold, with a calibration explainer.
class _ThresholdSection extends StatefulWidget {
  const _ThresholdSection();

  @override
  State<_ThresholdSection> createState() => _ThresholdSectionState();
}

class _ThresholdSectionState extends State<_ThresholdSection> {
  double? _pending;

  @override
  Widget build(BuildContext context) {
    final farm = context.watch<FarmProvider>();
    final colors = context.farmColors;
    final value = _pending ?? farm.data.threshold.toDouble();

    return _Section(
      title: 'Dry threshold',
      icon: Icons.tune_rounded,
      children: [
        Row(
          children: [
            Text(
              'Current reading: ${farm.data.soilMoisture}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
            ),
            const Spacer(),
            Text(
              value.round().toString(),
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(
                fontSize: 18,
                color: colors.soilDry,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(500.0, 3500.0),
          min: 500,
          max: 3500,
          divisions: 60,
          onChanged: (v) => setState(() => _pending = v),
          onChangeEnd: (v) async {
            await farm.setThreshold(v.round());
            if (mounted) setState(() => _pending = null);
          },
        ),
        Text(
          'The sensor reads higher as the soil gets drier. The pump triggers '
          'once the reading passes this threshold. To calibrate: note the '
          'reading in well-watered soil and again when the crop needs water, '
          'then set the threshold between them.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            Text(
              display,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFeatures: Tokens.tabular,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return _Section(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.darkMode,
          onChanged: settings.setDarkMode,
          title: Text('Dark mode', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text(
            'Easier on the eyes for early-morning field checks',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final colors = context.farmColors;

    return _Section(
      title: 'Sensor history',
      icon: Icons.storage_outlined,
      children: [
        Text(
          '${history.readings.length} readings stored in Firebase under '
          '/farm/history. Samples are logged every 10 minutes while the app is '
          'open, and pruned after 7 days.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.inkTertiary),
        ),
        const SizedBox(height: Tokens.space4),
        OutlinedButton.icon(
          onPressed: history.readings.isEmpty
              ? null
              : () => _confirmClear(context, history),
          icon: const Icon(Icons.delete_outline_rounded, size: 17),
          label: const Text('Clear history'),
          style: OutlinedButton.styleFrom(foregroundColor: colors.danger),
        ),
      ],
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryProvider history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear sensor history?'),
        content: const Text(
          'This permanently deletes all logged readings from Firebase. Your '
          'trend charts and water-usage figures will restart from empty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) await history.clearHistory();
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return _Section(
      title: 'About',
      icon: Icons.info_outline_rounded,
      children: [
        Text(
          'Smart Farm pairs an ESP32 soil-moisture controller with weather '
          'forecasting, crop recommendations and on-device disease detection.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Tokens.space3),
        Text(
          'Weather by Open-Meteo · Disease model runs on-device · Farm state '
          'synced through Firebase Realtime Database',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            color: colors.inkTertiary,
          ),
        ),
      ],
    );
  }
}

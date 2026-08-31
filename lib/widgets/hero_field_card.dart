import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/farm_data.dart';
import '../providers/farm_provider.dart';
import '../theme/theme.dart';

/// The dashboard's hero: the soil reading, the pump, and who is in charge.
///
/// The one raised panel on the screen. Everything below it qualifies what it
/// says, so it gets the deeper shadow and the only gauge in the app.
///
/// ## What is deliberately *not* here
///
/// The start/stop control. The pump lives in the thumb zone above the
/// navigation bar (`FieldActionBar`), because it is the control a farmer
/// reaches for one-handed while standing in a field — and because two ways to
/// start the same pump, on the same screen, raises the question of which one
/// the controller actually heard. This card carries the mode switch, which
/// decides *who* commands the pump, and reports the state the controller
/// measured.
class HeroFieldCard extends StatelessWidget {
  const HeroFieldCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final data = provider.data;
    final colors = context.farmColors;

    return Panel(
      raised: true,
      padding: const EdgeInsets.fromLTRB(
        Tokens.space5,
        Tokens.space6,
        Tokens.space5,
        Tokens.space5,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Eyebrow('Soil moisture'),
              const SizedBox(width: Tokens.space2),
              if (!provider.isConnected)
                Icon(
                  Icons.cloud_off_rounded,
                  size: 14,
                  color: colors.inkTertiary,
                ),
            ],
          ),
          const SizedBox(height: Tokens.space5),
          MoistureGauge(
            raw: data.soilMoisture,
            threshold: data.threshold,
            isPlausible: data.hasPlausibleSoil,
            // Driven by pumpStatus — the state the controller reported — and
            // never by a command the app has merely sent.
            irrigating: data.pumpStatus,
          ),
          const SizedBox(height: Tokens.space6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _PumpState(data: data)),
              Container(
                width: 1,
                height: 40,
                color: colors.panelBorder,
                margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              ),
              Expanded(
                child: _ModeSwitch(
                  isAutomatic: data.isAutomatic,
                  onChanged: (auto) {
                    Haptics.commandSent();
                    provider.setMode(auto ? 'automatic' : 'manual');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pump as the controller reports it — never as the app requested it.
class _PumpState extends StatelessWidget {
  final FarmData data;

  const _PumpState({required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;
    final running = data.pumpStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Pump'),
        const SizedBox(height: Tokens.space2),
        Row(
          children: [
            AnimatedContainer(
              duration: Tokens.motionBase,
              curve: Tokens.curveData,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: running ? colors.water : colors.inkTertiary,
                shape: BoxShape.circle,
                boxShadow: running
                    ? [
                        BoxShadow(
                          color: colors.water.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: Tokens.space2),
            Text(
              running ? 'Watering' : 'Idle',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: running ? colors.water : colors.inkPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A two-position segmented control for who commands the pump.
///
/// Both options stay visible and labelled. A single switch would leave the
/// farmer working out which end is automatic, and this decides whether the
/// controller or the person is watering the field.
class _ModeSwitch extends StatelessWidget {
  final bool isAutomatic;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.isAutomatic, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Mode'),
        const SizedBox(height: Tokens.space2),
        Container(
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.panelMuted,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Row(
            children: [
              _Segment(
                label: 'Auto',
                selected: isAutomatic,
                accent: colors.growth,
                onTap: () => onChanged(true),
              ),
              _Segment(
                label: 'Manual',
                selected: !isAutomatic,
                accent: colors.sun,
                onTap: () => onChanged(false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.farmColors;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: selected ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: Tokens.motionFast,
            curve: Tokens.curveStandard,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.panel : Colors.transparent,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              boxShadow: selected
                  ? Tokens.restingShadow(colors.panelShadow)
                  : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 11.5,
                color: selected ? accent : colors.inkTertiary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontVariations: [FontVariation('wght', selected ? 700 : 600)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

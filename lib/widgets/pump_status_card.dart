import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';

class PumpStatusCard extends StatelessWidget {
  const PumpStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pumpOn = context.watch<FarmProvider>().data.pumpStatus;

    final color = pumpOn ? Colors.blue : Colors.grey.shade400;
    final label = pumpOn ? 'Pump ON' : 'Pump OFF';
    final icon = pumpOn ? Icons.water_drop : Icons.water_drop_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Actual Pump Status',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Reported by ESP32',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade400,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: pumpOn ? Colors.blue : Colors.grey.shade300,
                shape: BoxShape.circle,
                boxShadow: pumpOn
                    ? [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

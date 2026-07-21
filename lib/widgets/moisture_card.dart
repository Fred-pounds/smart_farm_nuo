import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';

class MoistureCard extends StatelessWidget {
  const MoistureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<FarmProvider>().data;
    final isDry = data.isDry;

    // Clamp ratio for the progress bar: 0 (very wet) → 1 (very dry)
    // Higher raw value = drier soil
    final ratio = (data.soilMoisture / (data.threshold * 2)).clamp(0.0, 1.0);

    final statusColor = isDry ? Colors.orange : Colors.teal;
    final statusLabel = isDry ? 'Dry' : 'Wet';
    final statusIcon = isDry ? Icons.wb_sunny_outlined : Icons.water_outlined;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grass_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Soil Moisture',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ValueTile(
                  label: 'Raw Value',
                  value: '${data.soilMoisture}',
                  color: statusColor,
                ),
                _ValueTile(
                  label: 'Threshold',
                  value: '${data.threshold}',
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Wet',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text(
                  'Dry',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.teal.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                isDry
                    ? 'Soil is dry — pump may activate'
                    : 'Soil is moist — no watering needed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValueTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

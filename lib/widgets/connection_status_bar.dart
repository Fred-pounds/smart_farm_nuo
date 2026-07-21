import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';

class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();

    Color color;
    IconData icon;
    String label;

    switch (provider.connection) {
      case FarmConnectionState.connecting:
        color = Colors.orange;
        icon = Icons.cloud_sync_outlined;
        label = 'Connecting to Firebase…';
      case FarmConnectionState.connected:
        color = Colors.green;
        icon = Icons.cloud_done_outlined;
        label = 'Live — Firebase Connected';
      case FarmConnectionState.error:
        color = Colors.red;
        icon = Icons.cloud_off_outlined;
        label = provider.errorMessage ?? 'Connection error';
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (provider.connection == FarmConnectionState.connecting)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

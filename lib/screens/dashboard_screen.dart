import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/mode_selector_widget.dart';
import '../widgets/pump_status_card.dart';
import '../widgets/pump_control_card.dart';
import '../widgets/moisture_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(mode: provider.data.mode),
            const ConnectionStatusBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  ModeSelectorWidget(),
                  SizedBox(height: 12),
                  PumpStatusCard(),
                  SizedBox(height: 12),
                  PumpControlCard(),
                  SizedBox(height: 12),
                  MoistureCard(),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  final String mode;

  const _AppHeader({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Color(0xFF2E7D32),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Smart Farm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Irrigation Dashboard',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: mode == 'automatic'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              mode == 'automatic' ? 'AUTO' : 'MANUAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: mode == 'automatic' ? Colors.green : Colors.orange,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

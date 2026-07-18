import 'package:flutter/material.dart';

import 'account_test_screen.dart';
import 'game_test_screen.dart';
import 'telemetry_screen.dart';

/// Simple launcher between the backend-connectivity test tools built so far.
/// No product UI lives here yet — just picks which test harness to open.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trust Rummy — Dev Tools'), centerTitle: true),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GameTestScreen()),
                  ),
                  icon: const Icon(Icons.videogame_asset),
                  label: const Text('Game Engine + Lobby Connection Test'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountTestScreen()),
                  ),
                  icon: const Icon(Icons.account_circle),
                  label: const Text('Account, Wallet & History Test'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TelemetryScreen()),
                  ),
                  icon: const Icon(Icons.speed),
                  label: const Text('Live Telemetry (Phase 1)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

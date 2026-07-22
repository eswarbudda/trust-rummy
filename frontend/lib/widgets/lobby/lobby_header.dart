import 'package:flutter/material.dart';

import '../../lobby/lobby_controller.dart';

class LobbyHeader extends StatelessWidget {
  const LobbyHeader({
    super.key,
    required this.controller,
    required this.onSettings,
  });

  final LobbyController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final name = controller.username ?? 'Player';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Virtual credits',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
              ),
            ],
          ),
        ),
        WalletBalanceCard(balance: controller.walletBalance),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Settings',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({super.key, required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            balance.toStringAsFixed(balance.truncateToDouble() == balance ? 0 : 2),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

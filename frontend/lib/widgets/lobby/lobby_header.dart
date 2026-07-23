import 'package:flutter/material.dart';

import '../../config/ui_config.dart';
import '../../lobby/lobby_controller.dart';
import '../../theme/lobby_theme.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRUST RUMMY', style: LobbyText.label(size: 11, color: LobbyColors.feltBright)),
                  const SizedBox(height: 2),
                  Text('Hit the tables', style: LobbyText.brand(size: 34)),
                  const SizedBox(height: 4),
                  Text(
                    'Shuffle · Group · Show  ♣ ♦',
                    style: LobbyText.bodyMuted(size: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: onSettings,
              style: IconButton.styleFrom(
                backgroundColor: LobbyColors.inkSoft.withValues(alpha: 0.8),
                foregroundColor: LobbyColors.chipYellow,
                side: BorderSide(color: LobbyColors.chipYellow.withValues(alpha: 0.45)),
              ),
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LobbyPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderColor: LobbyColors.feltBright.withValues(alpha: 0.45),
          gradient: LinearGradient(
            colors: [
              LobbyColors.felt.withValues(alpha: 0.45),
              LobbyColors.inkSoft.withValues(alpha: 0.92),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: LobbyColors.cream,
                  border: Border.all(color: LobbyColors.cardRed, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: LobbyColors.cardRed.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  initial,
                  style: LobbyText.brand(size: 24, color: LobbyColors.cardRed),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: LobbyText.body(size: 17, weight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Your seat is warm ♥', style: LobbyText.bodyMuted(size: 12)),
                  ],
                ),
              ),
              WalletBalanceCard(balance: controller.walletBalance),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: LobbyColors.chipYellow,
        boxShadow: [
          BoxShadow(
            color: LobbyColors.chipYellow.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            UiConfig.formatMoney(balance),
            style: LobbyText.body(size: 15, weight: FontWeight.w800, color: LobbyColors.ink),
          ),
        ],
      ),
    );
  }
}

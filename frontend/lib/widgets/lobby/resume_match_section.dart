import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../theme/lobby_theme.dart';

class ResumeMatchSection extends StatelessWidget {
  const ResumeMatchSection({
    super.key,
    required this.info,
    required this.onResume,
  });

  final ResumeMatchInfo info;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return LobbyPanel(
      borderColor: LobbyColors.jokerOrange.withValues(alpha: 0.65),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LobbyColors.jokerOrange.withValues(alpha: 0.55),
          LobbyColors.cardRed.withValues(alpha: 0.35),
          LobbyColors.inkSoft.withValues(alpha: 0.92),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TABLE STILL OPEN', style: LobbyText.label(size: 11, color: LobbyColors.cream)),
          const SizedBox(height: 4),
          Text('Jump back in 🎲', style: LobbyText.section(size: 24)),
          const SizedBox(height: 8),
          Text(
            'Room ${info.roomCode} · ${LobbyVariants.labelFor(info.gameVariant)} · '
            '${info.playerCount}${info.maxPlayers != null ? "/${info.maxPlayers}" : ""} players · ${info.status}',
            style: LobbyText.bodyMuted(),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onResume,
            style: FilledButton.styleFrom(
              backgroundColor: LobbyColors.chipYellow,
              foregroundColor: LobbyColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              'Resume Match',
              style: LobbyText.body(size: 14, weight: FontWeight.w800, color: LobbyColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

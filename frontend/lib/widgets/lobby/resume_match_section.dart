import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';

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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
            Colors.teal.withValues(alpha: 0.28),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resume match',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Room ${info.roomCode} · ${LobbyVariants.labelFor(info.gameVariant)} · '
            '${info.playerCount}${info.maxPlayers != null ? "/${info.maxPlayers}" : ""} players · ${info.status}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume Match'),
          ),
        ],
      ),
    );
  }
}

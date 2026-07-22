import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../services/match_history_api_service.dart';

class RecentGamesSection extends StatelessWidget {
  const RecentGamesSection({
    super.key,
    required this.matches,
    required this.myUsername,
  });

  final List<MatchHistoryItem> matches;
  final String? myUsername;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Recent games',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (matches.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'No matches yet. Play a game to see results here.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...matches.map((m) {
            final when = m.endedAt ?? m.startedAt;
            final dateLabel = when == null
                ? '—'
                : '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
            final won = myUsername != null && m.winnerUsername == myUsername;
            final result = m.status == 'ABORTED'
                ? 'Aborted'
                : (won ? 'Won' : (m.status == 'COMPLETED' ? 'Lost' : m.status));
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  title: Text('$dateLabel · ${LobbyVariants.labelFor(m.gameVariant)}'),
                  subtitle: Text('$result · score ${m.myFinalScore ?? '—'} · ${m.roomCode}'),
                ),
              ),
            );
          }),
      ],
    );
  }
}

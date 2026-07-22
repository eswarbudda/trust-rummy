import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import 'countdown_widget.dart';

/// Final match summary — Play Again / Leave Table; no auto-start.
class MatchSummaryDialog extends StatelessWidget {
  final MatchEndedEvent result;
  final String? winnerName;
  final String? lastDealScoreLines;
  final Map<int, String>? playerNames;
  final int? selfUserId;
  final String? selfUsername;
  final List<PlayerView> opponents;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeaveTable;

  const MatchSummaryDialog({
    super.key,
    required this.result,
    this.winnerName,
    this.lastDealScoreLines,
    this.playerNames,
    this.selfUserId,
    this.selfUsername,
    this.opponents = const [],
    this.onPlayAgain,
    this.onLeaveTable,
  });

  @override
  Widget build(BuildContext context) {
    final winner = winnerName ??
        (result.winnerUserId != null ? 'Player ${result.winnerUserId}' : '—');
    final scores = result.finalScores.entries.map((e) {
      String? name = playerNames?[e.key];
      if (name == null && e.key == selfUserId) name = selfUsername;
      if (name == null) {
        for (final p in opponents) {
          if (p.userId == e.key) {
            name = p.username;
            break;
          }
        }
      }
      return MapEntry(name ?? 'Player ${e.key}', e.value);
    }).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return ResultOverlayShell(
      title: 'Match Result',
      children: [
        if (result.dealsPlayed != null) ...[
          Text(
            'Deals played: ${result.dealsPlayed}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Winner: $winner',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RummyColors.gold,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Final standings',
          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final row in scores)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.key, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
                Text(
                  '${row.value}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (lastDealScoreLines != null && lastDealScoreLines!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Last deal',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(lastDealScoreLines!, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onLeaveTable,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Leave Table'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onPlayAgain,
                style: FilledButton.styleFrom(
                  backgroundColor: RummyColors.showGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Play Again'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Play Again returns you to the lobby to start a new match. '
          'During a multi-deal match use Start Next Deal on the deal result screen.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
        ),
      ],
    );
  }
}

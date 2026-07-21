import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import 'countdown_widget.dart';

/// Between-deal result overlay — freeze gameplay; Start Next Deal / Leave Table.
class DealResultDialog extends StatelessWidget {
  final DealResultEvent result;
  final String? winnerName;
  final VoidCallback? onStartNextDeal;
  final VoidCallback? onLeaveTable;

  const DealResultDialog({
    super.key,
    required this.result,
    this.winnerName,
    this.onStartNextDeal,
    this.onLeaveTable,
  });

  @override
  Widget build(BuildContext context) {
    final winner = winnerName ??
        (result.winnerUserId != null ? 'Player ${result.winnerUserId}' : '—');
    final dealLabel = result.dealsPerMatch != null
        ? 'Deal ${result.dealNumber ?? result.dealsPlayed} of ${result.dealsPerMatch}'
        : 'Deal ${result.dealNumber ?? result.dealsPlayed}';

    return ResultOverlayShell(
      title: 'Deal Result',
      children: [
        Text(
          dealLabel,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
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
          'Deal points',
          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final row in result.scores)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.username, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ),
                Text(
                  row.roundPoints == 0 ? '0' : '+${row.roundPoints}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          'Match score',
          style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (final row in result.scores)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.username +
                        (row.matchPlayerStatus == RummyMatchPlayerStatus.eliminated ? ' (out)' : ''),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                Text(
                  '${row.cumulativeScore}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ],
            ),
          ),
        if (result.autoNextDealSeconds > 0) ...[
          const SizedBox(height: 16),
          CountdownWidget(initialSeconds: result.autoNextDealSeconds),
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
                onPressed: onStartNextDeal,
                style: FilledButton.styleFrom(
                  backgroundColor: RummyColors.showGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Start Next Deal'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

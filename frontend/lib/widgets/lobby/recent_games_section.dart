import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../services/match_history_api_service.dart';
import '../../theme/lobby_theme.dart';

class RecentGamesSection extends StatelessWidget {
  const RecentGamesSection({
    super.key,
    required this.matches,
    required this.myUsername,
    required this.page,
    required this.totalPages,
    required this.totalElements,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final List<MatchHistoryItem> matches;
  final String? myUsername;
  final int page;
  final int totalPages;
  final int totalElements;
  final bool loading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final hasPager = totalPages > 1 || totalElements > matches.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LobbySectionTitle('Your recent hands', eyebrow: 'Scoreboard'),
        const SizedBox(height: 14),
        if (matches.isEmpty && !loading)
          LobbyPanel(
            borderColor: LobbyColors.sapphire.withValues(alpha: 0.3),
            child: Text(
              'No matches yet. Play a game to see results here.',
              style: LobbyText.bodyMuted(),
            ),
          )
        else ...[
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: LobbyColors.chipYellow),
                ),
              ),
            ),
          ...matches.map((m) {
            final when = m.endedAt ?? m.startedAt;
            final dateLabel = when == null
                ? '—'
                : '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}';
            final won = myUsername != null && m.winnerUsername == myUsername;
            final result = m.status == 'ABORTED'
                ? 'Aborted'
                : (won ? 'Won' : (m.status == 'COMPLETED' ? 'Lost' : m.status));
            final resultColor = m.status == 'ABORTED'
                ? LobbyColors.creamMuted
                : (won ? LobbyColors.gold : LobbyColors.coral);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LobbyPanel(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                borderColor: resultColor.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: resultColor.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        result.toUpperCase(),
                        style: LobbyText.label(size: 12, color: resultColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dateLabel · ${LobbyVariants.labelFor(m.gameVariant)}',
                            style: LobbyText.body(size: 15, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Score ${m.myFinalScore ?? '—'} · ${m.roomCode}',
                            style: LobbyText.bodyMuted(size: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (hasPager || totalElements > 0) ...[
            const SizedBox(height: 4),
            LobbyPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              borderColor: LobbyColors.gold.withValues(alpha: 0.35),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: loading || onPrev == null ? null : onPrev,
                    style: IconButton.styleFrom(
                      foregroundColor: LobbyColors.gold,
                      disabledForegroundColor: LobbyColors.creamMuted.withValues(alpha: 0.35),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      totalPages <= 0
                          ? '${matches.length} hands'
                          : 'Page ${page + 1} of $totalPages · $totalElements hands',
                      textAlign: TextAlign.center,
                      style: LobbyText.bodyMuted(size: 14),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: loading || onNext == null ? null : onNext,
                    style: IconButton.styleFrom(
                      foregroundColor: LobbyColors.gold,
                      disabledForegroundColor: LobbyColors.creamMuted.withValues(alpha: 0.35),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

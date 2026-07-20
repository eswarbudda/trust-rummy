import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';
import 'hand_view.dart';
import 'rummy_action_bar.dart';
import 'rummy_table_board.dart';

/// High-level presentation modes for the production table chrome.
///
/// Networking and game-state ownership stay outside this widget — parents
/// map connection / match lifecycle into [mode] and pass board props.
enum RummyGameUiMode {
  waiting,
  active,
  completed,
  disconnected,
}

/// Pure presentation shell for the rummy table: header, status banner,
/// [RummyTableBoard], selection tools, footer actions, and optional
/// post-match result overlay.
///
/// No networking, no services, no mutable game state.
class RummyGameView extends StatelessWidget {
  final RummyGameUiMode mode;
  final String headerLabel;
  final RummyLayout layout;

  final List<PlayerView> opponents;
  final PlayerView me;
  final List<rummy.Card> hand;
  final rummy.Value? wildValue;
  final rummy.Card? cutJokerCard;
  final int closedDeckCount;
  final List<rummy.Card>? discardPile;
  final rummy.Card? discardTop;
  final rummy.Card? finishSlotCard;
  final RummyTurnPhase? phase;
  final int? currentTurnUserId;
  final int? turnSecondsRemaining;
  final int? selectedIndex;
  final Set<int> groupBreaksAfterIndex;
  final DeclareResultEvent? declareResult;
  final String? declareResultName;
  final bool isMyTurn;
  final bool canDiscardSelected;

  /// When non-null and [mode] is [RummyGameUiMode.completed], shows the
  /// Points-Rummy result overlay (summary + Play Again / Leave Table).
  final MatchEndedEvent? matchResult;
  final String? matchWinnerName;
  final String? lastDealScoreLines;
  /// Optional userId → username map for the result overlay score rows.
  final Map<int, String>? playerNames;
  final VoidCallback? onPlayAgain;
  final VoidCallback? onLeaveTable;

  /// Mockup-only extras (wallet chip, phase switch). Production leaves null.
  final Widget? headerTrailing;
  final Widget? belowHeader;

  final VoidCallback? onExit;
  final VoidCallback? onCloseDeclareResult;
  final void Function(int index, rummy.Card card)? onCardTap;
  final void Function(int index)? onToggleGroupBreak;
  final void Function(int fromIndex, int toIndex)? onMoveCard;
  final void Function(int fromIndex, int gapAfterIndex)? onMoveIntoGap;
  final void Function(bool fromClosed)? onAcceptFromPile;
  final VoidCallback? onDrawClosed;
  final VoidCallback? onDrawOpen;
  final ValueChanged<HandDragPayload>? onDiscardDrop;
  final ValueChanged<HandDragPayload>? onFinishDrop;
  final VoidCallback? onDrop;
  final VoidCallback? onDeclare;
  final VoidCallback? onNudgeLeft;
  final VoidCallback? onNudgeRight;
  final VoidCallback? onToggleSplit;
  final VoidCallback? onDiscardSelected;

  const RummyGameView({
    super.key,
    required this.mode,
    required this.headerLabel,
    required this.opponents,
    required this.me,
    required this.hand,
    required this.wildValue,
    required this.closedDeckCount,
    this.layout = RummyLayout.standard,
    this.cutJokerCard,
    this.discardPile,
    this.discardTop,
    this.finishSlotCard,
    this.phase,
    this.currentTurnUserId,
    this.turnSecondsRemaining,
    this.selectedIndex,
    this.groupBreaksAfterIndex = const {},
    this.declareResult,
    this.declareResultName,
    this.isMyTurn = false,
    this.canDiscardSelected = false,
    this.matchResult,
    this.matchWinnerName,
    this.lastDealScoreLines,
    this.playerNames,
    this.onPlayAgain,
    this.onLeaveTable,
    this.headerTrailing,
    this.belowHeader,
    this.onExit,
    this.onCloseDeclareResult,
    this.onCardTap,
    this.onToggleGroupBreak,
    this.onMoveCard,
    this.onMoveIntoGap,
    this.onAcceptFromPile,
    this.onDrawClosed,
    this.onDrawOpen,
    this.onDiscardDrop,
    this.onFinishDrop,
    this.onDrop,
    this.onDeclare,
    this.onNudgeLeft,
    this.onNudgeRight,
    this.onToggleSplit,
    this.onDiscardSelected,
  });

  bool get _connected => mode != RummyGameUiMode.disconnected;

  String? get _statusBanner {
    switch (mode) {
      case RummyGameUiMode.waiting:
        return 'Waiting for DEAL_STARTED…';
      case RummyGameUiMode.disconnected:
        return 'Disconnected — check your connection';
      case RummyGameUiMode.completed:
        return null; // result overlay owns this state
      case RummyGameUiMode.active:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RummyColors.boardGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  if (belowHeader != null) belowHeader!,
                  if (_statusBanner != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        _statusBanner!,
                        style: TextStyle(
                          color: mode == RummyGameUiMode.disconnected
                              ? RummyColors.danger.withOpacity(0.85)
                              : Colors.white.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Expanded(
                    child: RummyTableBoard(
                      opponents: opponents,
                      me: me,
                      hand: hand,
                      wildValue: wildValue,
                      cutJokerCard: cutJokerCard,
                      closedDeckCount: closedDeckCount,
                      discardPile: discardPile,
                      discardTop: discardTop,
                      finishSlotCard: finishSlotCard,
                      phase: phase,
                      currentTurnUserId: currentTurnUserId,
                      turnSecondsRemaining: turnSecondsRemaining,
                      layout: layout,
                      selectedIndex: selectedIndex,
                      groupBreaksAfterIndex: groupBreaksAfterIndex,
                      declareResult: declareResult,
                      declareResultName: declareResultName,
                      onCloseDeclareResult: onCloseDeclareResult,
                      onCardTap: onCardTap,
                      onToggleGroupBreak: onToggleGroupBreak,
                      onMoveCard: onMoveCard,
                      onMoveIntoGap: onMoveIntoGap,
                      onAcceptFromPile: onAcceptFromPile,
                      onDrawClosed: onDrawClosed,
                      onDrawOpen: onDrawOpen,
                      onDiscardDrop: onDiscardDrop,
                      onFinishDrop: onFinishDrop,
                      selectionTools: selectedIndex != null ? _selectedCardTools() : null,
                    ),
                  ),
                  _footerActions(),
                ],
              ),
              if (mode == RummyGameUiMode.completed && matchResult != null) _matchResultOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 4),
      child: Row(
        children: [
          Material(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: mode == RummyGameUiMode.completed ? onLeaveTable : onExit,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'EXIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: RummyColors.headerPill.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      headerLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.signal_cellular_alt,
                    color: _connected ? RummyColors.success : RummyColors.danger,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          if (headerTrailing != null) ...[
            const SizedBox(width: 8),
            headerTrailing!,
          ],
        ],
      ),
    );
  }

  /// SCORE · DROP · SHOW — spaced for touch, never cramped against seat tools.
  Widget _footerActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Text(
            'SCORE: ${me.cumulativeScore}',
            style: TextStyle(
              color: RummyColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 13 * layout.scale.clamp(0.9, 1.2),
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          RummyActionBar(
            isMyTurn: isMyTurn,
            phase: phase,
            onDrop: onDrop,
            onDeclare: onDeclare,
          ),
        ],
      ),
    );
  }

  Widget _selectedCardTools() {
    final i = selectedIndex!;
    final canLeft = i > 0;
    final canRight = i < hand.length - 1;
    final splitActive = i < hand.length - 1 && groupBreaksAfterIndex.contains(i);
    final gap = 14 * layout.scale;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolChip(
            icon: Icons.chevron_left_rounded,
            label: 'Left',
            enabled: canLeft,
            onTap: canLeft ? onNudgeLeft : null,
          ),
          SizedBox(width: gap),
          _toolChip(
            icon: Icons.view_column_rounded,
            label: splitActive ? 'Ungroup' : 'Create Group',
            enabled: canRight,
            active: splitActive,
            onTap: canRight ? onToggleSplit : null,
          ),
          SizedBox(width: gap),
          _toolChip(
            icon: Icons.chevron_right_rounded,
            label: 'Right',
            enabled: canRight,
            onTap: canRight ? onNudgeRight : null,
          ),
          if (canDiscardSelected) ...[
            SizedBox(width: gap),
            _toolChip(
              icon: Icons.upload_rounded,
              label: 'Discard',
              enabled: true,
              onTap: onDiscardSelected,
            ),
          ],
        ],
      ),
    );
  }

  Widget _toolChip({
    required IconData icon,
    required String label,
    required bool enabled,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: active ? RummyColors.gold.withOpacity(0.25) : Colors.white.withOpacity(enabled ? 0.1 : 0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14 * layout.scale, vertical: 9 * layout.scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: enabled ? (active ? RummyColors.gold : Colors.white) : Colors.white30),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? (active ? RummyColors.gold : Colors.white70) : Colors.white30,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// In-tree post-game UI — same on every client; no Navigator dialog races.
  Widget _matchResultOverlay() {
    final ended = matchResult!;
    final winner = matchWinnerName ?? (ended.winnerUserId != null ? 'Player ${ended.winnerUserId}' : '—');
    final scores = ended.finalScores.entries.map((e) {
      String? name = playerNames?[e.key];
      if (name == null && e.key == me.userId) name = me.username;
      if (name == null) {
        for (final p in opponents) {
          if (p.userId == e.key) {
            name = p.username;
            break;
          }
        }
      }
      return MapEntry(name ?? 'Player ${e.key}', e.value);
    }).toList();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: RummyColors.panelBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: RummyColors.gold.withOpacity(0.45), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Match Result',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          letterSpacing: 0.4,
                        ),
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
                        'Final scores',
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
                        'Play Again returns you to the lobby to start a new match.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

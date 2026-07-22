import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';
import '../common/screen_background.dart';
import 'deal_result_dialog.dart';
import 'declare_result_panel.dart';
import 'hand_view.dart';
import 'match_summary_dialog.dart';
import 'rummy_action_bar.dart';
import 'rummy_table_board.dart';

/// High-level presentation modes for the production table chrome.
///
/// Networking and game-state ownership stay outside this widget — parents
/// map connection / match lifecycle into [mode] and pass board props.
enum RummyGameUiMode {
  waiting,
  active,
  dealResult,
  completed,
  disconnected,
}

/// Pure presentation shell for the rummy table.
///
/// Zone Column (top → bottom):
/// Header → Table Area (felt + seats + piles + hand) → Bottom Lane
/// (DRAW/DISCARD · group controls · DROP/SHOW, centered Option C).
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
  /// match summary overlay.
  final MatchEndedEvent? matchResult;
  final String? matchWinnerName;
  final String? lastDealScoreLines;
  /// Optional userId → username map for the result overlay score rows.
  final Map<int, String>? playerNames;

  /// Between-deal result ([RummyGameUiMode.dealResult]).
  final DealResultEvent? dealResult;
  final String? dealWinnerName;
  final VoidCallback? onStartNextDeal;

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
    this.dealResult,
    this.dealWinnerName,
    this.onStartNextDeal,
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
      case RummyGameUiMode.dealResult:
        return null; // result overlay owns this state
      case RummyGameUiMode.active:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final L = layout;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground.board(
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: L.headerMinHeight,
                    width: double.infinity,
                    child: _topBar(),
                  ),
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
                  // Table Area — felt + all seats + piles + hand.
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
                      // Declare panel is rendered above deal/match overlays
                      // so a wrong show stays visible until dismissed.
                      onCardTap: onCardTap,
                      onToggleGroupBreak: onToggleGroupBreak,
                      onMoveCard: onMoveCard,
                      onMoveIntoGap: onMoveIntoGap,
                      onAcceptFromPile: onAcceptFromPile,
                      onDrawClosed: onDrawClosed,
                      onDrawOpen: onDrawOpen,
                      onDiscardDrop: onDiscardDrop,
                      onFinishDrop: onFinishDrop,
                    ),
                  ),
                  // Bottom lane — DRAW/DISCARD (left) · group tools · DROP/SHOW (right).
                  SizedBox(
                    height: L.bottomLaneHeight,
                    width: double.infinity,
                    child: _bottomLane(),
                  ),
                ],
              ),
              if (mode == RummyGameUiMode.dealResult && dealResult != null)
                DealResultDialog(
                  result: dealResult!,
                  winnerName: dealWinnerName,
                  onStartNextDeal: onStartNextDeal,
                  onLeaveTable: onLeaveTable,
                ),
              if (mode == RummyGameUiMode.completed && matchResult != null)
                MatchSummaryDialog(
                  result: matchResult!,
                  winnerName: matchWinnerName,
                  lastDealScoreLines: lastDealScoreLines,
                  playerNames: playerNames,
                  selfUserId: me.userId,
                  selfUsername: me.username,
                  opponents: opponents,
                  onPlayAgain: onPlayAgain,
                  onLeaveTable: onLeaveTable,
                ),
              // Above deal/match overlays so everyone can inspect a wrong show
              // before continuing to scores.
              if (declareResult != null)
                DeclareResultPanel(
                  declarerName: declareResultName ?? 'Player',
                  result: declareResult!,
                  onClose: onCloseDeclareResult ?? () {},
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      child: Row(
        children: [
          Material(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: (mode == RummyGameUiMode.completed || mode == RummyGameUiMode.dealResult)
                  ? onLeaveTable
                  : onExit,
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

  Widget _bottomLane() {
    final L = layout;
    // Option C: pairs flank group tools near center (not pinned to screen edges).
    return Padding(
      padding: EdgeInsets.fromLTRB(
        L.bottomLaneSideInset,
        4 * L.scale,
        L.bottomLaneSideInset,
        6 * L.scale,
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: RummyActionBar.drawDiscard(
                isMyTurn: isMyTurn,
                phase: phase,
                layout: L,
                canDiscardSelected: canDiscardSelected && selectedIndex != null,
                onDraw: onDrawClosed,
                onDiscard: onDiscardSelected,
              ),
            ),
          ),
          SizedBox(width: L.bottomLaneActionToGroupGap),
          if (selectedIndex != null)
            Flexible(
              child: Center(child: _selectedCardTools()),
            )
          else
            SizedBox(width: L.bottomLaneCenterGap),
          SizedBox(width: L.bottomLaneActionToGroupGap),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: RummyActionBar.dropShow(
                isMyTurn: isMyTurn,
                phase: phase,
                layout: L,
                onDrop: onDrop,
                onDeclare: onDeclare,
              ),
            ),
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
    final gap = layout.groupControlGap;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
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
          padding: EdgeInsets.symmetric(horizontal: 12 * layout.scale, vertical: 8 * layout.scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: enabled ? (active ? RummyColors.gold : Colors.white) : Colors.white30),
              const SizedBox(width: 5),
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
}

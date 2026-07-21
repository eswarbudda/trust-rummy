import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../models/game_state.dart';
import '../../theme/rummy_layout.dart';
import 'card_piles_view.dart';
import 'declare_result_panel.dart';
import 'hand_view.dart';
import 'player_seat_view.dart';
import 'table_surface.dart';

/// Felt board: opponent rim seats, local seat on the bottom rim, center piles,
/// and the local hand strip along the bottom inner border.
///
/// Group controls and DROP/SHOW live outside this widget in [RummyGameView]'s
/// bottom lane.
class RummyTableBoard extends StatelessWidget {
  final List<PlayerView> opponents;
  final PlayerView me;
  final List<rummy.Card> hand;
  final rummy.Value? wildValue;
  final rummy.Card? cutJokerCard;
  final int closedDeckCount;

  /// Full discard history for the mockup (oldest → newest). Prefer this when set.
  final List<rummy.Card>? discardPile;

  /// Live open-deck top only (server snapshots expose a single card).
  final rummy.Card? discardTop;

  final rummy.Card? finishSlotCard;
  final RummyTurnPhase? phase;
  final int? currentTurnUserId;
  final int? turnSecondsRemaining;
  final RummyLayout layout;
  final int? selectedIndex;
  final Set<int> groupBreaksAfterIndex;
  final DeclareResultEvent? declareResult;
  final String? declareResultName;
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

  const RummyTableBoard({
    super.key,
    required this.opponents,
    required this.me,
    required this.hand,
    required this.wildValue,
    required this.closedDeckCount,
    this.cutJokerCard,
    this.discardPile,
    this.discardTop,
    this.finishSlotCard,
    this.phase,
    this.currentTurnUserId,
    this.turnSecondsRemaining,
    this.layout = RummyLayout.standard,
    this.selectedIndex,
    this.groupBreaksAfterIndex = const {},
    this.declareResult,
    this.declareResultName,
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
  });

  bool get _isMyTurn => currentTurnUserId != null && me.userId == currentTurnUserId;

  double get _handStripHeight {
    final L = layout;
    if (hand.isEmpty) return L.handEmptyHeight;
    return groupBreaksAfterIndex.isNotEmpty ? L.handHeightWithMelds : L.handHeightPlain;
  }

  @override
  Widget build(BuildContext context) {
    final L = layout;
    return Padding(
      padding: L.tableVerticalPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideInset = constraints.maxWidth * L.tableHorizontalInsetFraction;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: sideInset),
            child: SizedBox.expand(
              child: TableSurface(
                child: Column(
                  children: [
                    // Opponents + piles — all remaining felt above the hand / local seat.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, pileConstraints) {
                          final pileSize = Size(pileConstraints.maxWidth, pileConstraints.maxHeight);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ..._opponentRimSeats(pileSize, L),
                              // Bias piles downward so they sit nearer the visual middle of the oval.
                              Align(
                                alignment: Alignment(0, L.pileAlignY),
                                child: CardPilesView(
                                  closedDeckCount: closedDeckCount,
                                  discardPile: discardPile,
                                  discardTop: discardTop,
                                  cutJokerCard: cutJokerCard,
                                  wildValue: wildValue,
                                  finishSlotCard: finishSlotCard,
                                  layout: L,
                                  onDrawClosed: onDrawClosed,
                                  onDrawOpen: onDrawOpen,
                                  onDiscardDrop: onDiscardDrop,
                                  onFinishDrop: onFinishDrop,
                                ),
                              ),
                              if (declareResult != null)
                                DeclareResultPanel(
                                  declarerName: declareResultName ?? 'Player',
                                  result: declareResult!,
                                  onClose: onCloseDeclareResult ?? () {},
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Hand along the bottom inner border — fixed height, no scale-down.
                    SizedBox(
                      height: _handStripHeight,
                      width: double.infinity,
                      child: HandView(
                        cards: hand,
                        wildValue: wildValue,
                        selectedIndex: selectedIndex,
                        groupBreaksAfterIndex: groupBreaksAfterIndex,
                        layout: L,
                        onCardTap: onCardTap,
                        onToggleGroupBreak: onToggleGroupBreak,
                        onMoveCard: onMoveCard,
                        onMoveIntoGap: onMoveIntoGap,
                        onAcceptFromPile: onAcceptFromPile,
                      ),
                    ),
                    // Local seat on the bottom rim of the oval (same chip style as opponents).
                    SizedBox(
                      height: L.localSeatBandHeight,
                      width: double.infinity,
                      child: Center(
                        child: PlayerSeatView(
                          player: me,
                          isCurrentTurn: _isMyTurn,
                          isMe: true,
                          compact: true,
                          nameAbove: false,
                          showScoreOnPlate: true,
                          turnSecondsRemaining: _isMyTurn ? turnSecondsRemaining : null,
                          layout: L,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _opponentRimSeats(Size size, RummyLayout layout) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.49;
    final ry = size.height * 0.42;
    final count = opponents.length;

    if (count == 0) return const [];

    return [
      for (var i = 0; i < count; i++)
        _seatAt(
          cx: cx,
          cy: cy,
          rx: rx,
          ry: ry,
          // Upper arc only — bottom rim is reserved for the local seat + hand.
          angle: count == 1 ? math.pi / 2 : math.pi - i * (math.pi / (count - 1)),
          player: opponents[i],
          layout: layout,
        ),
    ];
  }

  Widget _seatAt({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required double angle,
    required PlayerView player,
    required RummyLayout layout,
  }) {
    final x = cx + rx * math.cos(angle);
    final y = cy - ry * math.sin(angle);
    final seatW = layout.seatNameplateMaxWidth;
    final avatarR = layout.seatAvatarSize / 2;
    // Name sits under the avatar for opponents — offset so the plate clears the circle.
    final nameBlock = 28 * layout.scale;
    final isTurn = currentTurnUserId != null && player.userId == currentTurnUserId;
    return Positioned(
      left: x - seatW / 2,
      top: y - avatarR,
      width: seatW,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: layout.seatAvatarSize + layout.seatTimerRingPad + nameBlock,
            child: PlayerSeatView(
              player: player,
              isCurrentTurn: isTurn,
              isMe: false,
              compact: true,
              nameAbove: false,
              turnSecondsRemaining: isTurn ? turnSecondsRemaining : null,
              layout: layout,
            ),
          ),
        ),
      ),
    );
  }
}

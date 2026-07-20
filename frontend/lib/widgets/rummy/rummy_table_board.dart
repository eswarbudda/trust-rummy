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

/// Felt board: opponent rim seats + center piles in the upper region,
/// then a dedicated local column (hand → name → avatar) that never
/// competes with [Positioned] overlays for the same vertical space.
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

  /// Selection tools (Left / Create Group / Right) rendered under the seat.
  final Widget? selectionTools;

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
    this.selectionTools,
  });

  @override
  Widget build(BuildContext context) {
    final L = layout;
    return Padding(
      padding: L.tablePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var width = constraints.maxWidth;
          var height = constraints.maxHeight;
          final ratio = width / height;
          if (ratio > L.tableMaxAspect) {
            width = height * L.tableMaxAspect;
          } else if (ratio < L.tableMinAspect) {
            height = width / L.tableMinAspect;
          }

          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: TableSurface(
                child: Column(
                  children: [
                    // Opponents + piles — takes remaining space above the local zone.
                    Expanded(
                      flex: 5,
                      child: LayoutBuilder(
                        builder: (context, pileConstraints) {
                          final pileSize = Size(pileConstraints.maxWidth, pileConstraints.maxHeight);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ..._opponentRimSeats(pileSize, L),
                              Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
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
                    // Local zone: hand → username → avatar → tools (no Stack overlap).
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8 * L.scale),
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: width - 16 * L.scale,
                                    height: L.handHeightWithMelds,
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
                                ),
                              ),
                            ),
                            SizedBox(height: 6 * L.scale),
                            PlayerSeatView(
                              player: me,
                              isCurrentTurn: currentTurnUserId != null && me.userId == currentTurnUserId,
                              isMe: true,
                              compact: true,
                              nameAbove: true,
                              turnSecondsRemaining:
                                  (currentTurnUserId != null && me.userId == currentTurnUserId)
                                      ? turnSecondsRemaining
                                      : null,
                              layout: L,
                            ),
                            if (selectionTools != null) ...[
                              SizedBox(height: 10 * L.scale),
                              selectionTools!,
                            ],
                            SizedBox(height: 4 * L.scale),
                          ],
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

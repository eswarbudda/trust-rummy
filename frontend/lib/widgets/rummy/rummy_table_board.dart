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

/// Shared felt board: rim seats, center piles, local hand, optional declare panel.
///
/// Used by both the visual mockup and the live [RummyGameScreen]. Chrome
/// (exit / meta pill / action bar / phase chips) stays on the parent screen.
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ..._opponentRimSeats(Size(width, height), L),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: height * 0.24,
                      height: L.handCardHeight + 40 * L.scale,
                      child: Center(
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
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: L.handBottomInset,
                      height: L.handHeightWithMelds + 4 * L.scale,
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
                    _localRimSeat(Size(width, height), L),
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
        },
      ),
    );
  }

  List<Widget> _opponentRimSeats(Size size, RummyLayout layout) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rx = size.width * 0.49;
    final ry = size.height * 0.48;
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
          isMe: false,
        ),
    ];
  }

  Widget _localRimSeat(Size size, RummyLayout layout) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Name under the avatar so the hand can sit lower without covering the label.
    return _seatAt(
      cx: cx,
      cy: cy,
      rx: size.width * 0.49,
      ry: size.height * 0.47,
      angle: -math.pi / 2,
      player: me,
      layout: layout,
      isMe: true,
      nameAbove: false,
    );
  }

  Widget _seatAt({
    required double cx,
    required double cy,
    required double rx,
    required double ry,
    required double angle,
    required PlayerView player,
    required RummyLayout layout,
    required bool isMe,
    bool nameAbove = false,
  }) {
    final x = cx + rx * math.cos(angle);
    final y = cy - ry * math.sin(angle);
    final seatW = layout.seatNameplateMaxWidth;
    final avatarR = layout.seatAvatarSize / 2;
    final nameBlock = nameAbove ? 34 * layout.scale : 0.0;
    final isTurn = currentTurnUserId != null && player.userId == currentTurnUserId;
    return Positioned(
      left: x - seatW / 2,
      top: y - avatarR - nameBlock,
      width: seatW,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: PlayerSeatView(
            player: player,
            isCurrentTurn: isTurn,
            isMe: isMe,
            compact: true,
            nameAbove: nameAbove,
            turnSecondsRemaining: isTurn ? turnSecondsRemaining : null,
            layout: layout,
          ),
        ),
      ),
    );
  }
}

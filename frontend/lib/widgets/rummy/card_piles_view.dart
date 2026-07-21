import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';
import 'hand_view.dart';
import 'playing_card_view.dart';

/// Center piles: closed deck (+ cut joker under it), discard / open deck, finish slot.
/// Deck / discard can be tapped or dragged onto the hand to draw.
///
/// Pass [discardPile] (mock: full history, oldest → newest) or [discardTop]
/// (live: single open card from the server snapshot). When both are set,
/// [discardPile] wins for the multi-card bundle look.
class CardPilesView extends StatelessWidget {
  final int closedDeckCount;
  final List<rummy.Card>? discardPile;
  final rummy.Card? discardTop;
  final rummy.Card? cutJokerCard;
  final rummy.Value? wildValue;
  final rummy.Card? finishSlotCard;
  final RummyLayout layout;

  final VoidCallback? onDrawClosed;
  final VoidCallback? onDrawOpen;
  final ValueChanged<HandDragPayload>? onDiscardDrop;
  final ValueChanged<HandDragPayload>? onFinishDrop;

  const CardPilesView({
    super.key,
    required this.closedDeckCount,
    required this.wildValue,
    this.discardPile,
    this.discardTop,
    this.cutJokerCard,
    this.finishSlotCard,
    this.layout = RummyLayout.standard,
    this.onDrawClosed,
    this.onDrawOpen,
    this.onDiscardDrop,
    this.onFinishDrop,
  });

  rummy.Card? get _openTop {
    final pile = discardPile;
    if (pile != null && pile.isNotEmpty) return pile.last;
    return discardTop;
  }

  bool get _hasOpenCard => _openTop != null;

  // Match hand card proportions so open/discard faces read like your cards.
  double get _w => layout.cardWidth;
  double get _h => layout.handCardHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _closedDeckWithJoker(),
        SizedBox(width: layout.pileSpacingDeckToDiscard),
        _discardSlot(),
        SizedBox(width: layout.pileSpacingDiscardToFinish),
        _finishSlot(),
      ],
    );
  }

  Widget _closedDeckWithJoker() {
    final stackDepth = closedDeckCount.clamp(0, 5).toInt();
    final joker = cutJokerCard;
    final canDraw = onDrawClosed != null;
    final L = layout;

    // Cut joker lies landscape under the closed deck; left + bottom peek stay readable.
    // After RotatedBox(quarterTurns: 1): footprint is cardHeight × cardWidth.
    final jokerLayoutW = _h;
    final jokerLayoutH = _w;
    final jokerPeekLeft = L.jokerPeekLeft;
    final jokerPeekDown = L.jokerPeekDown;
    final boxW = joker != null ? (jokerPeekLeft + _w + 8 * L.scale) : (_w + 8 * L.scale);
    final boxH = joker != null ? (_h + jokerPeekDown + 10 * L.scale) : (_h + 8 * L.scale);
    final deckLeft = joker != null ? jokerPeekLeft : 4.0 * L.scale;
    final deckBottom = joker != null ? (jokerPeekDown + 4 * L.scale) : 4.0 * L.scale;
    final jokerBottom = 0.0;

    final stack = SizedBox(
      width: boxW,
      height: boxH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (joker != null)
            Positioned(
              left: 0,
              bottom: jokerBottom,
              width: jokerLayoutW,
              height: jokerLayoutH,
              child: RotatedBox(
                quarterTurns: 1,
                child: PlayingCardView(
                  card: joker,
                  width: _w,
                  height: _h,
                ),
              ),
            ),
          for (var i = 0; i < stackDepth; i++)
            Positioned(
              left: deckLeft + i * L.pileStackOffsetX,
              bottom: deckBottom + i * L.pileStackOffsetY,
              child: PlayingCardView(faceUp: false, width: _w, height: _h),
            ),
        ],
      ),
    );

    final labeled = _labeledPile(
      stack,
      joker != null ? 'OPEN JOKER' : '',
      joker != null ? RummyColors.gold : Colors.transparent,
      highlight: canDraw,
    );

    // Prefer a clear tap target over nested Draggable-on-web quirks.
    // Drag-onto-hand still works via Draggable when canDraw.
    final tappable = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canDraw ? onDrawClosed : null,
        borderRadius: BorderRadius.circular(10),
        child: labeled,
      ),
    );

    if (!canDraw) return labeled;

    return Draggable<PileDragPayload>(
      data: const PileDragPayload(fromClosed: true),
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        elevation: 10,
        child: PlayingCardView(faceUp: false, width: _w, height: _h),
      ),
      childWhenDragging: Opacity(opacity: 0.45, child: labeled),
      child: tappable,
    );
  }

  Widget _discardSlot() {
    final pile = _discardBundle();
    final top = _openTop;
    final canDraw = onDrawOpen != null && _hasOpenCard;
    final canReceiveDiscard = onDiscardDrop != null;

    Widget labeled = _labeledPile(
      pile,
      'OPEN DECK',
      canDraw || canReceiveDiscard ? Colors.white70 : Colors.white54,
      highlight: canDraw,
    );

    if (canDraw && top != null) {
      labeled = Draggable<PileDragPayload>(
        data: const PileDragPayload(fromClosed: false),
        maxSimultaneousDrags: 1,
        feedback: Material(
          color: Colors.transparent,
          elevation: 10,
          child: PlayingCardView(
            card: top,
            isWild: top.isWildFor(wildValue),
            width: _w,
            height: _h,
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.45, child: labeled),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDrawOpen,
            borderRadius: BorderRadius.circular(10),
            child: labeled,
          ),
        ),
      );
    } else if (onDrawOpen != null) {
      labeled = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDrawOpen,
          borderRadius: BorderRadius.circular(10),
          child: labeled,
        ),
      );
    }

    if (!canReceiveDiscard) return labeled;

    return DragTarget<HandDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onDiscardDrop!(d.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: hovering ? 1.08 : 1.0,
          child: Container(
            decoration: hovering
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: RummyColors.info.withOpacity(0.55), blurRadius: 14)],
                  )
                : null,
            child: hovering
                ? _labeledPile(pile, 'DROP HERE', RummyColors.info, highlight: true)
                : labeled,
          ),
        );
      },
    );
  }

  Widget _discardBundle() {
    final pile = discardPile;
    // Mock: multi-card discard history bundle.
    if (pile != null && pile.isNotEmpty) {
      final top = pile.last;
      final under = pile.length > 1 ? pile.sublist(0, pile.length - 1).reversed.take(3).toList() : <rummy.Card>[];
      const step = 2.2;
      final layers = under.length;
      final boxW = _w + layers * step;
      final boxH = _h + layers * step;

      return SizedBox(
        width: boxW,
        height: boxH,
        child: Stack(
          children: [
            for (var i = 0; i < layers; i++)
              Positioned(
                left: i * step,
                top: i * step,
                child: Opacity(
                  opacity: 0.85,
                  child: PlayingCardView(
                    card: under[layers - 1 - i],
                    isWild: under[layers - 1 - i].isWildFor(wildValue),
                    width: _w,
                    height: _h,
                  ),
                ),
              ),
            Positioned(
              left: layers * step,
              top: layers * step,
              child: PlayingCardView(
                card: top,
                isWild: top.isWildFor(wildValue),
                width: _w,
                height: _h,
              ),
            ),
          ],
        ),
      );
    }

    // Live: single face-up open card at hand size.
    final top = discardTop;
    if (top != null) {
      return PlayingCardView(
        card: top,
        isWild: top.isWildFor(wildValue),
        width: _w,
        height: _h,
      );
    }

    return Container(
      width: _w,
      height: _h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(Icons.arrow_forward, color: Colors.white.withOpacity(0.45), size: 22),
    );
  }

  Widget _finishSlot() {
    final child = finishSlotCard != null
        ? PlayingCardView(card: finishSlotCard, width: _w, height: _h)
        : Container(
            width: _w,
            height: _h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: RummyColors.gold.withOpacity(0.45), width: 1.4),
            ),
            child: Text(
              'FINISH\nSLOT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          );

    if (onFinishDrop == null) {
      return _slotBox(child, finishSlotCard != null ? 'FINISHED' : 'FINISH SLOT');
    }

    return DragTarget<HandDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onFinishDrop!(d.data),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: hovering ? 1.08 : 1.0,
          child: _slotBox(child, hovering ? 'SHOW HERE' : 'FINISH SLOT', highlight: hovering),
        );
      },
    );
  }

  Widget _slotBox(Widget child, String label, {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: highlight
                ? [BoxShadow(color: RummyColors.gold.withOpacity(0.55), blurRadius: 14)]
                : null,
          ),
          child: child,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: highlight ? RummyColors.gold : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _labeledPile(Widget child, String label, Color labelColor, {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: highlight
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: RummyColors.gold.withOpacity(0.4), blurRadius: 14, spreadRadius: 1)],
                )
              : null,
          child: child,
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(color: labelColor, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
          ),
        ],
      ],
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../theme/rummy_colors.dart';

/// Renders a single playing card — either face-up (rank + suit, with a
/// distinct highlight when it's this deal's wild joker) or as a face-down
/// card back for opponents' hands and the closed deck.
class PlayingCardView extends StatelessWidget {
  final rummy.Card? card;
  final bool faceUp;
  final bool isWild;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const PlayingCardView({
    super.key,
    this.card,
    this.faceUp = true,
    this.isWild = false,
    this.selected = false,
    this.width = 56,
    this.height = 78,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = faceUp && card != null ? _buildFace(card!) : _buildBack();

    final painted = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: width,
      height: height,
      transform: selected ? Matrix4.translationValues(0.0, -10.0, 0.0) : Matrix4.identity(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(selected ? 0.45 : 0.28),
            blurRadius: selected ? 10 : 4,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: selected
              ? RummyColors.gold
              : isWild
                  ? RummyColors.gold.withOpacity(0.7)
                  : Colors.black26,
          width: selected ? 2.4 : (isWild ? 1.8 : 1),
        ),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(7), child: child),
    );

    // Only wrap a GestureDetector when this card itself owns the tap —
    // otherwise a parent Draggable/GestureDetector (e.g. HandView) would
    // lose the gesture arena to this empty detector and drag would stall.
    if (onTap == null) return painted;
    return GestureDetector(onTap: onTap, child: painted);
  }

  Widget _buildFace(rummy.Card c) {
    final isRed = c.suit == rummy.Suit.hearts || c.suit == rummy.Suit.diamonds;
    final color = c.isPrintedJoker ? RummyColors.gold : (isRed ? RummyColors.suitRed : RummyColors.suitBlack);
    // Scale pip / corner type with card size (baseline width 56).
    final t = (width / 56.0).clamp(0.95, 1.55);
    final centerSize = (c.isPrintedJoker ? 28.0 : 26.0) * t;
    final rankSize = 14.0 * t;
    final suitSize = 13.0 * t;

    return Container(
      color: RummyColors.cardFace,
      padding: EdgeInsets.symmetric(horizontal: 4 * t, vertical: 3 * t),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, child: _cornerIndex(c, color, rankSize, suitSize)),
          Positioned(
            bottom: 0,
            right: 0,
            child: Transform.rotate(angle: math.pi, child: _cornerIndex(c, color, rankSize, suitSize)),
          ),
          Center(
            child: Text(
              c.isPrintedJoker ? '★' : suitSymbol(c.suit),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: centerSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isWild && !c.isPrintedJoker)
            Positioned(
              bottom: 2,
              right: 2,
              child: Icon(Icons.stars_rounded, size: 13 * t, color: RummyColors.gold),
            ),
        ],
      ),
    );
  }

  /// A classic playing card's corner "index" — rank stacked above the
  /// small suit glyph — mirrored into the opposite corner (rotated 180°)
  /// so the card reads right-side-up from either end of a fan.
  Widget _cornerIndex(rummy.Card c, Color color, double rankSize, double suitSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c.isPrintedJoker ? 'JK' : c.value.shortCode,
          style: TextStyle(color: color, fontSize: rankSize, fontWeight: FontWeight.w800, height: 1),
        ),
        if (!c.isPrintedJoker)
          Text(
            suitSymbol(c.suit),
            style: TextStyle(color: color, fontSize: suitSize, height: 1),
          ),
      ],
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: const BoxDecoration(gradient: RummyColors.cardBackGradient),
      child: Center(
        child: Container(
          width: width * 0.5,
          height: height * 0.5,
          decoration: BoxDecoration(
            border: Border.all(color: RummyColors.cardBackAccent, width: 1.4),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  static String suitSymbol(rummy.Suit? suit) {
    switch (suit) {
      case rummy.Suit.spades:
        return '♠';
      case rummy.Suit.hearts:
        return '♥';
      case rummy.Suit.diamonds:
        return '♦';
      case rummy.Suit.clubs:
        return '♣';
      case null:
        return '';
    }
  }
}

import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';
import 'hand_grouping.dart';
import 'playing_card_view.dart';

/// Card dragged from the local hand.
class HandDragPayload {
  final int handIndex;
  final rummy.Card card;

  const HandDragPayload({required this.handIndex, required this.card});
}

/// Card dragged from the closed deck or open discard pile onto the hand.
class PileDragPayload {
  final bool fromClosed;

  const PileDragPayload({required this.fromClosed});
}

/// Local player's hand. Groups are defined only by [groupBreaksAfterIndex]
/// (manual Split/Merge); cards are never auto-reordered. Each group is
/// reclassified with [classifyGroup] whenever the hand rebuilds.
class HandView extends StatelessWidget {
  final List<rummy.Card> cards;
  final rummy.Value? wildValue;
  final int? selectedIndex;
  final Set<int> groupBreaksAfterIndex;
  final RummyLayout layout;
  final void Function(int index, rummy.Card card)? onCardTap;
  final void Function(int index)? onToggleGroupBreak;
  final void Function(int fromIndex, int toIndex)? onMoveCard;
  final void Function(int fromIndex, int gapAfterIndex)? onMoveIntoGap;
  final void Function(bool fromClosed)? onAcceptFromPile;

  const HandView({
    super.key,
    required this.cards,
    required this.wildValue,
    this.selectedIndex,
    this.groupBreaksAfterIndex = const {},
    this.layout = RummyLayout.standard,
    this.onCardTap,
    this.onToggleGroupBreak,
    this.onMoveCard,
    this.onMoveIntoGap,
    this.onAcceptFromPile,
  });

  static bool isFormedMeld(String kind) =>
      kind == 'SET' || kind == 'SEQUENCE' || kind == 'PURE_SEQUENCE';

  /// Manual groups from breaks, each labeled via [classifyGroup].
  List<HandSegment> _segments() {
    final groups = HandGrouping.splitIntoGroups(cards, groupBreaksAfterIndex);
    final segments = <HandSegment>[];
    var start = 0;
    for (final group in groups) {
      final kind = group.length >= 3 ? classifyGroup(group, wildValue) : (group.length >= 2 ? 'GROUP' : null);
      segments.add(HandSegment(startIndex: start, cards: group, kind: kind));
      start += group.length;
    }
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final L = layout;

    if (cards.isEmpty) {
      return DragTarget<PileDragPayload>(
        onWillAcceptWithDetails: (_) => onAcceptFromPile != null,
        onAcceptWithDetails: (d) => onAcceptFromPile?.call(d.data.fromClosed),
        builder: (context, candidate, rejected) {
          return SizedBox(
            height: L.handEmptyHeight,
            child: Center(
              child: Text(
                candidate.isNotEmpty ? 'Drop drawn card here' : 'No cards yet',
                style: TextStyle(color: candidate.isNotEmpty ? RummyColors.gold : Colors.white38),
              ),
            ),
          );
        },
      );
    }

    // Groups come only from manual breaks — never auto-reordered.
    final segments = _segments();

    return DragTarget<PileDragPayload>(
      onWillAcceptWithDetails: (_) => onAcceptFromPile != null,
      onAcceptWithDetails: (d) => onAcceptFromPile?.call(d.data.fromClosed),
      builder: (context, pileCandidate, rejected) {
        final drawing = pileCandidate.isNotEmpty;
        final anyLabeled = segments.any((s) => s.showLabel);

        return Container(
          height: anyLabeled ? L.handHeightWithMelds : L.handHeightPlain,
          decoration: drawing
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RummyColors.gold.withOpacity(0.7), width: 1.5),
                  color: RummyColors.gold.withOpacity(0.08),
                )
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final groupCount = segments.length;
              final gapBudget = (groupCount - 1).clamp(0, 99) * L.handMeldGap + (cards.length - 1) * L.handSoftGap;
              final available = (constraints.maxWidth * 0.96) - gapBudget - (groupCount * 12.0 * L.scale);
              final slot = (available / cards.length).clamp(L.handSlotMin, L.handSlotMax);

              final rowChildren = <Widget>[];
              for (var g = 0; g < segments.length; g++) {
                final segment = segments[g];
                final formed = segment.isFormedMeld;
                final tray = segment.showLabel;

                final cardsRow = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = 0; k < segment.cards.length; k++) ...[
                      _HandCard(
                        key: ValueKey('hand_${segment.startIndex + k}_${segment.cards[k].code}'),
                        index: segment.startIndex + k,
                        card: segment.cards[k],
                        slotWidth: slot,
                        cardWidth: L.cardWidth,
                        cardHeight: L.handCardHeight,
                        selected: selectedIndex == segment.startIndex + k,
                        isWild: segment.cards[k].isWildFor(wildValue),
                        onTap: () => onCardTap?.call(segment.startIndex + k, segment.cards[k]),
                        onMoveHere: (from) => onMoveCard?.call(from, segment.startIndex + k),
                      ),
                      if (k < segment.cards.length - 1)
                        _BetweenGap(
                          width: L.handSoftGap,
                          isGroupBreak: false,
                          onDrop: (from) {
                            final after = segment.startIndex + k;
                            if (onMoveIntoGap != null) {
                              onMoveIntoGap!(from, after);
                            } else {
                              onMoveCard?.call(from, after);
                            }
                          },
                          onTap: () => onToggleGroupBreak?.call(segment.startIndex + k),
                        ),
                    ],
                  ],
                );

                final label = !segment.showLabel
                    ? null
                    : (formed ? '✓ ${meldLabel(segment.kind!)}' : '✕ ${meldLabel(segment.kind ?? 'GROUP')}');
                final labelColor = formed ? RummyColors.success : RummyColors.danger;

                rowChildren.add(
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * L.scale, vertical: 2 * L.scale),
                    child: DecoratedBox(
                      decoration: tray
                          ? BoxDecoration(
                              color: formed
                                  ? L.meldTrayFill.withOpacity(0.35)
                                  : Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(L.meldTrayRadius),
                              border: Border.all(
                                color: formed ? L.meldTrayBorder : Colors.white24,
                                width: formed ? L.meldTrayBorderWidth : 1,
                              ),
                            )
                          : const BoxDecoration(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tray ? 6 * L.scale : 0,
                          vertical: tray ? 4 * L.scale : 0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            cardsRow,
                            if (label != null) ...[
                              SizedBox(height: 5 * L.scale),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8 * L.scale, vertical: 3 * L.scale),
                                decoration: BoxDecoration(
                                  color: labelColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5 * L.scale,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                if (g < segments.length - 1) {
                  final gapAfter = segment.startIndex + segment.cards.length - 1;
                  rowChildren.add(
                    Padding(
                      padding: EdgeInsets.only(top: 8 * L.scale),
                      child: _BetweenGap(
                        width: L.handMeldGap,
                        isGroupBreak: true,
                        onDrop: (from) {
                          if (onMoveIntoGap != null) {
                            onMoveIntoGap!(from, gapAfter);
                          } else {
                            onMoveCard?.call(from, gapAfter + 1);
                          }
                        },
                        onTap: () => onToggleGroupBreak?.call(gapAfter),
                      ),
                    ),
                  );
                }
              }

              return Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 8 * L.scale, vertical: 4 * L.scale),
                  child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Client-side visual heuristic aligned with backend [HandValidator] classify:
  /// sets may use jokers; sequences may use jokers for gaps/extensions within A–K.
  static String classifyGroup(List<rummy.Card> group, rummy.Value? wildValue) {
    if (group.length < 3) return 'GROUP';

    final natural = <rummy.Card>[];
    var wildCount = 0;
    for (final c in group) {
      if (c.isWildFor(wildValue)) {
        wildCount++;
      } else {
        natural.add(c);
      }
    }
    // Need at least one natural anchor (same rule as the server).
    if (natural.isEmpty) return 'GROUP';

    // SET (3–4 cards): naturals share rank, distinct suits; jokers fill remaining.
    if (group.length <= 4 && _isSetShape(natural)) {
      return 'SET';
    }

    // SEQUENCE: same suit, no duplicate ranks; jokers fill gaps / extend within A–K.
    final seq = _classifySequence(natural, wildCount, group.length);
    if (seq != null) return seq;

    return 'GROUP';
  }

  static bool _isSetShape(List<rummy.Card> naturals) {
    final rank = naturals.first.value;
    final suits = <rummy.Suit>{};
    for (final c in naturals) {
      if (c.value != rank) return false;
      if (c.suit == null) return false;
      if (!suits.add(c.suit!)) return false; // duplicate suit
    }
    return true;
  }

  /// Returns PURE_SEQUENCE / SEQUENCE, or null if invalid.
  static String? _classifySequence(List<rummy.Card> naturals, int jokerCount, int groupLength) {
    if (naturals.first.suit == null) return null;
    final suit = naturals.first.suit!;
    final ranks = <int>{};
    for (final c in naturals) {
      if (c.suit != suit) return null;
      final r = _rankOrder(c); // ACE=0 … KING=12
      if (r < 0 || !ranks.add(r)) return null; // duplicate rank
    }

    final sorted = ranks.toList()..sort();
    final min = sorted.first;
    final max = sorted.last;
    final span = max - min + 1;
    final internalGaps = span - naturals.length;
    if (internalGaps < 0 || internalGaps > jokerCount) return null;

    // Leftover jokers must extend the run without leaving A–K.
    final extension = jokerCount - internalGaps;
    final roomBelow = min;
    final roomAbove = 12 - max;
    if (roomBelow + roomAbove < extension) return null;

    // Contiguous group length must match naturals + jokers used in this meld.
    if (naturals.length + jokerCount != groupLength) return null;

    return jokerCount == 0 ? 'PURE_SEQUENCE' : 'SEQUENCE';
  }

  /// Ace-low ordinal matching backend [Value.ordinal] (ACE=0 … KING=12).
  static int _rankOrder(rummy.Card c) {
    switch (c.value) {
      case rummy.Value.ace:
        return 0;
      case rummy.Value.two:
        return 1;
      case rummy.Value.three:
        return 2;
      case rummy.Value.four:
        return 3;
      case rummy.Value.five:
        return 4;
      case rummy.Value.six:
        return 5;
      case rummy.Value.seven:
        return 6;
      case rummy.Value.eight:
        return 7;
      case rummy.Value.nine:
        return 8;
      case rummy.Value.ten:
        return 9;
      case rummy.Value.jack:
        return 10;
      case rummy.Value.queen:
        return 11;
      case rummy.Value.king:
        return 12;
      case rummy.Value.joker:
        return -1;
    }
  }

  static String meldLabel(String type) {
    switch (type) {
      case 'PURE_SEQUENCE':
        return 'Pure Sequence';
      case 'SEQUENCE':
        return 'Impure Sequence';
      case 'SET':
        return 'Set';
      case 'GROUP':
      default:
        return 'Invalid Group';
    }
  }
}

class _HandCard extends StatelessWidget {
  final int index;
  final rummy.Card card;
  final double slotWidth;
  final double cardWidth;
  final double cardHeight;
  final bool selected;
  final bool isWild;
  final VoidCallback onTap;
  final ValueChanged<int> onMoveHere;

  const _HandCard({
    super.key,
    required this.index,
    required this.card,
    required this.slotWidth,
    required this.cardWidth,
    required this.cardHeight,
    required this.selected,
    required this.isWild,
    required this.onTap,
    required this.onMoveHere,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = PlayingCardView(
      card: card,
      isWild: isWild,
      selected: selected,
      width: cardWidth,
      height: cardHeight,
    );

    return DragTarget<HandDragPayload>(
      onWillAcceptWithDetails: (d) => d.data.handIndex != index,
      onAcceptWithDetails: (d) => onMoveHere(d.data.handIndex),
      builder: (context, candidate, rejected) {
        return SizedBox(
          width: slotWidth,
          height: cardHeight + 12,
          child: OverflowBox(
            maxWidth: cardWidth,
            minWidth: cardWidth,
            alignment: Alignment.bottomCenter,
            child: Draggable<HandDragPayload>(
              data: HandDragPayload(handIndex: index, card: card),
              maxSimultaneousDrags: 1,
              feedback: Material(
                color: Colors.transparent,
                elevation: 12,
                child: PlayingCardView(
                  card: card,
                  isWild: isWild,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.2, child: cardWidget),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: candidate.isNotEmpty
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: RummyColors.gold.withOpacity(0.55), blurRadius: 12)],
                        )
                      : null,
                  child: cardWidget,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BetweenGap extends StatelessWidget {
  final double width;
  final bool isGroupBreak;
  final ValueChanged<int> onDrop;
  final VoidCallback onTap;

  const _BetweenGap({
    required this.width,
    required this.isGroupBreak,
    required this.onDrop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<HandDragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) => onDrop(d.data.handIndex),
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty || isGroupBreak;
        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 100,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: hot ? 3.5 : 1.2,
                height: hot ? 70 : 40,
                decoration: BoxDecoration(
                  color: candidate.isNotEmpty
                      ? RummyColors.gold
                      : isGroupBreak
                          ? RummyColors.gold.withOpacity(0.7)
                          : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

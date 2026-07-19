import 'package:flutter/material.dart';

import '../../models/card.dart' as rummy;
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';
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

/// Local player's hand. Only valid sets/sequences get a tray + label;
/// loose cards stay in a plain fan with no group chrome.
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

    // Visual groups come only from contiguous valid melds — not manual splits.
    final segments = _meldSegments();

    return DragTarget<PileDragPayload>(
      onWillAcceptWithDetails: (_) => onAcceptFromPile != null,
      onAcceptWithDetails: (d) => onAcceptFromPile?.call(d.data.fromClosed),
      builder: (context, pileCandidate, rejected) {
        final drawing = pileCandidate.isNotEmpty;
        final anyFormed = segments.any((s) => s.kind != null);

        return Container(
          height: anyFormed ? L.handHeightWithMelds : L.handHeightPlain,
          decoration: drawing
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RummyColors.gold.withOpacity(0.7), width: 1.5),
                  color: RummyColors.gold.withOpacity(0.08),
                )
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final formedCount = segments.where((s) => s.kind != null).length;
              final gapBudget = formedCount * L.handMeldGap + (cards.length - 1) * L.handSoftGap;
              final available = (constraints.maxWidth * 0.96) - gapBudget - (formedCount * 20.0 * L.scale);
              final slot = (available / cards.length).clamp(L.handSlotMin, L.handSlotMax);

              final rowChildren = <Widget>[];
              for (var g = 0; g < segments.length; g++) {
                final segment = segments[g];
                final formed = segment.kind != null;

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

                // Reference: cards on top, status pill underneath each group.
                final label = formed
                    ? '✓ ${meldLabel(segment.kind!)}'
                    : (segment.cards.length >= 2 ? '✕ Invalid' : null);
                final labelColor = formed ? RummyColors.success : RummyColors.danger;

                rowChildren.add(
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * L.scale, vertical: 2 * L.scale),
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
                );

                if (g < segments.length - 1) {
                  final gapAfter = segment.startIndex + segment.cards.length - 1;
                  final nextFormed = segments[g + 1].kind != null;
                  final aisle = formed || nextFormed;
                  rowChildren.add(
                    Padding(
                      padding: EdgeInsets.only(top: 8 * L.scale),
                      child: _BetweenGap(
                        width: aisle ? L.handMeldGap : L.handSoftGap + 2 * L.scale,
                        isGroupBreak: aisle,
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

  /// Walk the hand left→right; tray only contiguous valid melds (set / sequence).
  List<_HandSegment> _meldSegments() {
    final segments = <_HandSegment>[];
    var i = 0;
    while (i < cards.length) {
      String? kind;
      var len = 0;
      // Prefer longer runs (sequences up to remaining; sets max 4).
      final maxLen = cards.length - i;
      for (var tryLen = maxLen; tryLen >= 3; tryLen--) {
        final slice = cards.sublist(i, i + tryLen);
        final k = classifyGroup(slice, wildValue);
        if (isFormedMeld(k)) {
          kind = k;
          len = tryLen;
          break;
        }
      }
      if (kind != null) {
        segments.add(_HandSegment(startIndex: i, cards: cards.sublist(i, i + len), kind: kind));
        i += len;
        continue;
      }
      final start = i;
      i++;
      while (i < cards.length) {
        var meldStartsHere = false;
        for (var tryLen = cards.length - i; tryLen >= 3; tryLen--) {
          if (isFormedMeld(classifyGroup(cards.sublist(i, i + tryLen), wildValue))) {
            meldStartsHere = true;
            break;
          }
        }
        if (meldStartsHere) break;
        i++;
      }
      segments.add(_HandSegment(startIndex: start, cards: cards.sublist(start, i), kind: null));
    }
    return segments;
  }

  /// Client-side visual heuristic only — server validates on Declare/Show.
  /// Sets: 3–4 same rank, distinct suits. Sequences: 3+ same suit, consecutive.
  static String classifyGroup(List<rummy.Card> group, rummy.Value? wildValue) {
    if (group.length < 3) return 'GROUP';

    final natural = group.where((c) => !c.isWildFor(wildValue)).toList();
    final wildCount = group.length - natural.length;
    if (natural.length < 2) return 'GROUP';

    // SET: same rank, distinct suits, exactly 3 or 4 cards.
    if (group.length <= 4 && natural.every((c) => c.value == natural.first.value)) {
      final suits = <rummy.Suit>{};
      for (final c in natural) {
        if (c.suit == null) return 'GROUP';
        if (!suits.add(c.suit!)) return 'GROUP';
      }
      return 'SET';
    }

    // SEQUENCE: same suit, consecutive ranks; wilds fill gaps only.
    if (natural.every((c) => c.suit != null && c.suit == natural.first.suit)) {
      final ranks = natural.map(_rankOrder).toList()..sort();
      var gaps = 0;
      for (var i = 1; i < ranks.length; i++) {
        final d = ranks[i] - ranks[i - 1];
        if (d <= 0) return 'GROUP';
        gaps += d - 1;
      }
      final span = ranks.last - ranks.first + 1;
      if (span > group.length) return 'GROUP';
      if (gaps <= wildCount) {
        return wildCount == 0 ? 'PURE_SEQUENCE' : 'SEQUENCE';
      }
    }
    return 'GROUP';
  }

  static int _rankOrder(rummy.Card c) {
    switch (c.value) {
      case rummy.Value.ace:
        return 1;
      case rummy.Value.two:
        return 2;
      case rummy.Value.three:
        return 3;
      case rummy.Value.four:
        return 4;
      case rummy.Value.five:
        return 5;
      case rummy.Value.six:
        return 6;
      case rummy.Value.seven:
        return 7;
      case rummy.Value.eight:
        return 8;
      case rummy.Value.nine:
        return 9;
      case rummy.Value.ten:
        return 10;
      case rummy.Value.jack:
        return 11;
      case rummy.Value.queen:
        return 12;
      case rummy.Value.king:
        return 13;
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
      default:
        return '';
    }
  }
}

class _HandSegment {
  final int startIndex;
  final List<rummy.Card> cards;
  /// Non-null only for a valid set / sequence.
  final String? kind;

  const _HandSegment({required this.startIndex, required this.cards, required this.kind});
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

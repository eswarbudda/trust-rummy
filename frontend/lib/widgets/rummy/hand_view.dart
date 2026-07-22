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
///
/// Cards always render at full [RummyLayout.cardWidth] — width pressure is
/// handled by overlap advance and/or horizontal scrolling, never by scaling.
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

    final segments = _segments();
    // Flat fan until the player creates a group break (Create Group / gap split).
    final groupingActive = groupBreaksAfterIndex.isNotEmpty;

    return DragTarget<PileDragPayload>(
      onWillAcceptWithDetails: (_) => onAcceptFromPile != null,
      onAcceptWithDetails: (d) => onAcceptFromPile?.call(d.data.fromClosed),
      builder: (context, pileCandidate, rejected) {
        final drawing = pileCandidate.isNotEmpty;
        final anyLabeled = groupingActive && segments.any((s) => s.showLabel);

        return Container(
          height: anyLabeled ? L.handHeightWithMelds : L.handHeightPlain,
          width: double.infinity,
          decoration: drawing
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: RummyColors.gold.withOpacity(0.7), width: 1.5),
                  color: RummyColors.gold.withOpacity(0.08),
                )
              : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final advance = _computeAdvance(segments, constraints.maxWidth, L);
              final rowChildren = <Widget>[];

              for (var g = 0; g < segments.length; g++) {
                final segment = segments[g];
                final formed = segment.isFormedMeld;
                final tray = groupingActive && segment.showLabel;

                final label = !tray
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
                            _OverlappingCardRow(
                              segment: segment,
                              advance: advance,
                              cardWidth: L.cardWidth,
                              cardHeight: L.handCardHeight,
                              softGap: L.handSoftGap,
                              selectedIndex: selectedIndex,
                              wildValue: wildValue,
                              onCardTap: onCardTap,
                              onMoveCard: onMoveCard,
                              onMoveIntoGap: onMoveIntoGap,
                              onToggleGroupBreak: onToggleGroupBreak,
                            ),
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

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8 * L.scale, vertical: 4 * L.scale),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth - 16 * L.scale),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: rowChildren,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Left-edge advance between cards: full width + soft gap when space allows,
  /// otherwise overlap down to [handSlotMin]. Never shrinks card widgets.
  double _computeAdvance(List<HandSegment> segments, double maxWidth, RummyLayout L) {
    final groupCount = segments.length;
    final trayPad = groupCount * 12.0 * L.scale;
    final sidePad = 16 * L.scale;
    final meldGaps = (groupCount - 1).clamp(0, 99) * L.handMeldGap;
    final available = (maxWidth - sidePad - trayPad - meldGaps).clamp(0.0, double.infinity);

    final openAdvance = L.cardWidth + L.handSoftGap;
    var idealWidth = 0.0;
    for (final s in segments) {
      final n = s.cards.length;
      if (n <= 0) continue;
      idealWidth += n == 1 ? L.cardWidth : (n - 1) * openAdvance + L.cardWidth;
    }

    if (idealWidth <= available || cards.length <= 1) {
      return openAdvance;
    }

    // sum_g ((n_g - 1) * advance + cardWidth) = (n - groupCount) * advance + groupCount * cardWidth
    final n = cards.length;
    final cardBases = groupCount * L.cardWidth;
    final steps = (n - groupCount).clamp(0, n);
    if (steps == 0) return L.cardWidth;
    return ((available - cardBases) / steps).clamp(L.handSlotMin, L.cardWidth);
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
  ///
  /// Ace may be low (A-2-3) or high (Q-K-A / J-Q-K-A). K-A-2 wrap is never legal.
  static String? _classifySequence(List<rummy.Card> naturals, int jokerCount, int groupLength) {
    final low = _classifySequenceRanks(naturals, jokerCount, groupLength, aceHigh: false);
    if (low != null) return low;
    final hasAce = naturals.any((c) => c.value == rummy.Value.ace);
    if (!hasAce) return null;
    return _classifySequenceRanks(naturals, jokerCount, groupLength, aceHigh: true);
  }

  static String? _classifySequenceRanks(
    List<rummy.Card> naturals,
    int jokerCount,
    int groupLength, {
    required bool aceHigh,
  }) {
    if (naturals.first.suit == null) return null;
    final suit = naturals.first.suit!;
    final ranks = <int>{};
    for (final c in naturals) {
      if (c.suit != suit) return null;
      final r = _sequenceRank(c, aceHigh: aceHigh);
      if (r < 0 || !ranks.add(r)) return null; // duplicate / joker-as-natural
    }

    final sorted = ranks.toList()..sort();
    final min = sorted.first;
    final max = sorted.last;
    final span = max - min + 1;
    final internalGaps = span - naturals.length;
    if (internalGaps < 0 || internalGaps > jokerCount) return null;

    final extension = jokerCount - internalGaps;
    final floor = aceHigh ? 1 : 0; // TWO…ACE(high) or ACE(low)…KING
    final ceiling = aceHigh ? 13 : 12;
    final roomBelow = min - floor;
    final roomAbove = ceiling - max;
    if (roomBelow + roomAbove < extension) return null;

    if (naturals.length + jokerCount != groupLength) return null;

    return jokerCount == 0 ? 'PURE_SEQUENCE' : 'SEQUENCE';
  }

  /// Ace-low: ACE=0…KING=12. Ace-high: TWO=1…KING=12, ACE=13.
  static int _sequenceRank(rummy.Card c, {required bool aceHigh}) {
    if (c.value == rummy.Value.ace) return aceHigh ? 13 : 0;
    return _rankOrder(c);
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

/// Renders one meld group as a width-based fan: full-size cards, [advance]
/// between left edges (overlap when advance &lt; cardWidth).
class _OverlappingCardRow extends StatelessWidget {
  final HandSegment segment;
  final double advance;
  final double cardWidth;
  final double cardHeight;
  final double softGap;
  final int? selectedIndex;
  final rummy.Value? wildValue;
  final void Function(int index, rummy.Card card)? onCardTap;
  final void Function(int fromIndex, int toIndex)? onMoveCard;
  final void Function(int fromIndex, int gapAfterIndex)? onMoveIntoGap;
  final void Function(int index)? onToggleGroupBreak;

  const _OverlappingCardRow({
    required this.segment,
    required this.advance,
    required this.cardWidth,
    required this.cardHeight,
    required this.softGap,
    required this.selectedIndex,
    required this.wildValue,
    this.onCardTap,
    this.onMoveCard,
    this.onMoveIntoGap,
    this.onToggleGroupBreak,
  });

  @override
  Widget build(BuildContext context) {
    final n = segment.cards.length;
    if (n == 0) return const SizedBox.shrink();

    final step = advance;
    final totalWidth = n == 1 ? cardWidth : (n - 1) * step + cardWidth;

    return SizedBox(
      width: totalWidth,
      height: cardHeight + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var k = 0; k < n; k++)
            Positioned(
              left: k * step,
              bottom: 0,
              width: cardWidth,
              height: cardHeight + 12,
              child: _HandCard(
                key: ValueKey('hand_${segment.startIndex + k}_${segment.cards[k].code}'),
                index: segment.startIndex + k,
                card: segment.cards[k],
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                selected: selectedIndex == segment.startIndex + k,
                isWild: segment.cards[k].isWildFor(wildValue),
                onTap: () => onCardTap?.call(segment.startIndex + k, segment.cards[k]),
                onMoveHere: (from) => onMoveCard?.call(from, segment.startIndex + k),
              ),
            ),
          for (var k = 0; k < n - 1; k++)
            Positioned(
              left: k * step + step - softGap / 2,
              top: 0,
              bottom: 0,
              width: softGap.clamp(8.0, 24.0),
              child: _BetweenGap(
                width: softGap.clamp(8.0, 24.0),
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
            ),
        ],
      ),
    );
  }
}

class _HandCard extends StatelessWidget {
  final int index;
  final rummy.Card card;
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
        return Draggable<HandDragPayload>(
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

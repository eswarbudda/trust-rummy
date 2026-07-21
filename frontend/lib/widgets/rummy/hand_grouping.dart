import 'package:flutter/foundation.dart';

import '../../models/card.dart' as rummy;

/// Client-only hand grouping helpers. Break indices are "after card i"
/// (i.e. a gap between cards i and i+1). The game engine never sees these.
class HandGrouping {
  HandGrouping._();

  /// Split [cards] into contiguous groups using [breaksAfterIndex].
  static List<List<rummy.Card>> splitIntoGroups(
    List<rummy.Card> cards,
    Set<int> breaksAfterIndex,
  ) {
    if (cards.isEmpty) return const [];
    final groups = <List<rummy.Card>>[];
    var start = 0;
    for (var i = 0; i < cards.length; i++) {
      final isBreak = breaksAfterIndex.contains(i) || i == cards.length - 1;
      if (isBreak) {
        groups.add(cards.sublist(start, i + 1));
        start = i + 1;
      }
    }
    return groups;
  }

  /// Adjust break indices after removing the card at [removedIndex].
  static Set<int> afterRemove(Set<int> breaks, int removedIndex, int newLength) {
    return breaks
        .where((i) => i != removedIndex)
        .map((i) => i > removedIndex ? i - 1 : i)
        .where((i) => i >= 0 && i < newLength - 1)
        .toSet();
  }

  /// Adjust break indices after moving a card from [from] to [to] (final index).
  static Set<int> afterMove(Set<int> breaks, int from, int to, int length) {
    if (from == to || length < 2) return {...breaks.where((i) => i < length - 1)};
    // Rebuild by mapping old card positions → new positions, then remap breaks.
    final order = List<int>.generate(length, (i) => i);
    final card = order.removeAt(from);
    var insertAt = to.clamp(0, order.length);
    order.insert(insertAt, card);

    final oldToNew = <int, int>{};
    for (var newIdx = 0; newIdx < order.length; newIdx++) {
      oldToNew[order[newIdx]] = newIdx;
    }

    final next = <int>{};
    for (final b in breaks) {
      if (b < 0 || b >= length - 1) continue;
      // Break was between b and b+1. Keep it between the same two cards if both remain adjacent.
      final leftCard = b;
      final rightCard = b + 1;
      final newLeft = oldToNew[leftCard];
      final newRight = oldToNew[rightCard];
      if (newLeft == null || newRight == null) continue;
      if (newRight == newLeft + 1) {
        next.add(newLeft);
      }
      // If the move separated them, the break dissolves (user must re-split).
    }
    return next.where((i) => i < length - 1).toSet();
  }

  /// Toggle a group break after [index] (Split / Merge / Create Group / Ungroup).
  static Set<int> toggleBreak(Set<int> breaks, int index, int handLength) {
    if (index < 0 || index >= handLength - 1) return breaks;
    final next = Set<int>.from(breaks);
    if (!next.add(index)) next.remove(index);
    return next;
  }
}

/// One visual segment of the hand for [HandView].
@immutable
class HandSegment {
  final int startIndex;
  final List<rummy.Card> cards;
  /// PURE_SEQUENCE | SEQUENCE | SET | GROUP | null (singleton / unlabeled).
  final String? kind;

  const HandSegment({
    required this.startIndex,
    required this.cards,
    required this.kind,
  });

  bool get isFormedMeld =>
      kind == 'SET' || kind == 'SEQUENCE' || kind == 'PURE_SEQUENCE';

  /// Labels/trays only apply once the player has created at least one group break.
  bool get showLabel => cards.length >= 2;
}

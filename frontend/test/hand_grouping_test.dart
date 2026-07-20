import 'package:flutter_test/flutter_test.dart';
import 'package:trust_rummy_app/models/card.dart' as rummy;
import 'package:trust_rummy_app/widgets/rummy/hand_grouping.dart';
import 'package:trust_rummy_app/widgets/rummy/hand_view.dart';

void main() {
  group('HandGrouping', () {
    test('splitIntoGroups respects breaks', () {
      final cards = List.generate(
        6,
        (i) => rummy.Card(value: rummy.Value.values[i + 1], suit: rummy.Suit.hearts),
      );
      final groups = HandGrouping.splitIntoGroups(cards, {1, 3});
      expect(groups.map((g) => g.length).toList(), [2, 2, 2]);
    });

    test('toggleBreak creates and removes a group boundary', () {
      var breaks = <int>{};
      breaks = HandGrouping.toggleBreak(breaks, 2, 5);
      expect(breaks, {2});
      breaks = HandGrouping.toggleBreak(breaks, 2, 5);
      expect(breaks, isEmpty);
    });

    test('afterRemove shifts break indices', () {
      final next = HandGrouping.afterRemove({2, 5}, 3, 6);
      expect(next, {2, 4});
    });

    test('afterMove keeps break between same adjacent cards', () {
      // Cards 0-5, break after 2. Move card 5 to index 0.
      final next = HandGrouping.afterMove({2}, 5, 0, 6);
      // Cards that were 2 and 3 should still be adjacent with a break between them.
      expect(next, {3});
    });
  });

  group('manual group classification', () {
    const wild = rummy.Value.six;

    test('seeded mockup groups classify as expected', () {
      final hand = [
        const rummy.Card(value: rummy.Value.ten, suit: rummy.Suit.spades),
        const rummy.Card(value: rummy.Value.jack, suit: rummy.Suit.spades),
        const rummy.Card(value: rummy.Value.queen, suit: rummy.Suit.spades),
        const rummy.Card(value: rummy.Value.king, suit: rummy.Suit.spades),
        const rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.hearts),
        const rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs),
        const rummy.Card(value: rummy.Value.three, suit: rummy.Suit.hearts),
        const rummy.Card(value: rummy.Value.four, suit: rummy.Suit.hearts),
        const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
        const rummy.Card(value: rummy.Value.joker),
        const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.diamonds),
        const rummy.Card(value: rummy.Value.three, suit: rummy.Suit.spades),
        const rummy.Card(value: rummy.Value.five, suit: rummy.Suit.spades),
      ];
      final groups = HandGrouping.splitIntoGroups(hand, {3, 7, 10});
      expect(HandView.classifyGroup(groups[0], wild), 'PURE_SEQUENCE');
      expect(HandView.classifyGroup(groups[1], wild), 'SEQUENCE');
      expect(HandView.classifyGroup(groups[2], wild), 'SET');
      expect(HandView.classifyGroup(groups[3], wild), 'GROUP');
      expect(HandView.meldLabel('GROUP'), 'Invalid Group');
    });
  });
}

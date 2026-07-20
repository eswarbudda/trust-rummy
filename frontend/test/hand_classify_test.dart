import 'package:flutter_test/flutter_test.dart';
import 'package:trust_rummy_app/models/card.dart' as rummy;
import 'package:trust_rummy_app/widgets/rummy/hand_view.dart';

void main() {
  const wild = rummy.Value.six;

  test('pure set of three', () {
    final g = [
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.diamonds),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.clubs),
    ];
    expect(HandView.classifyGroup(g, wild), 'SET');
  });

  test('impure set with one natural and two jokers', () {
    final g = [
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.joker),
      const rummy.Card(value: rummy.Value.joker),
    ];
    expect(HandView.classifyGroup(g, wild), 'SET');
  });

  test('impure set with two naturals and printed joker', () {
    final g = [
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.joker),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.diamonds),
    ];
    expect(HandView.classifyGroup(g, wild), 'SET');
  });

  test('impure set using cut wild as joker', () {
    final g = [
      const rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs), // wild
    ];
    expect(HandView.classifyGroup(g, wild), 'SET');
  });

  test('duplicate suit is not a set', () {
    final g = [
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.clubs),
    ];
    expect(HandView.classifyGroup(g, wild), 'GROUP');
  });

  test('impure sequence fills internal gap', () {
    final g = [
      const rummy.Card(value: rummy.Value.ace, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.six, suit: rummy.Suit.clubs), // wild
      const rummy.Card(value: rummy.Value.three, suit: rummy.Suit.hearts),
      const rummy.Card(value: rummy.Value.four, suit: rummy.Suit.hearts),
    ];
    expect(HandView.classifyGroup(g, wild), 'SEQUENCE');
  });

  test('impure sequence may extend with leftover jokers', () {
    const cut = rummy.Value.two;
    final g = [
      const rummy.Card(value: rummy.Value.five, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.six, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.seven, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.joker),
    ];
    expect(HandView.classifyGroup(g, cut), 'SEQUENCE');
  });

  test('pure sequence', () {
    final g = [
      const rummy.Card(value: rummy.Value.ten, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.jack, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.queen, suit: rummy.Suit.spades),
      const rummy.Card(value: rummy.Value.king, suit: rummy.Suit.spades),
    ];
    expect(HandView.classifyGroup(g, wild), 'PURE_SEQUENCE');
  });
}

/// The four standard card suits. Printed jokers have no suit
/// (see [Card.isPrintedJoker]).
enum Suit {
  spades,
  hearts,
  diamonds,
  clubs;

  String get shortCode {
    switch (this) {
      case Suit.spades:
        return 'S';
      case Suit.hearts:
        return 'H';
      case Suit.diamonds:
        return 'D';
      case Suit.clubs:
        return 'C';
    }
  }

  static Suit? fromWire(String? name) {
    if (name == null) return null;
    return Suit.values.firstWhere(
      (s) => s.name.toUpperCase() == name.toUpperCase(),
    );
  }
}

/// The face value of a card, plus the printed [Value.joker]. This only
/// carries intrinsic card data (short code, face point value); it does not
/// encode any rummy-specific scoring or meld rules.
enum Value {
  ace(1, 'A'),
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, '10'),
  jack(10, 'J'),
  queen(10, 'Q'),
  king(10, 'K'),
  joker(0, 'JK');

  const Value(this.points, this.shortCode);

  final int points;
  final String shortCode;

  static Value fromWire(String name) {
    return Value.values.firstWhere(
      (v) => v.name.toUpperCase() == name.toUpperCase(),
    );
  }
}

/// A single playing card. Plain, serializable data holder — no shuffling,
/// dealing, or meld/validation logic lives here (that arrives with the game
/// engine in a later phase).
///
/// Printed jokers have `value == Value.joker` and `suit == null`.
class Card {
  final Suit? suit;
  final Value value;

  const Card({required this.value, this.suit});

  bool get isPrintedJoker => value == Value.joker;

  /// Compact wire code, e.g. "AS" (ace of spades), "10H", "JK" (printed joker).
  String get code => isPrintedJoker ? value.shortCode : '${value.shortCode}${suit!.shortCode}';

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      value: Value.fromWire(json['value'] as String),
      suit: Suit.fromWire(json['suit'] as String?),
    );
  }

  /// Parses the compact wire code the live gameplay WebSocket actually
  /// sends (`Card.getCode()` on the backend, e.g. "AS", "10H", "JK") — the
  /// deal snapshot payloads (`hand`, `discardTop`, `cutJokerCard`, meld
  /// `cards[]`) carry cards as these bare strings, not the `{suit,value}`
  /// object shape [Card.fromJson] expects.
  factory Card.fromCode(String code) {
    if (code == Value.joker.shortCode) {
      return const Card(value: Value.joker);
    }
    final suitCode = code.substring(code.length - 1);
    final rankCode = code.substring(0, code.length - 1);
    final suit = Suit.values.firstWhere((s) => s.shortCode == suitCode);
    final value = Value.values.firstWhere((v) => v.shortCode == rankCode);
    return Card(value: value, suit: suit);
  }

  /// Whether this card counts as a joker for meld purposes this deal — a
  /// printed joker, or any card whose rank matches the deal's cut wild
  /// value (`RULES_ENGINE.md` §4). Purely a display hint for highlighting;
  /// real meld validation only ever happens server-side on `DECLARE`.
  bool isWildFor(Value? wildValue) => isPrintedJoker || (wildValue != null && value == wildValue);

  Map<String, dynamic> toJson() => {
        'suit': suit?.name.toUpperCase(),
        'value': value.name.toUpperCase(),
      };

  @override
  String toString() => code;

  @override
  bool operator ==(Object other) =>
      other is Card && other.suit == suit && other.value == value;

  @override
  int get hashCode => Object.hash(suit, value);
}

import 'card.dart';

/// Mirrors the backend's `com.trustrummy.backend.entity.PlayerStatus` enum.
enum PlayerStatus {
  joined,
  ready,
  playing,
  dropped,
  left;

  static PlayerStatus fromWire(String name) {
    return PlayerStatus.values.firstWhere(
      (s) => s.name.toUpperCase() == name.toUpperCase(),
      orElse: () => PlayerStatus.joined,
    );
  }
}

/// In-memory representation of a player seated at a live [GameRoom]. Plain,
/// serializable data holder — draw/discard/turn logic arrives with the game
/// engine in a later phase.
class Player {
  final int? userId;
  final String username;
  final int? seatNumber;
  final List<Card> hand;
  final int score;
  final PlayerStatus status;

  Player({
    this.userId,
    required this.username,
    this.seatNumber,
    List<Card>? hand,
    this.score = 0,
    this.status = PlayerStatus.joined,
  }) : hand = hand ?? [];

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      userId: json['userId'] as int?,
      username: json['username'] as String,
      seatNumber: json['seatNumber'] as int?,
      hand: (json['hand'] as List<dynamic>? ?? [])
          .map((c) => Card.fromJson(c as Map<String, dynamic>))
          .toList(),
      score: json['score'] as int? ?? 0,
      status: PlayerStatus.fromWire(json['status'] as String? ?? 'JOINED'),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'seatNumber': seatNumber,
        'hand': hand.map((c) => c.toJson()).toList(),
        'score': score,
        'status': status.name.toUpperCase(),
      };
}

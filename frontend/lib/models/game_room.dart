import 'card.dart';
import 'player.dart';

/// Mirrors the backend's `com.trustrummy.backend.entity.RoomStatus` enum.
enum RoomStatus {
  waiting,
  inProgress,
  completed,
  cancelled;

  String get wireName {
    switch (this) {
      case RoomStatus.waiting:
        return 'WAITING';
      case RoomStatus.inProgress:
        return 'IN_PROGRESS';
      case RoomStatus.completed:
        return 'COMPLETED';
      case RoomStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static RoomStatus fromWire(String name) {
    switch (name.toUpperCase()) {
      case 'WAITING':
        return RoomStatus.waiting;
      case 'IN_PROGRESS':
        return RoomStatus.inProgress;
      case 'COMPLETED':
        return RoomStatus.completed;
      case 'CANCELLED':
        return RoomStatus.cancelled;
      default:
        return RoomStatus.waiting;
    }
  }
}

/// In-memory, serializable structure describing a live game room's players
/// and card piles. Mirrors the backend's
/// `com.trustrummy.backend.game.model.GameRoom` runtime shape (distinct
/// from the persisted room record returned by the REST API). Plain data
/// holder — no shuffling, dealing, or turn logic lives here (that arrives
/// with the game engine in a later phase).
class GameRoom {
  final String roomCode;
  final String? name;
  final int? maxPlayers;
  final double? stakeAmount;
  final RoomStatus status;
  final List<Player> players;
  final List<Card> drawPile;
  final List<Card> discardPile;

  GameRoom({
    required this.roomCode,
    this.name,
    this.maxPlayers,
    this.stakeAmount,
    this.status = RoomStatus.waiting,
    List<Player>? players,
    List<Card>? drawPile,
    List<Card>? discardPile,
  })  : players = players ?? [],
        drawPile = drawPile ?? [],
        discardPile = discardPile ?? [];

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      roomCode: json['roomCode'] as String,
      name: json['name'] as String?,
      maxPlayers: json['maxPlayers'] as int?,
      stakeAmount: (json['stakeAmount'] as num?)?.toDouble(),
      status: RoomStatus.fromWire(json['status'] as String? ?? 'WAITING'),
      players: (json['players'] as List<dynamic>? ?? [])
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      drawPile: (json['drawPile'] as List<dynamic>? ?? [])
          .map((c) => Card.fromJson(c as Map<String, dynamic>))
          .toList(),
      discardPile: (json['discardPile'] as List<dynamic>? ?? [])
          .map((c) => Card.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'roomCode': roomCode,
        'name': name,
        'maxPlayers': maxPlayers,
        'stakeAmount': stakeAmount,
        'status': status.wireName,
        'players': players.map((p) => p.toJson()).toList(),
        'drawPile': drawPile.map((c) => c.toJson()).toList(),
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
      };
}

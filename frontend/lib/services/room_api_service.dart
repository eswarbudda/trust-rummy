import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// One seated player, as returned by the create/join room endpoints.
class RoomPlayerSummary {
  final int userId;
  final String username;
  final int? seatNumber;

  RoomPlayerSummary({required this.userId, required this.username, this.seatNumber});

  factory RoomPlayerSummary.fromJson(Map<String, dynamic> json) {
    return RoomPlayerSummary(
      userId: json['userId'] as int,
      username: json['username'] as String,
      seatNumber: json['seatNumber'] as int?,
    );
  }
}

/// Result of creating/joining a room via REST, just the fields this test tool needs.
class CreatedRoom {
  final String roomCode;
  final String status;
  final String? gameVariant;
  final List<RoomPlayerSummary> players;

  CreatedRoom({
    required this.roomCode,
    required this.status,
    this.gameVariant,
    this.players = const [],
  });

  factory CreatedRoom.fromJson(Map<String, dynamic> json) {
    return CreatedRoom(
      roomCode: json['roomCode'] as String,
      status: json['status'] as String? ?? 'WAITING',
      gameVariant: json['gameVariant'] as String?,
      players: (json['players'] as List<dynamic>?)
              ?.map((p) => RoomPlayerSummary.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Thin REST client for `POST /api/v1/rooms` (see `RoomController`). Only
/// used here to bootstrap a room so the game WebSocket test screen has a
/// `roomCode` to connect to — no room-browsing/join UI yet.
class RoomApiService {
  Future<CreatedRoom> createRoom({
    required String jwt,
    String name = 'Engine Test Room',
    int maxPlayers = 2,
    double stakeAmount = 0,
    String gameVariant = 'POOL_101',
  }) async {
    final response = await http.post(
      ApiConfig.roomsUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({
        'name': name,
        'maxPlayers': maxPlayers,
        'stakeAmount': stakeAmount,
        'gameVariant': gameVariant,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Create room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Seats the calling user into an existing room. This is the step a
  /// second/third/... browser must do before its game WebSocket connection
  /// counts as a "seated player" — connecting the socket alone does not
  /// seat you, it only opens a channel for broadcasts.
  Future<CreatedRoom> joinRoom({required String jwt, required String roomCode}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.roomsUri}/$roomCode/join'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Join room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

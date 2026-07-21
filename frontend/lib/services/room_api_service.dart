import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// One seated player, as returned by the create/join/get/ready room endpoints.
class RoomPlayerSummary {
  final int userId;
  final String username;
  final int? seatNumber;
  final String? status;

  RoomPlayerSummary({required this.userId, required this.username, this.seatNumber, this.status});

  factory RoomPlayerSummary.fromJson(Map<String, dynamic> json) {
    return RoomPlayerSummary(
      userId: json['userId'] as int,
      username: json['username'] as String,
      seatNumber: json['seatNumber'] as int?,
      status: json['status'] as String?,
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
    /// Only meaningful for DEALS; ignored by the server for POINTS and pool.
    int? dealsPerMatch,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'maxPlayers': maxPlayers,
      'stakeAmount': stakeAmount,
      'gameVariant': gameVariant,
    };
    if (dealsPerMatch != null) {
      body['dealsPerMatch'] = dealsPerMatch;
    }
    final response = await http.post(
      ApiConfig.roomsUri,
      headers: _authHeaders(jwt),
      body: jsonEncode(body),
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
    final response = await http.post(ApiConfig.roomJoinUri(roomCode), headers: _authHeaders(jwt));

    if (response.statusCode != 200) {
      throw Exception('Join room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Room detail incl. seated players — lets a client poll/refresh lobby state without the WebSocket.
  Future<CreatedRoom> getRoom({required String jwt, required String roomCode}) async {
    final response = await http.get(ApiConfig.roomUri(roomCode), headers: _authHeaders(jwt));

    if (response.statusCode != 200) {
      throw Exception('Fetch room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Un-seats the caller from a room that hasn't started yet. If the caller
  /// is the host, the whole room is disbanded server-side.
  Future<void> leaveRoom({required String jwt, required String roomCode}) async {
    final response = await http.post(ApiConfig.roomLeaveUri(roomCode), headers: _authHeaders(jwt));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Leave room failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Host-only: closes a still-waiting room.
  Future<void> cancelRoom({required String jwt, required String roomCode}) async {
    final response = await http.delete(ApiConfig.roomUri(roomCode), headers: _authHeaders(jwt));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Cancel room failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Toggles the caller's ready flag in the lobby (purely informational — START_MATCH doesn't require it).
  Future<CreatedRoom> setReady({required String jwt, required String roomCode, required bool ready}) async {
    final response = await http.put(
      ApiConfig.roomReadyUri(roomCode),
      headers: _authHeaders(jwt),
      body: jsonEncode({'ready': ready}),
    );

    if (response.statusCode != 200) {
      throw Exception('Set ready failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _authHeaders(String jwt) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      };
}

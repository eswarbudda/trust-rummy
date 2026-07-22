import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';

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

/// REST client for `/api/v1/rooms/*`.
///
/// Auth is always [AuthSessionService] via [ApiClient] (refresh on expiry/401).
class RoomApiService {
  RoomApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<CreatedRoom> createRoom({
    String name = 'Engine Test Room',
    int maxPlayers = 6,
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
    final response = await _client.post(ApiConfig.roomsUri, body: body);

    if (response.statusCode != 200) {
      throw Exception('Create room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CreatedRoom> joinRoom({required String roomCode}) async {
    final response = await _client.post(ApiConfig.roomJoinUri(roomCode));

    if (response.statusCode != 200) {
      throw Exception('Join room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CreatedRoom> getRoom({required String roomCode}) async {
    final response = await _client.get(ApiConfig.roomUri(roomCode));

    if (response.statusCode != 200) {
      throw Exception('Fetch room failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> leaveRoom({required String roomCode}) async {
    final response = await _client.post(ApiConfig.roomLeaveUri(roomCode));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Leave room failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> cancelRoom({required String roomCode}) async {
    final response = await _client.delete(ApiConfig.roomUri(roomCode));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Cancel room failed (${response.statusCode}): ${response.body}');
    }
  }

  Future<CreatedRoom> setReady({required String roomCode, required bool ready}) async {
    final response = await _client.put(
      ApiConfig.roomReadyUri(roomCode),
      body: {'ready': ready},
    );

    if (response.statusCode != 200) {
      throw Exception('Set ready failed (${response.statusCode}): ${response.body}');
    }

    return CreatedRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';

/// One seated player, as returned by create/join/get/ready room endpoints.
class RoomPlayerSummary {
  final int userId;
  final String username;
  final int? seatNumber;
  final String? status;

  RoomPlayerSummary({
    required this.userId,
    required this.username,
    this.seatNumber,
    this.status,
  });

  factory RoomPlayerSummary.fromJson(Map<String, dynamic> json) {
    return RoomPlayerSummary(
      userId: json['userId'] as int,
      username: json['username'] as String,
      seatNumber: json['seatNumber'] as int?,
      status: json['status'] as String?,
    );
  }
}

/// Room payload from create/join/get/list (`RoomResponse`).
class CreatedRoom {
  final String roomCode;
  final String status;
  final String? name;
  final String? gameVariant;
  final int? maxPlayers;
  final double? stakeAmount;
  final int? dealsPerMatch;
  final String? visibility;
  final int? sourceGroupId;
  final List<RoomPlayerSummary> players;

  CreatedRoom({
    required this.roomCode,
    required this.status,
    this.name,
    this.gameVariant,
    this.maxPlayers,
    this.stakeAmount,
    this.dealsPerMatch,
    this.visibility,
    this.sourceGroupId,
    this.players = const [],
  });

  factory CreatedRoom.fromJson(Map<String, dynamic> json) {
    return CreatedRoom(
      roomCode: json['roomCode'] as String,
      status: json['status'] as String? ?? 'WAITING',
      name: json['name'] as String?,
      gameVariant: json['gameVariant'] as String?,
      maxPlayers: json['maxPlayers'] as int?,
      stakeAmount: (json['stakeAmount'] as num?)?.toDouble(),
      dealsPerMatch: json['dealsPerMatch'] as int?,
      visibility: json['visibility'] as String?,
      sourceGroupId: json['sourceGroupId'] as int?,
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
    String name = 'Trust Rummy Table',
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

  /// Open WAITING rooms. List payloads do not include `players[]`.
  Future<List<CreatedRoom>> listOpenRooms() async {
    final response = await _client.get(ApiConfig.roomsUri);
    if (response.statusCode != 200) {
      throw Exception('List rooms failed (${response.statusCode}): ${response.body}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => CreatedRoom.fromJson(e as Map<String, dynamic>))
        .toList();
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

    // 204 success; 404/409 mean the seat/room is already gone (host disbanded,
    // match started, etc.) — treat as success so lobby UI can always dismiss.
    if (response.statusCode == 204 ||
        response.statusCode == 200 ||
        response.statusCode == 404 ||
        response.statusCode == 409) {
      return;
    }
    throw Exception('Leave room failed (${response.statusCode}): ${response.body}');
  }

  Future<void> cancelRoom({required String roomCode}) async {
    final response = await _client.delete(ApiConfig.roomUri(roomCode));

    if (response.statusCode == 204 ||
        response.statusCode == 200 ||
        response.statusCode == 409) {
      return;
    }
    throw Exception('Cancel room failed (${response.statusCode}): ${response.body}');
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

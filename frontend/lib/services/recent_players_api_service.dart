import 'dart:convert';

import 'api_client.dart';
import '../config/api_config.dart';

class RecentOpponent {
  RecentOpponent({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.online,
    required this.alreadyFriends,
    required this.matchCount,
    required this.lastPlayedAt,
    this.lastRoomCode,
  });

  final int userId;
  final String username;
  final String displayName;
  final bool online;
  final bool alreadyFriends;
  final int matchCount;
  final DateTime lastPlayedAt;
  final String? lastRoomCode;

  factory RecentOpponent.fromJson(Map<String, dynamic> json) {
    return RecentOpponent(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      displayName: (json['displayName'] as String?) ?? (json['username'] as String),
      online: json['online'] as bool? ?? false,
      alreadyFriends: json['alreadyFriends'] as bool? ?? false,
      matchCount: (json['matchCount'] as num?)?.toInt() ?? 0,
      lastPlayedAt: DateTime.parse(json['lastPlayedAt'] as String),
      lastRoomCode: json['lastRoomCode'] as String?,
    );
  }
}

class RecentPlayersApiService {
  RecentPlayersApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<RecentOpponent>> list({int limit = 30}) async {
    final response = await _client.get(ApiConfig.recentPlayersUri(limit: limit));
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['opponents'] as List<dynamic>? ?? const [])
        .map((e) => RecentOpponent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendFriendRequest(int userId) async {
    final response = await _client.post(ApiConfig.recentPlayerFriendRequestUri(userId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to send friend request'));
    }
  }

  Future<String> inviteAgain(int userId) async {
    final response = await _client.post(ApiConfig.recentPlayerInviteAgainUri(userId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to invite again'));
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return map['roomCode'] as String;
  }

  String _errorMessage(String body, String fallback) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return (map['message'] as String?) ?? (map['error'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

import 'dart:convert';

import 'api_client.dart';
import '../config/api_config.dart';

class FriendUser {
  FriendUser({
    required this.friendshipId,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.online,
    this.friendsSince,
  });

  final int friendshipId;
  final int userId;
  final String username;
  final String displayName;
  final bool online;
  final DateTime? friendsSince;

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      friendshipId: (json['friendshipId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      displayName: (json['displayName'] as String?) ?? (json['username'] as String),
      online: json['online'] as bool? ?? false,
      friendsSince: json['friendsSince'] == null
          ? null
          : DateTime.parse(json['friendsSince'] as String),
    );
  }
}

class FriendRequestItem {
  FriendRequestItem({
    required this.friendshipId,
    required this.direction,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherDisplayName,
    required this.createdAt,
  });

  final int friendshipId;
  final String direction;
  final int otherUserId;
  final String otherUsername;
  final String otherDisplayName;
  final DateTime createdAt;

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) {
    return FriendRequestItem(
      friendshipId: (json['friendshipId'] as num).toInt(),
      direction: json['direction'] as String,
      otherUserId: (json['otherUserId'] as num).toInt(),
      otherUsername: json['otherUsername'] as String,
      otherDisplayName:
          (json['otherDisplayName'] as String?) ?? (json['otherUsername'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FriendRequestsPage {
  FriendRequestsPage({required this.incoming, required this.outgoing});

  final List<FriendRequestItem> incoming;
  final List<FriendRequestItem> outgoing;
}

class FriendsApiService {
  FriendsApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<FriendUser>> listFriends() async {
    final response = await _client.get(ApiConfig.friendsUri);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['friends'] as List<dynamic>? ?? const [])
        .map((e) => FriendUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FriendRequestsPage> listRequests() async {
    final response = await _client.get(ApiConfig.friendsRequestsUri);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final incoming = (map['incoming'] as List<dynamic>? ?? const [])
        .map((e) => FriendRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final outgoing = (map['outgoing'] as List<dynamic>? ?? const [])
        .map((e) => FriendRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return FriendRequestsPage(incoming: incoming, outgoing: outgoing);
  }

  Future<void> sendRequest({String? username, int? userId}) async {
    final body = <String, dynamic>{
      if (username != null && username.isNotEmpty) 'username': username,
      if (userId != null) 'userId': userId,
    };
    final response = await _client.post(ApiConfig.friendsRequestsUri, body: body);
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to send friend request'));
    }
  }

  Future<void> accept(int friendshipId) async {
    final response = await _client.post(ApiConfig.friendRequestAcceptUri(friendshipId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to accept request'));
    }
  }

  Future<void> decline(int friendshipId) async {
    final response = await _client.post(ApiConfig.friendRequestDeclineUri(friendshipId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to decline request'));
    }
  }

  Future<void> unfriend(int userId) async {
    final response = await _client.delete(ApiConfig.friendUri(userId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to remove friend'));
    }
  }

  Future<void> block(int userId) async {
    final response = await _client.post(ApiConfig.friendBlockUri(userId));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to block user'));
    }
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

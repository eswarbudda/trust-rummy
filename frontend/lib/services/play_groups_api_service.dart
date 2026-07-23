import 'dart:convert';

import 'api_client.dart';
import '../config/api_config.dart';

class PlayGroupMember {
  PlayGroupMember({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.role,
    required this.status,
  });

  final int userId;
  final String username;
  final String displayName;
  final String role;
  final String status;

  factory PlayGroupMember.fromJson(Map<String, dynamic> json) {
    return PlayGroupMember(
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      displayName: (json['displayName'] as String?) ?? (json['username'] as String),
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }
}

class PlayGroup {
  PlayGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.ownerUsername,
    required this.status,
    required this.memberCount,
    required this.maxMembers,
    this.members = const [],
  });

  final int id;
  final String name;
  final int ownerId;
  final String? ownerUsername;
  final String status;
  final int memberCount;
  final int maxMembers;
  final List<PlayGroupMember> members;

  factory PlayGroup.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List<dynamic>? ?? const [])
        .map((e) => PlayGroupMember.fromJson(e as Map<String, dynamic>))
        .toList();
    return PlayGroup(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      ownerId: (json['ownerId'] as num).toInt(),
      ownerUsername: json['ownerUsername'] as String?,
      status: json['status'] as String,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? members.length,
      maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 20,
      members: members,
    );
  }
}

class PlayGroupsApiService {
  PlayGroupsApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<PlayGroup>> list() async {
    final response = await _client.get(ApiConfig.playGroupsUri);
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['items'] as List<dynamic>? ?? const [])
        .map((e) => PlayGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PlayGroup> create({required String name, int? maxMembers}) async {
    final response = await _client.post(
      ApiConfig.playGroupsUri,
      body: {
        'name': name,
        if (maxMembers != null) 'maxMembers': maxMembers,
      },
    );
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to create group'));
    }
    return PlayGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PlayGroup> get(int id) async {
    final response = await _client.get(ApiConfig.playGroupUri(id));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to load group'));
    }
    return PlayGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<PlayGroup> addMember(int groupId, {String? username, int? userId}) async {
    final response = await _client.post(
      ApiConfig.playGroupMembersUri(groupId),
      body: {
        if (username != null && username.isNotEmpty) 'username': username,
        if (userId != null) 'userId': userId,
      },
    );
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to add member'));
    }
    return PlayGroup.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteGroup(int id) async {
    final response = await _client.delete(ApiConfig.playGroupUri(id));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to delete group'));
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

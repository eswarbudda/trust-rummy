import 'dart:convert';

import 'api_client.dart';
import '../config/api_config.dart';

class GameInvitation {
  GameInvitation({
    required this.id,
    required this.roomId,
    required this.roomCode,
    this.groupId,
    required this.inviterId,
    required this.inviterUsername,
    required this.inviteeId,
    required this.inviteeUsername,
    required this.inviteeDisplayName,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final int roomId;
  final String roomCode;
  final int? groupId;
  final int inviterId;
  final String? inviterUsername;
  final int inviteeId;
  final String? inviteeUsername;
  final String? inviteeDisplayName;
  final String status;
  final DateTime? expiresAt;

  factory GameInvitation.fromJson(Map<String, dynamic> json) {
    return GameInvitation(
      id: json['id'] as String,
      roomId: (json['roomId'] as num).toInt(),
      roomCode: json['roomCode'] as String,
      groupId: (json['groupId'] as num?)?.toInt(),
      inviterId: (json['inviterId'] as num).toInt(),
      inviterUsername: json['inviterUsername'] as String?,
      inviteeId: (json['inviteeId'] as num).toInt(),
      inviteeUsername: json['inviteeUsername'] as String?,
      inviteeDisplayName: json['inviteeDisplayName'] as String?,
      status: json['status'] as String,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
    );
  }
}

class StartGroupGameResult {
  StartGroupGameResult({
    required this.roomId,
    required this.roomCode,
    required this.groupId,
    required this.groupName,
    required this.invitations,
  });

  final int roomId;
  final String roomCode;
  final int groupId;
  final String groupName;
  final List<GameInvitation> invitations;

  factory StartGroupGameResult.fromJson(Map<String, dynamic> json) {
    return StartGroupGameResult(
      roomId: (json['roomId'] as num).toInt(),
      roomCode: json['roomCode'] as String,
      groupId: (json['groupId'] as num).toInt(),
      groupName: json['groupName'] as String? ?? '',
      invitations: (json['invitations'] as List<dynamic>? ?? const [])
          .map((e) => GameInvitation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InvitationsApiService {
  InvitationsApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<GameInvitation>> listPending() async {
    final response = await _client.get(ApiConfig.invitationsPendingUri);
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to load invitations'));
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['items'] as List<dynamic>? ?? const [])
        .map((e) => GameInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GameInvitation> accept(String id) async {
    final response = await _client.post(ApiConfig.invitationAcceptUri(id));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to accept invitation'));
    }
    return GameInvitation.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GameInvitation> decline(String id) async {
    final response = await _client.post(ApiConfig.invitationDeclineUri(id));
    if (response.statusCode >= 400) {
      throw Exception(_errorMessage(response.body, 'Failed to decline invitation'));
    }
    return GameInvitation.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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

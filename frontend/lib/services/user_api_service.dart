import 'dart:convert';

import '../config/api_config.dart';
import 'api_client.dart';
import 'auth_session_service.dart';

/// Mirrors the backend's `UserProfileResponse` DTO.
class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? displayName;
  final double walletBalance;
  final String role;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    required this.walletBalance,
    required this.role,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      role: json['role'] as String? ?? 'PLAYER',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }
}

/// REST client for `/api/v1/users/*`.
///
/// Auth is always [AuthSessionService] via [ApiClient] (refresh on expiry/401).
class UserApiService {
  UserApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<UserProfile> getProfile() async {
    final response = await _client.get(ApiConfig.profileUri);
    if (response.statusCode != 200) {
      throw Exception('Fetch profile failed (${response.statusCode}): ${response.body}');
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({
    String? displayName,
    String? email,
  }) async {
    final response = await _client.put(
      ApiConfig.profileUri,
      body: {'displayName': displayName, 'email': email},
    );
    if (response.statusCode != 200) {
      throw Exception('Update profile failed (${response.statusCode}): ${response.body}');
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.put(
      ApiConfig.changePasswordUri,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Change password failed (${response.statusCode}): ${response.body}');
    }
    // Server revoked all refresh tokens — drop local credentials (no logout call needed).
    await AuthSessionService.instance.clearLocalSession();
  }
}

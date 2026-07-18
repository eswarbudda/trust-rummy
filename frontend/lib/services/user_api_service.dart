import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

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

/// REST client for `/api/v1/users/*` (see `UserController`).
class UserApiService {
  Future<UserProfile> getProfile(String jwt) async {
    final response = await http.get(ApiConfig.profileUri, headers: _authHeaders(jwt));
    if (response.statusCode != 200) {
      throw Exception('Fetch profile failed (${response.statusCode}): ${response.body}');
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> updateProfile({
    required String jwt,
    String? displayName,
    String? email,
  }) async {
    final response = await http.put(
      ApiConfig.profileUri,
      headers: _authHeaders(jwt),
      body: jsonEncode({'displayName': displayName, 'email': email}),
    );
    if (response.statusCode != 200) {
      throw Exception('Update profile failed (${response.statusCode}): ${response.body}');
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String jwt,
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      ApiConfig.changePasswordUri,
      headers: _authHeaders(jwt),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Change password failed (${response.statusCode}): ${response.body}');
    }
  }

  Map<String, String> _authHeaders(String jwt) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwt',
      };
}

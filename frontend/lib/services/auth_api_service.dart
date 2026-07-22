import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Result of register/login/refresh — mirrors the backend's `AuthResponse` DTO.
class AuthResult {
  final String token;
  final String tokenType;
  final String username;
  final int? expiresInMs;
  final String? refreshToken;

  AuthResult({
    required this.token,
    required this.tokenType,
    required this.username,
    this.expiresInMs,
    this.refreshToken,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      username: json['username'] as String,
      expiresInMs: json['expiresInMs'] as int?,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}

/// REST client for `/api/v1/auth/*` (see `AuthController`).
///
/// Uses raw `http` (not [ApiClient]) on purpose: these endpoints mint or
/// redeem tokens and must not attach a Bearer access token or trigger refresh.
class AuthApiService {
  static final Random _random = Random();

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await http.post(
      ApiConfig.registerUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Register failed (${response.statusCode}): ${response.body}');
    }
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String username, required String password}) async {
    final response = await http.post(
      ApiConfig.loginUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed (${response.statusCode}): ${response.body}');
    }
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Redeems a refresh token (returned by register/login) for a fresh access + refresh token pair.
  Future<AuthResult> refresh({required String refreshToken}) async {
    final response = await http.post(
      ApiConfig.refreshUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 200) {
      throw Exception('Refresh failed (${response.statusCode}): ${response.body}');
    }
    return AuthResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// The access JWT is stateless (no server-side blocklist yet) — this only
  /// revokes the refresh token, if one is supplied.
  Future<void> logout({String? refreshToken}) async {
    final response = await http.post(
      ApiConfig.logoutUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Logout failed (${response.statusCode}): ${response.body}');
    }
  }

  /// Registers a throwaway test account (random username) and returns just
  /// the access token — used by the connectivity test screens that only
  /// need a quick, disposable JWT.
  Future<String> quickRegisterTestUser() async {
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    final username = 'tester_$suffix';
    final result = await register(
      username: username,
      email: '$username@trust-rummy.test',
      password: 'TelemetryTest#123',
      displayName: 'Telemetry Tester',
    );
    return result.token;
  }
}

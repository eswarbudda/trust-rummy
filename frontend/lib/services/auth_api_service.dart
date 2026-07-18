import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Thin REST client used only to bootstrap a disposable JWT for the
/// telemetry test screen (Auth / Wallet / Rooms REST endpoints live on the
/// Java Spring Boot server, see `/backend`).
class AuthApiService {
  static final Random _random = Random();

  /// Registers a throwaway test account (random username) and returns the
  /// JWT issued by the server. This is only meant for the Phase 1
  /// connectivity smoke-test screen; real user auth gets a dedicated flow.
  Future<String> quickRegisterTestUser() async {
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    final username = 'tester_$suffix';
    final email = '$username@trust-rummy.test';
    const password = 'TelemetryTest#123';

    final response = await http.post(
      ApiConfig.registerUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'displayName': 'Telemetry Tester',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Registration failed (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> body = jsonDecode(response.body);
    final token = body['token'] as String?;

    if (token == null || token.isEmpty) {
      throw Exception('Server response did not include a token');
    }

    return token;
  }
}

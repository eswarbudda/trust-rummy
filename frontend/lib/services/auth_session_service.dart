import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'auth_api_service.dart';
import 'auth_session_store.dart';

/// In-memory + secure-storage session for the Flutter client.
///
/// - Persists access/refresh tokens via [AuthSessionStore]
/// - Cold-start [restore] refreshes when access is expired/expiring
/// - Exposes [refreshAccessToken] for 401 retries ([ApiClient]) and WS resume
class AuthSessionService extends ChangeNotifier {
  AuthSessionService({
    AuthApiService? authApi,
    AuthSessionStore? store,
  })  : _authApi = authApi ?? AuthApiService(),
        _store = store ?? AuthSessionStore();

  static final AuthSessionService instance = AuthSessionService();

  final AuthApiService _authApi;
  final AuthSessionStore _store;
  final Random _random = Random();

  String? _accessToken;
  String? _refreshToken;
  String? _username;
  int? _accessExpiresAtMs;
  Future<bool>? _refreshInFlight;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get username => _username;
  bool get isSignedIn => _accessToken != null && _accessToken!.isNotEmpty;

  /// True when access token is missing expiry metadata or within 60s of expiry.
  bool get isAccessExpiringSoon {
    if (_accessExpiresAtMs == null) return _accessToken != null;
    return DateTime.now().millisecondsSinceEpoch >= (_accessExpiresAtMs! - 60000);
  }

  bool get isAccessExpired {
    if (_accessToken == null || _accessToken!.isEmpty) return true;
    if (_accessExpiresAtMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch >= _accessExpiresAtMs!;
  }

  /// Loads tokens from secure storage; refreshes when access is expired/expiring.
  Future<void> restore() async {
    _accessToken = await _store.readAccessToken();
    _refreshToken = await _store.readRefreshToken();
    _username = await _store.readUsername();
    _accessExpiresAtMs = await _store.readAccessExpiresAtMs();

    final hasRefresh = _refreshToken != null && _refreshToken!.isNotEmpty;
    if (hasRefresh && (isAccessExpired || isAccessExpiringSoon || _accessToken == null)) {
      final ok = await refreshAccessToken();
      if (!ok && isAccessExpired) {
        await clearLocalSession();
        return;
      }
    }

    notifyListeners();
  }

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final result = await _authApi.register(
      username: username,
      email: email,
      password: password,
      displayName: displayName,
    );
    await applyAuthResult(result);
    return result;
  }

  Future<AuthResult> login({required String username, required String password}) async {
    final result = await _authApi.login(username: username, password: password);
    await applyAuthResult(result);
    return result;
  }

  /// Registers a throwaway test user and persists the full session (access + refresh).
  Future<AuthResult> quickRegisterTestUser() async {
    final suffix = _random.nextInt(999999).toString().padLeft(6, '0');
    final username = 'tester_$suffix';
    return register(
      username: username,
      email: '$username@trust-rummy.test',
      password: 'TelemetryTest#123',
      displayName: 'Telemetry Tester',
    );
  }

  Future<void> applyAuthResult(AuthResult result) async {
    _accessToken = result.token;
    _refreshToken = result.refreshToken ?? _refreshToken;
    _username = result.username;
    if (result.expiresInMs != null && result.expiresInMs! > 0) {
      _accessExpiresAtMs = DateTime.now().millisecondsSinceEpoch + result.expiresInMs!;
    }
    await _store.save(
      accessToken: result.token,
      username: result.username,
      refreshToken: result.refreshToken,
      expiresInMs: result.expiresInMs,
    );
    notifyListeners();
  }

  /// Dev/test helper: put a manually pasted access token into the session
  /// (refresh may be missing — 401 refresh then fails until a real login).
  Future<void> setAccessTokenForTesting(String token, {String? username}) async {
    _accessToken = token.trim();
    if (username != null && username.isNotEmpty) {
      _username = username;
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      await _store.save(
        accessToken: _accessToken!,
        username: _username ?? 'unknown',
        refreshToken: _refreshToken,
      );
    }
    notifyListeners();
  }

  /// Ensures [ApiClient] has a session access token before authenticated REST.
  ///
  /// Prefer Quick Register / Login (access + refresh). If only a pasted access
  /// JWT is available, loads it into the session (no refresh until full login).
  Future<void> ensureSignedIn({String? pastedAccessToken}) async {
    if (_accessToken != null && _accessToken!.isNotEmpty) return;
    final pasted = pastedAccessToken?.trim();
    if (pasted != null && pasted.isNotEmpty) {
      await setAccessTokenForTesting(pasted);
      return;
    }
    throw Exception('Sign in first (Quick Register / Login)');
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _authApi.logout(refreshToken: refresh);
      }
    } catch (_) {
      // Still clear local session even if the server revoke fails.
    }
    await clearLocalSession();
  }

  /// Drops local credentials without calling the server (e.g. after password
  /// change, when the server already revoked every refresh token).
  Future<void> clearLocalSession() async {
    _accessToken = null;
    _refreshToken = null;
    _username = null;
    _accessExpiresAtMs = null;
    await _store.clear();
    notifyListeners();
  }

  /// Rotates tokens via `/auth/refresh`. Single-flight so parallel 401s share one refresh.
  /// On failure, clears the local session so stale credentials are not reused.
  Future<bool> refreshAccessToken() {
    final existing = _refreshInFlight;
    if (existing != null) return existing;

    final future = _doRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = future;
    return future;
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken ?? await _store.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final result = await _authApi.refresh(refreshToken: refresh);
      await applyAuthResult(result);
      return true;
    } catch (_) {
      await clearLocalSession();
      return false;
    }
  }
}

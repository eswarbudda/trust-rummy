import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session_service.dart';

/// Single authenticated HTTP path for the Flutter client.
///
/// Always uses [AuthSessionService]'s access token. Before each call, refreshes
/// when the access token is expired/expiring and a refresh token exists. On
/// 401, refreshes once and retries. There is no per-call JWT override — that
/// bypassed refresh and caused post-match Create Room failures.
///
/// Unauthenticated auth endpoints (`/api/v1/auth/*`) stay on [AuthApiService]
/// with raw `http` — they mint or redeem tokens and must not send a Bearer.
class ApiClient {
  ApiClient({AuthSessionService? session, http.Client? httpClient})
      : _session = session ?? AuthSessionService.instance,
        _http = httpClient ?? http.Client();

  static final ApiClient instance = ApiClient();

  final AuthSessionService _session;
  final http.Client _http;

  Future<http.Response> get(Uri uri) => _send('GET', uri);

  Future<http.Response> post(Uri uri, {Object? body}) =>
      _send('POST', uri, body: body);

  Future<http.Response> put(Uri uri, {Object? body}) =>
      _send('PUT', uri, body: body);

  Future<http.Response> delete(Uri uri) => _send('DELETE', uri);

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Object? body,
    bool isRetry = false,
  }) async {
    if (!isRetry &&
        _session.refreshToken != null &&
        _session.refreshToken!.isNotEmpty &&
        (_session.isAccessExpired || _session.isAccessExpiringSoon)) {
      await _session.refreshAccessToken();
    }

    final token = _session.accessToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final encodedBody = body == null
        ? null
        : body is String
            ? body
            : jsonEncode(body);

    late http.Response response;
    switch (method) {
      case 'GET':
        response = await _http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _http.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PUT':
        response = await _http.put(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        response = await _http.delete(uri, headers: headers);
        break;
      default:
        throw UnsupportedError('HTTP method $method');
    }

    if (response.statusCode == 401 &&
        !isRetry &&
        _session.refreshToken != null &&
        _session.refreshToken!.isNotEmpty) {
      final refreshed = await _session.refreshAccessToken();
      if (refreshed) {
        return _send(method, uri, body: body, isRetry: true);
      }
    }

    return response;
  }
}

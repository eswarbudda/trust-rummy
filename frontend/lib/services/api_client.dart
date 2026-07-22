import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session_service.dart';

/// HTTP helper that attaches the session Bearer token and retries once on 401
/// after a successful `/auth/refresh`.
class ApiClient {
  ApiClient({AuthSessionService? session, http.Client? httpClient})
      : _session = session ?? AuthSessionService.instance,
        _http = httpClient ?? http.Client();

  static final ApiClient instance = ApiClient();

  final AuthSessionService _session;
  final http.Client _http;

  Future<http.Response> get(Uri uri, {String? accessTokenOverride}) =>
      _send('GET', uri, accessTokenOverride: accessTokenOverride);

  Future<http.Response> post(
    Uri uri, {
    Object? body,
    String? accessTokenOverride,
  }) =>
      _send('POST', uri, body: body, accessTokenOverride: accessTokenOverride);

  Future<http.Response> put(
    Uri uri, {
    Object? body,
    String? accessTokenOverride,
  }) =>
      _send('PUT', uri, body: body, accessTokenOverride: accessTokenOverride);

  Future<http.Response> delete(Uri uri, {String? accessTokenOverride}) =>
      _send('DELETE', uri, accessTokenOverride: accessTokenOverride);

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Object? body,
    String? accessTokenOverride,
    bool isRetry = false,
  }) async {
    // Proactive refresh when the access token is about to expire (avoids a
    // wasted round-trip that would 401). Skip when an override token is forced.
    if (!isRetry &&
        accessTokenOverride == null &&
        _session.refreshToken != null &&
        _session.isAccessExpiringSoon) {
      await _session.refreshAccessToken();
    }
    final effectiveToken = accessTokenOverride ?? _session.accessToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (effectiveToken != null && effectiveToken.isNotEmpty)
        'Authorization': 'Bearer $effectiveToken',
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

    // Do not attempt refresh when the caller forced a specific token, or we
    // already retried, or this is an unauthenticated call.
    if (response.statusCode == 401 &&
        !isRetry &&
        accessTokenOverride == null &&
        _session.refreshToken != null) {
      final refreshed = await _session.refreshAccessToken();
      if (refreshed) {
        return _send(method, uri, body: body, isRetry: true);
      }
    }

    return response;
  }
}

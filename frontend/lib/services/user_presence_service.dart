import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'auth_session_service.dart';
import 'websocket_service.dart';

/// Client for `/ws/user` — registers presence with the backend while signed in.
///
/// Future notification delivery will reuse this socket; MVP only heartbeats
/// and tracks connection state.
class UserPresenceService extends ChangeNotifier {
  UserPresenceService._();

  static final UserPresenceService instance = UserPresenceService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  String? _lastStatus;

  SocketConnectionState get state => _state;
  String? get lastStatus => _lastStatus;
  bool get isConnected => _state == SocketConnectionState.connected;

  /// Connect when a session exists; no-op if already connected.
  Future<void> ensureConnected() async {
    final token = AuthSessionService.instance.accessToken;
    if (token == null || token.isEmpty) {
      await disconnect();
      return;
    }
    if (_state == SocketConnectionState.connected || _state == SocketConnectionState.connecting) {
      return;
    }
    await connect(token);
  }

  Future<void> connect(String jwt) async {
    await disconnect();
    _setState(SocketConnectionState.connecting);
    try {
      final uri = ApiConfig.userWsUri(jwt);
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _setState(SocketConnectionState.error),
        onDone: () {
          _stopHeartbeat();
          _setState(SocketConnectionState.disconnected);
          _lastStatus = null;
          notifyListeners();
        },
      );
      _setState(SocketConnectionState.connected);
      _startHeartbeat();
    } catch (_) {
      _setState(SocketConnectionState.error);
    }
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // ignore
    }
    _channel = null;
    _lastStatus = null;
    if (_state != SocketConnectionState.disconnected) {
      _setState(SocketConnectionState.disconnected);
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type == 'PRESENCE' || type == 'HEARTBEAT_ACK') {
        _lastStatus = map['status'] as String?;
        notifyListeners();
      }
    } catch (_) {
      // ignore malformed frames
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel == null || _state != SocketConnectionState.connected) return;
      _channel!.sink.add(jsonEncode({'type': 'HEARTBEAT'}));
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _setState(SocketConnectionState next) {
    _state = next;
    notifyListeners();
  }
}

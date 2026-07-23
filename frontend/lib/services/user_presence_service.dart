import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'auth_session_service.dart';
import 'notification_api_service.dart';
import 'websocket_service.dart';

/// Client for `/ws/user` — presence + realtime notification frames.
class UserPresenceService extends ChangeNotifier {
  UserPresenceService._();

  static final UserPresenceService instance = UserPresenceService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  final NotificationApiService _notifications = NotificationApiService();

  SocketConnectionState _state = SocketConnectionState.disconnected;
  String? _lastStatus;
  int _unreadCount = 0;
  Map<String, dynamic>? _lastNotification;

  SocketConnectionState get state => _state;
  String? get lastStatus => _lastStatus;
  bool get isConnected => _state == SocketConnectionState.connected;
  int get unreadCount => _unreadCount;
  Map<String, dynamic>? get lastNotification => _lastNotification;

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
      unawaited(refreshUnreadCount());
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
    _lastNotification = null;
    _unreadCount = 0;
    if (_state != SocketConnectionState.disconnected) {
      _setState(SocketConnectionState.disconnected);
    }
  }

  Future<void> refreshUnreadCount() async {
    if (!AuthSessionService.instance.isSignedIn) return;
    try {
      _unreadCount = await _notifications.unreadCount();
      notifyListeners();
    } catch (_) {
      // ignore transient failures
    }
  }

  Future<void> markAllRead() async {
    try {
      _unreadCount = await _notifications.markAllRead();
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type == 'PRESENCE' || type == 'HEARTBEAT_ACK') {
        _lastStatus = map['status'] as String?;
        notifyListeners();
        return;
      }
      if (type == 'NOTIFICATION') {
        _lastNotification = map;
        notifyListeners();
        return;
      }
      if (type == 'NOTIFICATION_COUNT') {
        _unreadCount = (map['unreadCount'] as num?)?.toInt() ?? _unreadCount;
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

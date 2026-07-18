import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

enum SocketConnectionState { disconnected, connecting, connected, error }

class TelemetryEvent {
  final String type;
  final Map<String, dynamic> raw;
  final DateTime receivedAt;

  TelemetryEvent(this.type, this.raw) : receivedAt = DateTime.now();
}

/// Thin wrapper around [WebSocketChannel] dedicated to the real-time
/// telemetry test channel (`/ws/telemetry`). Mirrors, in miniature, the
/// same connection lifecycle the real gameplay WebSocket service will use.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _stateController = StreamController<SocketConnectionState>.broadcast();
  final _eventController = StreamController<TelemetryEvent>.broadcast();
  final _latencyController = StreamController<int>.broadcast();

  SocketConnectionState _state = SocketConnectionState.disconnected;
  Timer? _pingTimer;
  int? _lastPingSentAtMs;

  Stream<SocketConnectionState> get stateStream => _stateController.stream;
  Stream<TelemetryEvent> get eventStream => _eventController.stream;
  Stream<int> get latencyStream => _latencyController.stream;

  SocketConnectionState get state => _state;

  Future<void> connect(String jwt) async {
    _setState(SocketConnectionState.connecting);

    try {
      final uri = ApiConfig.telemetryWsUri(jwt);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          _setState(SocketConnectionState.error);
        },
        onDone: () {
          _setState(SocketConnectionState.disconnected);
          _stopHeartbeat();
        },
      );

      // Optimistically flip to "connected"; the WELCOME payload will
      // confirm the handshake completed on the server side too.
      _setState(SocketConnectionState.connected);
      _startHeartbeat();
    } catch (_) {
      _setState(SocketConnectionState.error);
    }
  }

  void sendPing() {
    if (_channel == null || _state != SocketConnectionState.connected) return;

    _lastPingSentAtMs = DateTime.now().millisecondsSinceEpoch;
    _channel!.sink.add(jsonEncode({
      'type': 'PING',
      'clientTime': _lastPingSentAtMs,
    }));
  }

  void disconnect() {
    _stopHeartbeat();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(SocketConnectionState.disconnected);
  }

  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(message as String);
      final type = decoded['type'] as String? ?? 'UNKNOWN';
      _eventController.add(TelemetryEvent(type, decoded));

      if (type == 'PONG' && _lastPingSentAtMs != null) {
        final latency = DateTime.now().millisecondsSinceEpoch - _lastPingSentAtMs!;
        _latencyController.add(latency);
      }
    } catch (_) {
      _eventController.add(TelemetryEvent('RAW', {'payload': message.toString()}));
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) => sendPing());
    sendPing();
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _setState(SocketConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _eventController.close();
    _latencyController.close();
  }
}

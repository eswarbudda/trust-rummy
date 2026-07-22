import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'auth_session_service.dart';

enum SocketConnectionState { disconnected, connecting, connected, error }

/// Where a DRAW_CARD action pulls its card from. Mirrors the backend's
/// `com.trustrummy.backend.game.ws.DrawSource` enum.
enum GameDrawSource {
  closed,
  open;

  String get wireName => this == GameDrawSource.closed ? 'CLOSED' : 'OPEN';
}

/// A single inbound event from `/ws/game/{roomCode}`.
class GameSocketEvent {
  final String type;
  final Map<String, dynamic> raw;
  final DateTime receivedAt;

  GameSocketEvent(this.type, this.raw) : receivedAt = DateTime.now();
}

/// WebSocket controller for `/ws/game/{roomCode}`.
///
/// When [resumeWithSession] is true (default), an unexpected disconnect
/// triggers one access-token refresh + reconnect attempt.
class GameWebSocketService {
  GameWebSocketService({AuthSessionService? session}) : _session = session ?? AuthSessionService.instance;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final AuthSessionService _session;
  final _stateController = StreamController<SocketConnectionState>.broadcast();
  final _eventController = StreamController<GameSocketEvent>.broadcast();
  final _rawController = StreamController<String>.broadcast();

  SocketConnectionState _state = SocketConnectionState.disconnected;
  String? _roomCode;
  bool _intentionalDisconnect = false;
  bool _resumeAttempted = false;
  bool _resumeWithSession = true;

  Stream<SocketConnectionState> get stateStream => _stateController.stream;
  Stream<GameSocketEvent> get eventStream => _eventController.stream;

  /// Raw JSON text exactly as it arrives on the wire — feeds the audit board.
  Stream<String> get rawStream => _rawController.stream;

  SocketConnectionState get state => _state;
  String? get roomCode => _roomCode;

  Future<void> connect(
    String roomCode,
    String jwt, {
    bool resumeWithSession = true,
  }) async {
    _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    _roomCode = roomCode;
    _resumeWithSession = resumeWithSession;
    _intentionalDisconnect = false;
    _resumeAttempted = false;
    _setState(SocketConnectionState.connecting);

    try {
      final uri = ApiConfig.gameWsUri(roomCode, jwt);
      final channel = WebSocketChannel.connect(uri);

      await channel.ready;

      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (_) => _onUnexpectedClose(),
        onDone: _onUnexpectedClose,
      );

      _setState(SocketConnectionState.connected);
    } catch (_) {
      _channel = null;
      _setState(SocketConnectionState.error);
    }
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setState(SocketConnectionState.disconnected);
  }

  Future<void> _onUnexpectedClose() async {
    if (_intentionalDisconnect) {
      _setState(SocketConnectionState.disconnected);
      return;
    }

    if (_resumeWithSession && !_resumeAttempted && _roomCode != null) {
      _resumeAttempted = true;
      _setState(SocketConnectionState.connecting);
      final refreshed = await _session.refreshAccessToken();
      final token = _session.accessToken;
      if (refreshed && token != null && token.isNotEmpty) {
        // Fresh connect resets resumeAttempted so a later drop can try once more.
        await connect(_roomCode!, token, resumeWithSession: _resumeWithSession);
        return;
      }
    }

    _setState(SocketConnectionState.disconnected);
  }

  // ---- Typed action senders — RULES_ENGINE.md section 9 ("Inbound") ----

  void startMatch() => _send({'type': 'START_MATCH'});

  void drawCard(GameDrawSource source) => _send({
        'type': 'DRAW_CARD',
        'source': source.wireName,
      });

  void discardCard(String cardCode) => _send({
        'type': 'DISCARD_CARD',
        'cardCode': cardCode,
      });

  void declare(String cardCode) => _send({
        'type': 'DECLARE',
        'cardCode': cardCode,
      });

  void drop() => _send({'type': 'DROP'});

  void startNextDeal() => _send({'type': 'START_NEXT_DEAL'});

  void leaveTable() => _send({'type': 'LEAVE_TABLE'});

  void _send(Map<String, dynamic> action) {
    if (_channel == null || _state != SocketConnectionState.connected) {
      _eventController.add(GameSocketEvent('CLIENT_ERROR', {
        'message': 'Not connected — action "${action['type']}" was not sent',
      }));
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(action));
    } catch (e) {
      _setState(SocketConnectionState.error);
      _eventController.add(GameSocketEvent('CLIENT_ERROR', {
        'message': 'Failed to send action "${action['type']}": $e',
      }));
    }
  }

  void _handleMessage(dynamic message) {
    final raw = message.toString();
    _rawController.add(raw);

    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      final type = decoded['type'] as String? ?? 'UNKNOWN';
      _eventController.add(GameSocketEvent(type, decoded));
    } catch (_) {
      _eventController.add(GameSocketEvent('UNPARSEABLE', {'payload': raw}));
    }
  }

  void _setState(SocketConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _eventController.close();
    _rawController.close();
  }
}

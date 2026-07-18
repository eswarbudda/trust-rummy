import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

enum SocketConnectionState { disconnected, connecting, connected, error }

/// Where a DRAW_CARD action pulls its card from. Mirrors the backend's
/// `com.trustrummy.backend.game.ws.DrawSource` enum.
enum GameDrawSource {
  closed,
  open;

  String get wireName => this == GameDrawSource.closed ? 'CLOSED' : 'OPEN';
}

/// A single inbound event from `/ws/game/{roomCode}`.
///
/// Note: the backend does not emit a single generic `GAME_STATE_UPDATE`
/// type — per `RULES_ENGINE.md` section 9 it emits distinct types
/// (`ROOM_STATE`, `DEAL_STARTED`, `TURN_STATE`, `CARD_DRAWN`,
/// `CARD_DISCARDED`, `PLAYER_DROPPED`, `DECLARE_RESULT`, `SCORE_UPDATE`,
/// `PLAYER_ELIMINATED`, `MATCH_ENDED`, `ERROR`) that all flow through this
/// same parsed-event pipeline; [type] tells you which one this is.
class GameSocketEvent {
  final String type;
  final Map<String, dynamic> raw;
  final DateTime receivedAt;

  GameSocketEvent(this.type, this.raw) : receivedAt = DateTime.now();
}

/// WebSocket controller for the real gameplay channel
/// (`/ws/game/{roomCode}`). Deliberately raw/minimal for this phase: it
/// connects, sends typed action envelopes, and exposes both a parsed
/// event stream and the exact raw-JSON-string stream (for a traffic audit
/// board) — no card-graphics-aware state modeling yet, per design.
class GameWebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  final _stateController = StreamController<SocketConnectionState>.broadcast();
  final _eventController = StreamController<GameSocketEvent>.broadcast();
  final _rawController = StreamController<String>.broadcast();

  SocketConnectionState _state = SocketConnectionState.disconnected;
  String? _roomCode;

  Stream<SocketConnectionState> get stateStream => _stateController.stream;
  Stream<GameSocketEvent> get eventStream => _eventController.stream;

  /// Raw JSON text exactly as it arrives on the wire — feeds the audit board.
  Stream<String> get rawStream => _rawController.stream;

  SocketConnectionState get state => _state;
  String? get roomCode => _roomCode;

  Future<void> connect(String roomCode, String jwt) async {
    _roomCode = roomCode;
    _setState(SocketConnectionState.connecting);

    try {
      final uri = ApiConfig.gameWsUri(roomCode, jwt);
      _channel = WebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _setState(SocketConnectionState.error),
        onDone: () => _setState(SocketConnectionState.disconnected),
      );

      // Optimistic; the first ROOM_STATE payload confirms the server side too.
      _setState(SocketConnectionState.connected);
    } catch (_) {
      _setState(SocketConnectionState.error);
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
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

  void _send(Map<String, dynamic> action) {
    if (_channel == null || _state != SocketConnectionState.connected) {
      return;
    }
    _channel!.sink.add(jsonEncode(action));
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

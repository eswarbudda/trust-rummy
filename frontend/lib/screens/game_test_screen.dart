import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/auth_session_service.dart';
import '../services/game_websocket_service.dart';
import '../services/room_api_service.dart';
import 'rummy_game_screen.dart';

/// Functional (non-visual) connection-verification tool for the Rummy game
/// engine WebSocket. Lets us drive `START_MATCH` / `DRAW_CARD` /
/// `DISCARD_CARD` / `DECLARE` / `DROP` actions by hand and watch the raw
/// event traffic, before any card-dragging UI exists.
///
/// To test with 2+ players: on tab #1, "Quick Register" then "Create Room
/// (host)" — this auto-seats the host. Copy the generated room code into
/// tab #2 (a separate browser/incognito window so it gets its own JWT), hit
/// "Quick Register" then "Join Room (2nd+ player)" there. Only once both
/// users are seated (shown as chips) will the host's "Start Match" succeed
/// — connecting the game socket alone does NOT seat you, it only opens a
/// channel for broadcasts.
class GameTestScreen extends StatefulWidget {
  const GameTestScreen({super.key});

  @override
  State<GameTestScreen> createState() => _GameTestScreenState();
}

class _GameTestScreenState extends State<GameTestScreen> {
  final _session = AuthSessionService.instance;
  final _roomApi = RoomApiService();
  final _gameWs = GameWebSocketService();

  final _tokenController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _cardCodeController = TextEditingController();
  final _scrollController = ScrollController();

  final List<String> _rawLog = [];
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  bool _busy = false;
  String? _errorMessage;
  String? _lastEventType;
  List<RoomPlayerSummary> _seatedPlayers = [];
  bool _isReady = false;

  /// Room variant for Create Room — backend defaults to POOL_101 if omitted.
  String _selectedVariant = 'POOL_101';

  /// Variant locked in for the current room (from create/join/get). Null until a room exists.
  String? _roomVariant;

  static const _variants = <({String value, String label})>[
    (value: 'POOL_101', label: 'Pool 101'),
    (value: 'POOL_201', label: 'Pool 201'),
    (value: 'POINTS', label: 'Points'),
    (value: 'DEALS', label: 'Deals'),
  ];

  String get _variantLabel {
    final code = _roomVariant ?? _selectedVariant;
    for (final v in _variants) {
      if (v.value == code) return v.label;
    }
    return code;
  }

  /// Surfaced prominently (separately from [_errorMessage], which is only
  /// for REST/setup failures) whenever an `ERROR` (server-rejected action,
  /// e.g. "It is not your turn") or `CLIENT_ERROR` (the socket wasn't
  /// actually open when we tried to send) event arrives on the game
  /// socket. Previously these either required scrolling the raw traffic
  /// log to notice, or — for the client-side case — never existed at all.
  String? _wsErrorMessage;

  /// From the JWT's `sub` claim — lets us work out which seated player is
  /// "me" so we can show whose turn it actually is next to the action
  /// buttons, instead of just guessing and getting a silent-looking
  /// "It is not your turn" rejection.
  String? _myUsername;
  int? _currentTurnUserId;

  /// Latest deal-bearing snapshot JSON — seeded into [RummyGameScreen] when
  /// opening the table mid-deal (or right after `DEAL_STARTED`).
  Map<String, dynamic>? _lastDealJson;

  /// True while [RummyGameScreen] is on top of this lobby (shared socket).
  bool _tableOpen = false;

  @override
  void initState() {
    super.initState();
    _hydrateSession();
    _gameWs.stateStream.listen((state) {
      setState(() => _connectionState = state);
    });
    _gameWs.eventStream.listen((event) {
      setState(() {
        _lastEventType = event.type;
        if (event.type == 'ERROR' || event.type == 'CLIENT_ERROR') {
          _wsErrorMessage = event.raw['message']?.toString() ?? 'Unknown error';
          return;
        }
        _wsErrorMessage = null;

        // Both the pre-match ROOM_STATE shape and the in-deal snapshot shape
        // carry userId/username/seatNumber among other fields, so this same
        // mapping works for either — RoomPlayerSummary.fromJson just ignores
        // the extra keys (cumulativeScore, handSize, etc.) it doesn't need.
        final playersField = event.raw['players'];
        if (playersField is List) {
          _seatedPlayers = playersField
              .whereType<Map<String, dynamic>>()
              .map(RoomPlayerSummary.fromJson)
              .toList();
        }
        final turnUserId = event.raw['currentTurnUserId'];
        if (turnUserId is int) {
          _currentTurnUserId = turnUserId;
        }

        final isDealEvent = event.type == 'DEAL_STARTED' ||
            event.type == 'TURN_STATE' ||
            event.type == 'CARD_DRAWN' ||
            event.type == 'CARD_DISCARDED' ||
            event.type == 'PLAYER_DROPPED' ||
            (event.type == 'ROOM_STATE' && DealSnapshot.hasDealFields(event.raw));
        if (isDealEvent) {
          _lastDealJson = Map<String, dynamic>.from(event.raw);
        }
      });

      if (event.type == 'DEAL_STARTED' && !_tableOpen && mounted) {
        _openLiveTable();
      }
    });
    _gameWs.rawStream.listen((raw) {
      setState(() {
        _rawLog.add(raw);
        if (_rawLog.length > 300) _rawLog.removeAt(0);
      });
      _scrollToBottom();
    });
  }

  Future<void> _hydrateSession() async {
    await _session.restore();
    if (!mounted) return;
    if (_session.accessToken != null) {
      _tokenController.text = _session.accessToken!;
    }
    if (_session.username != null) {
      _myUsername = _session.username;
    }
    setState(() {});
  }

  Future<void> _openLiveTable() async {
    if (!_connected || _tableOpen) return;
    final roomCode = _roomCodeController.text.trim();
    if (roomCode.isEmpty) return;

    _tableOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RummyGameScreen(
          gameWs: _gameWs,
          roomCode: roomCode,
          myUserId: _myUserId,
          myUsername: _myUsername,
          initialDealJson: _lastDealJson,
          gameVariantLabel: _variantLabel,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _tableOpen = false;
      // Prefer the service's live state — lobby `_connectionState` may lag
      // one frame behind the stream after Play Again disconnects.
      if (_gameWs.state != SocketConnectionState.connected) {
        _clearFinishedRoomLobby();
      }
    });
  }

  /// Drops seat/variant lock from a finished (or abandoned) room without
  /// requiring Leave/Cancel REST — those only succeed while status is WAITING.
  void _clearFinishedRoomLobby() {
    _seatedPlayers = [];
    _isReady = false;
    _roomVariant = null;
    _lastDealJson = null;
    _currentTurnUserId = null;
    _roomCodeController.clear();
  }

  /// Decodes the `sub` (username) claim out of the JWT payload — client-side
  /// only, no signature check (the server already validated it at connect
  /// time); this is purely so the UI can label whose turn it is.
  void _decodeMyUsernameFrom(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      _myUsername = payload['sub']?.toString();
    } catch (_) {
      _myUsername = null;
    }
  }

  /// My own seated userId, resolved by matching [_myUsername] against the
  /// last known seated-player list (which carries both userId and username).
  int? get _myUserId {
    if (_myUsername == null) return null;
    for (final p in _seatedPlayers) {
      if (p.username == _myUsername) return p.userId;
    }
    return null;
  }

  bool get _isMyTurn => _myUserId != null && _myUserId == _currentTurnUserId;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _quickRegister() => _run(() async {
        final result = await _session.quickRegisterTestUser();
        _tokenController.text = result.token;
        _myUsername = result.username;
      });

  Future<void> _createRoom() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null) {
          throw Exception('Quick-register (or paste a JWT) first');
        }
        // New room ⇒ must not keep sending actions on a previous room's socket.
        if (_connected) {
          _gameWs.disconnect();
        }
        final dealsPerMatch = _selectedVariant == 'DEALS' ? 2 : null;
        final room = await _roomApi.createRoom(
          jwt: jwt,
          gameVariant: _selectedVariant,
          dealsPerMatch: dealsPerMatch,
        );
        _roomCodeController.text = room.roomCode;
        setState(() {
          _seatedPlayers = room.players;
          _roomVariant = room.gameVariant ?? _selectedVariant;
          _isReady = false;
          _lastDealJson = null;
          _currentTurnUserId = null;
        });
      });

  /// Prefer the live session access token (kept fresh by refresh).
  /// Fall back to the JWT text field only when the session is empty.
  String? get _effectiveJwt {
    final fromSession = _session.accessToken?.trim();
    if (fromSession != null && fromSession.isNotEmpty) return fromSession;
    final fromField = _tokenController.text.trim();
    return fromField.isEmpty ? null : fromField;
  }

  /// Actually seats the current JWT's user into an existing room — needed
  /// on every browser/tab *except* the one that created the room, since
  /// creating already auto-seats the creator. Connecting the WebSocket does
  /// NOT seat you; this REST call is the missing step for "need at least 2
  /// seated players to start".
  Future<void> _joinRoom() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        if (_connected) {
          _gameWs.disconnect();
        }
        final room = await _roomApi.joinRoom(
          jwt: jwt,
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() {
          _seatedPlayers = room.players;
          _roomVariant = room.gameVariant ?? _roomVariant;
        });
      });

  /// Polls the current room's lobby state via REST (no WebSocket needed).
  Future<void> _getRoom() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        final room = await _roomApi.getRoom(
          jwt: jwt,
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() {
          _seatedPlayers = room.players;
          _roomVariant = room.gameVariant ?? _roomVariant;
        });
      });

  /// Un-seats the caller. If the caller is the host, the whole room is disbanded.
  /// After a completed match, REST leave fails (room not WAITING) — still unlock
  /// the lobby locally so a new game type can be chosen.
  Future<void> _leaveRoom() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        try {
          await _roomApi.leaveRoom(
            jwt: jwt,
            roomCode: _roomCodeController.text.trim(),
          );
        } catch (_) {
          // Completed / cancelled rooms reject leave — local reset is enough.
        }
        setState(_clearFinishedRoomLobby);
      });

  /// Host-only: closes a still-waiting room.
  Future<void> _cancelRoom() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        try {
          await _roomApi.cancelRoom(
            jwt: jwt,
            roomCode: _roomCodeController.text.trim(),
          );
        } catch (_) {
          // Same as leave: finished rooms cannot be cancelled via lobby REST.
        }
        setState(_clearFinishedRoomLobby);
      });

  /// Toggles the caller's ready flag. Purely informational — START_MATCH doesn't require it.
  Future<void> _toggleReady() => _run(() async {
        final jwt = _effectiveJwt;
        if (jwt == null || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        final next = !_isReady;
        final room = await _roomApi.setReady(
          jwt: jwt,
          roomCode: _roomCodeController.text.trim(),
          ready: next,
        );
        setState(() {
          _isReady = next;
          _seatedPlayers = room.players;
        });
      });

  Future<void> _connect() => _run(() async {
        if (_roomCodeController.text.isEmpty) {
          throw Exception('Need a JWT and a room code before connecting');
        }
        // Always mint a fresh access JWT before the WS handshake (15m TTL).
        // Prefer session refresh; if that fails, do not reconnect with a stale
        // text-field token — that is what caused "invalid or expired JWT".
        if (_session.refreshToken != null && _session.refreshToken!.isNotEmpty) {
          final refreshed = await _session.refreshAccessToken();
          if (!refreshed) {
            throw Exception(
              'Session expired — Quick Register or log in again, then Connect',
            );
          }
        } else if (_session.accessToken == null || _session.accessToken!.isEmpty) {
          // Manual paste into the JWT field: push it into the session so
          // reconnect / REST callers use the same credential.
          final pasted = _tokenController.text.trim();
          if (pasted.isEmpty) {
            throw Exception('Quick-register (or paste a JWT) first');
          }
          await _session.setAccessTokenForTesting(pasted);
        }
        final jwt = _session.accessToken ?? _effectiveJwt;
        if (jwt == null || jwt.isEmpty) {
          throw Exception('Need a JWT and a room code before connecting');
        }
        _tokenController.text = jwt;
        _decodeMyUsernameFrom(jwt);
        await _gameWs.connect(_roomCodeController.text.trim(), jwt);
        if (_gameWs.state != SocketConnectionState.connected) {
          throw Exception(
            'Game socket handshake rejected — JWT invalid/expired. '
            'Quick Register again (access tokens last 15 minutes).',
          );
        }
      });

  void _disconnect() {
    _gameWs.disconnect();
  }

  bool get _connected => _connectionState == SocketConnectionState.connected;

  void _appendLocalLog(String message) {
    setState(() {
      _rawLog.add(message);
      if (_rawLog.length > 300) _rawLog.removeAt(0);
    });
    _scrollToBottom();
  }

  void _sendStartMatch() {
    final wanted = _roomCodeController.text.trim();
    final live = _gameWs.roomCode;
    if (wanted.isEmpty) {
      setState(() => _wsErrorMessage = 'Enter a room code before Start Match');
      return;
    }
    if (live == null || live != wanted) {
      setState(() => _wsErrorMessage =
          'Socket is on room ${live ?? "(none)"} but UI shows $wanted — Disconnect, then Connect to the new room before Start Match');
      return;
    }
    _gameWs.startMatch();
    _appendLocalLog('>> SENT  {"type":"START_MATCH"}');
  }

  void _sendDraw(GameDrawSource source) {
    _gameWs.drawCard(source);
    _appendLocalLog('>> SENT  {"type":"DRAW_CARD","source":"${source.wireName}"}');
  }

  void _sendDiscard() {
    final code = _cardCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Enter a card code (e.g. "AS", "10H") to discard');
      return;
    }
    _gameWs.discardCard(code);
    _appendLocalLog('>> SENT  {"type":"DISCARD_CARD","cardCode":"$code"}');
  }

  void _sendDeclare() {
    final code = _cardCodeController.text.trim();
    _gameWs.declare(code);
    _appendLocalLog('>> SENT  {"type":"DECLARE","cardCode":"$code"}');
  }

  void _sendDrop() {
    _gameWs.drop();
    _appendLocalLog('>> SENT  {"type":"DROP"}');
  }

  @override
  void dispose() {
    _gameWs.dispose();
    _tokenController.dispose();
    _roomCodeController.dispose();
    _cardCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _statusColor() {
    switch (_connectionState) {
      case SocketConnectionState.connected:
        return Colors.greenAccent;
      case SocketConnectionState.connecting:
        return Colors.amberAccent;
      case SocketConnectionState.error:
        return Colors.redAccent;
      case SocketConnectionState.disconnected:
        return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rummy Engine — Connection Test'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSetupCard(),
                const SizedBox(height: 14),
                _buildActionCard(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
                if (_wsErrorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Game socket rejected the last action: $_wsErrorMessage',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Live traffic audit board',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildAuditBoard()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor()),
              ),
              const SizedBox(width: 8),
              Text(
                _connectionState.name.toUpperCase(),
                style: TextStyle(color: _statusColor(), fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
              if (_lastEventType != null) ...[
                const SizedBox(width: 12),
                Text('last event: $_lastEventType', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tokenController,
            enabled: !_connected,
            decoration: const InputDecoration(labelText: 'JWT token', isDense: true, border: OutlineInputBorder()),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _quickRegister(),
                  child: const Text('Quick Register'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _roomCodeController,
                  enabled: !_connected,
                  decoration: const InputDecoration(labelText: 'Room code', isDense: true, border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Select game type (before Create Room)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in _variants)
                ChoiceChip(
                  label: Text(v.label),
                  selected: _selectedVariant == v.value,
                  // Lock only while the game socket is live (in a match).
                  // A finished room used to leave `_roomVariant` set forever,
                  // which disabled every chip after Play Again → lobby.
                  onSelected: (_busy || _connected)
                      ? null
                      : (selected) {
                          if (!selected) return;
                          setState(() => _selectedVariant = v.value);
                        },
                ),
            ],
          ),
          if (_roomVariant != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.45)),
              ),
              child: Text(
                'Room variant: $_variantLabel (${_roomVariant!})'
                '${_selectedVariant == 'POINTS' || _selectedVariant == 'DEALS' || _roomVariant == 'POINTS' || _roomVariant == 'DEALS' ? ' · 2 deals' : ''}',
                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Selected: $_variantLabel — tap Create Room to use it.',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _createRoom(),
                  child: const Text('Create Room (host)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _joinRoom(),
                  child: const Text('Join Room (2nd+ player)'),
                ),
              ),
            ],
          ),
          if (_seatedPlayers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _seatedPlayers
                  .map((p) => Chip(
                        label: Text(
                          '#${p.seatNumber} ${p.username}${p.status != null ? " (${p.status})" : ""}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Text('Lobby (REST, no socket needed)', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _getRoom(),
                  child: const Text('Get Room'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _toggleReady(),
                  child: Text(_isReady ? 'Un-ready' : 'Set Ready'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _leaveRoom(),
                  child: const Text('Leave Room'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: (_busy || _connected) ? null : () => _cancelRoom(),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Cancel Room (host)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (_busy || _connected) ? null : () => _connect(),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Connect Game Socket'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? _disconnect : null,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Game actions', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          if (_currentTurnUserId != null) _buildTurnIndicator(),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _connected ? _sendStartMatch : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Host: Start Match'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _connected ? _openLiveTable : null,
            icon: const Icon(Icons.table_restaurant_outlined),
            label: Text(_lastDealJson != null ? 'Open table (live deal)' : 'Open table'),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? () => _sendDraw(GameDrawSource.closed) : null,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Draw from Deck'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? () => _sendDraw(GameDrawSource.open) : null,
                  icon: const Icon(Icons.file_download),
                  label: const Text('Draw from Discard'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cardCodeController,
            decoration: const InputDecoration(
              labelText: 'Card code (e.g. AS, 10H, KD, JK for joker)',
              helperText: 'Discard: card to discard. Declare: the 14th card you set aside.',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? _sendDiscard : null,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Discard Selection'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? _sendDeclare : null,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Declare'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _connected ? _sendDrop : null,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Drop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Makes turn ownership explicit so a rejected Draw/Discard reads as
  /// "you clicked out of turn" rather than "the button is broken".
  Widget _buildTurnIndicator() {
    final matches = _seatedPlayers.where((p) => p.userId == _currentTurnUserId);
    final label = matches.isNotEmpty ? matches.first.username : 'user #$_currentTurnUserId';
    final mine = _isMyTurn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (mine ? Colors.greenAccent : Colors.white24).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: mine ? Colors.greenAccent.withOpacity(0.4) : Colors.white24),
      ),
      child: Text(
        mine ? 'Your turn ($label)' : "Waiting on $label's turn",
        style: TextStyle(
          color: mine ? Colors.greenAccent : Colors.white70,
          fontSize: 12,
          fontWeight: mine ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildAuditBoard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: _rawLog.isEmpty
          ? const Center(
              child: Text(
                'No packets yet — connect and send an action above.',
                style: TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              itemCount: _rawLog.length,
              itemBuilder: (context, index) {
                final line = _rawLog[index];
                final isOutbound = line.startsWith('>> SENT');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: isOutbound ? Colors.cyanAccent : Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

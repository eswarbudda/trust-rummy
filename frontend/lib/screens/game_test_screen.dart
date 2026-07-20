import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/auth_api_service.dart';
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
  final _authApi = AuthApiService();
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
        ),
      ),
    );
    if (mounted) setState(() => _tableOpen = false);
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
        final token = await _authApi.quickRegisterTestUser();
        _tokenController.text = token;
      });

  Future<void> _createRoom() => _run(() async {
        if (_tokenController.text.isEmpty) {
          throw Exception('Quick-register (or paste a JWT) first');
        }
        final room = await _roomApi.createRoom(jwt: _tokenController.text);
        _roomCodeController.text = room.roomCode;
        setState(() => _seatedPlayers = room.players);
      });

  /// Actually seats the current JWT's user into an existing room — needed
  /// on every browser/tab *except* the one that created the room, since
  /// creating already auto-seats the creator. Connecting the WebSocket does
  /// NOT seat you; this REST call is the missing step for "need at least 2
  /// seated players to start".
  Future<void> _joinRoom() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        final room = await _roomApi.joinRoom(
          jwt: _tokenController.text.trim(),
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() => _seatedPlayers = room.players);
      });

  /// Polls the current room's lobby state via REST (no WebSocket needed).
  Future<void> _getRoom() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        final room = await _roomApi.getRoom(
          jwt: _tokenController.text.trim(),
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() => _seatedPlayers = room.players);
      });

  /// Un-seats the caller. If the caller is the host, the whole room is disbanded.
  Future<void> _leaveRoom() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        await _roomApi.leaveRoom(
          jwt: _tokenController.text.trim(),
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() {
          _seatedPlayers = [];
          _isReady = false;
        });
      });

  /// Host-only: closes a still-waiting room.
  Future<void> _cancelRoom() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        await _roomApi.cancelRoom(
          jwt: _tokenController.text.trim(),
          roomCode: _roomCodeController.text.trim(),
        );
        setState(() => _seatedPlayers = []);
      });

  /// Toggles the caller's ready flag. Purely informational — START_MATCH doesn't require it.
  Future<void> _toggleReady() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Quick-register and enter a room code first');
        }
        final room = await _roomApi.setReady(
          jwt: _tokenController.text.trim(),
          roomCode: _roomCodeController.text.trim(),
          ready: !_isReady,
        );
        setState(() {
          _isReady = !_isReady;
          _seatedPlayers = room.players;
        });
      });

  Future<void> _connect() => _run(() async {
        if (_tokenController.text.isEmpty || _roomCodeController.text.isEmpty) {
          throw Exception('Need a JWT and a room code before connecting');
        }
        _decodeMyUsernameFrom(_tokenController.text.trim());
        await _gameWs.connect(_roomCodeController.text.trim(), _tokenController.text.trim());
        if (_gameWs.state != SocketConnectionState.connected) {
          throw Exception('Game socket did not confirm connection (handshake rejected — check the JWT is still valid)');
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
          const SizedBox(height: 8),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lobby/lobby_controller.dart';
import '../lobby/lobby_models.dart';
import '../services/auth_session_service.dart';
import '../services/game_websocket_service.dart';
import '../services/room_api_service.dart';
import 'rummy_game_screen.dart';

/// Dedicated waiting room after create/join. Owns table seating UI + host start.
class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({
    super.key,
    required this.lobby,
    required this.roomCode,
    required this.isHost,
    this.initialRoom,
  });

  final LobbyController lobby;
  final String roomCode;
  final bool isHost;
  final CreatedRoom? initialRoom;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  final _session = AuthSessionService.instance;
  final _gameWs = GameWebSocketService();

  CreatedRoom? _room;
  String? _error;
  bool _busy = false;
  bool _openingTable = false;
  bool _exiting = false;
  Timer? _pollTimer;
  StreamSubscription<GameSocketEvent>? _eventSub;
  Map<String, dynamic>? _lastDealJson;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _eventSub?.cancel();
    // Keep socket if navigating to table; disconnect when leaving waiting room.
    if (!_openingTable) {
      _gameWs.disconnect();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_exiting || _openingTable) return;
    try {
      final room = await widget.lobby.refreshRoom(widget.roomCode);
      if (!mounted || _exiting) return;
      setState(() {
        _room = room;
        _error = null;
      });
      final status = room.status.toUpperCase();
      if (status == 'CANCELLED' || status == 'COMPLETED' || status == 'ABORTED') {
        await _exitBecauseRoomClosed(
          status == 'CANCELLED'
              ? 'Host left — this room was cancelled.'
              : 'This room is no longer available.',
        );
        return;
      }
      if (status == 'IN_PROGRESS' && !_openingTable) {
        await _ensureConnectedAndOpenTable();
      }
    } catch (e) {
      if (!mounted || _exiting) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _exitBecauseRoomClosed(String message) async {
    if (_exiting || !mounted) return;
    _exiting = true;
    _pollTimer?.cancel();
    await widget.lobby.clearFinishedRoom(widget.roomCode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  Future<void> _ensureConnectedAndOpenTable() async {
    if (_openingTable) return;
    await _connectSocket();
    if (_gameWs.state == SocketConnectionState.connected) {
      await _openTable();
    }
  }

  Future<void> _connectSocket() async {
    await _session.ensureSignedIn();
    if (_session.refreshToken != null && _session.refreshToken!.isNotEmpty) {
      await _session.refreshAccessToken();
    }
    final jwt = _session.accessToken;
    if (jwt == null || jwt.isEmpty) {
      throw Exception('Session expired — sign in again');
    }
    _eventSub?.cancel();
    _eventSub = _gameWs.eventStream.listen((event) {
      if (event.type == 'DEAL_STARTED' || event.type == 'TURN_STATE' || event.type == 'ROOM_STATE') {
        if (event.raw['dealNumber'] != null || event.raw['players'] is List) {
          _lastDealJson = event.raw;
        }
        final matchStatus = event.raw['matchStatus']?.toString().toUpperCase();
        if (matchStatus == 'CANCELLED' && mounted && !_openingTable && !_exiting) {
          _exitBecauseRoomClosed('Host left — this room was cancelled.');
        }
      }
      if (event.type == 'DEAL_STARTED' && mounted && !_openingTable) {
        _openTable();
      }
      if (event.type == 'ERROR' && mounted) {
        setState(() => _error = event.raw['message']?.toString() ?? 'Server error');
      }
    });
    await _gameWs.connect(widget.roomCode, jwt);
    if (_gameWs.state != SocketConnectionState.connected) {
      throw Exception('Could not connect game socket');
    }
  }

  Future<void> _startMatch() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _connectSocket();
      _gameWs.startMatch();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openTable() async {
    if (!mounted || _openingTable || _exiting) return;
    _openingTable = true;
    _pollTimer?.cancel();
    final room = _room;
    final myUsername = _session.username;
    int? myUserId;
    if (myUsername != null && room != null) {
      for (final p in room.players) {
        if (p.username == myUsername) {
          myUserId = p.userId;
          break;
        }
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RummyGameScreen(
          gameWs: _gameWs,
          roomCode: widget.roomCode,
          myUserId: myUserId,
          myUsername: myUsername,
          initialDealJson: _lastDealJson,
          gameVariantLabel: LobbyVariants.labelFor(room?.gameVariant),
        ),
      ),
    );
    await widget.lobby.clearFinishedRoom(widget.roomCode);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _leave() async {
    if (_busy || _exiting) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.ensureSignedIn();
      if (_session.refreshToken != null && _session.refreshToken!.isNotEmpty) {
        if (_session.isAccessExpired || _session.isAccessExpiringSoon) {
          await _session.refreshAccessToken();
        }
      }
      if (widget.isHost) {
        try {
          await widget.lobby.cancelRoom(widget.roomCode);
        } catch (_) {
          // Host may already have disbanded via leave; fall through to leave.
          await widget.lobby.leaveRoom(widget.roomCode);
        }
      } else {
        await widget.lobby.leaveRoom(widget.roomCode);
      }
      if (mounted && !_exiting) {
        _exiting = true;
        _pollTimer?.cancel();
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Still leave the UI if the seat is already gone / session flake —
      // otherwise guests get stuck after host cancel.
      if (mounted && !_exiting) {
        _exiting = true;
        _pollTimer?.cancel();
        await widget.lobby.clearFinishedRoom(widget.roomCode);
        if (mounted) Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final players = room?.players ?? const <RoomPlayerSummary>[];
    final canStart = widget.isHost && players.length >= 2 && !_busy;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _exiting || _openingTable) return;
        await _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Waiting · ${widget.roomCode}'),
          actions: [
            IconButton(
              tooltip: 'Copy room code',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: widget.roomCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Room code copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    LobbyVariants.labelFor(room?.gameVariant),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share code ${widget.roomCode} with friends. '
                    '${room?.maxPlayers != null ? "Max ${room!.maxPlayers} players." : ""}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 24),
                  Text('Seated players', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  if (players.isEmpty)
                    const Text('Loading seats…', style: TextStyle(color: Colors.white54))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in players)
                          Chip(
                            label: Text('#${p.seatNumber ?? '?'} ${p.username}${p.seatNumber == 0 ? " (host)" : ""}'),
                          ),
                      ],
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const Spacer(),
                  if (widget.isHost)
                    FilledButton.icon(
                      onPressed: canStart ? _startMatch : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_busy ? 'Starting…' : 'Start Match'),
                    )
                  else
                    const Text(
                      'Waiting for the host to start the match…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _busy ? null : _leave,
                    child: Text(widget.isHost ? 'Cancel room' : 'Leave room'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../lobby/lobby_controller.dart';
import '../lobby/lobby_models.dart';
import '../services/auth_session_service.dart';
import '../services/game_websocket_service.dart';
import '../services/room_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Waiting · ${widget.roomCode}', style: LobbyText.body(size: 16, weight: FontWeight.w700)),
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
              icon: const Icon(Icons.copy_rounded, color: LobbyColors.gold),
            ),
          ],
        ),
        body: ScreenBackground.lobby(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      LobbyVariants.labelFor(room?.gameVariant),
                      style: LobbyText.brand(size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share code ${widget.roomCode} — gather the table! '
                      '${room?.maxPlayers != null ? "Max ${room!.maxPlayers} players." : ""}',
                      style: LobbyText.bodyMuted(),
                    ),
                    const SizedBox(height: 24),
                    LobbyPanel(
                      borderColor: LobbyColors.feltBright.withValues(alpha: 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AT THE TABLE', style: LobbyText.label(size: 11)),
                          const SizedBox(height: 12),
                          if (players.isEmpty)
                            Text('Dealing seats…', style: LobbyText.bodyMuted())
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final p in players)
                                  Chip(
                                    backgroundColor: (p.seatNumber == 0 ? LobbyColors.chipYellow : LobbyColors.feltBright)
                                        .withValues(alpha: 0.22),
                                    side: BorderSide(
                                      color: (p.seatNumber == 0 ? LobbyColors.chipYellow : LobbyColors.feltBright)
                                          .withValues(alpha: 0.65),
                                    ),
                                    label: Text(
                                      '${p.seatNumber == 0 ? "👑 " : ""}${p.username}',
                                      style: LobbyText.body(size: 12, weight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: LobbyText.body(color: LobbyColors.cardRed)),
                    ],
                    const Spacer(),
                    if (widget.isHost)
                      FilledButton.icon(
                        onPressed: canStart ? _startMatch : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: LobbyColors.chipYellow,
                          foregroundColor: LobbyColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(_busy ? 'Shuffling…' : 'Start Match'),
                      )
                    else
                      Text(
                        'Waiting for the host to start… 🃏',
                        textAlign: TextAlign.center,
                        style: LobbyText.bodyMuted(),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _busy ? null : _leave,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LobbyColors.cream,
                        side: BorderSide(color: LobbyColors.chipYellow.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(widget.isHost ? 'Cancel room' : 'Leave room'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

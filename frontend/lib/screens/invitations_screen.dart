import 'package:flutter/material.dart';

import '../lobby/lobby_controller.dart';
import '../services/invitations_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
import 'waiting_room_screen.dart';

class InvitationsScreen extends StatefulWidget {
  const InvitationsScreen({super.key});

  @override
  State<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends State<InvitationsScreen> {
  final InvitationsApiService _api = InvitationsApiService();
  final LobbyController _lobby = LobbyController();

  List<GameInvitation> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lobby.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listPending();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _accept(GameInvitation invite) async {
    try {
      final accepted = await _api.accept(invite.id);
      final room = await _lobby.refreshRoom(accepted.roomCode);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WaitingRoomScreen(
            lobby: _lobby,
            roomCode: room.roomCode,
            isHost: false,
            initialRoom: room,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _decline(GameInvitation invite) async {
    try {
      await _api.decline(invite.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ScreenBackground.lobby(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: LobbyColors.cream),
                    ),
                    Expanded(child: Text('Invitations', style: LobbyText.brand(size: 26))),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, color: LobbyColors.gold),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_error!, style: LobbyText.body(color: LobbyColors.coral)),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: LobbyColors.gold))
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              'No pending room invitations.',
                              style: LobbyText.bodyMuted(),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final invite = _items[index];
                              return LobbyPanel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '@${invite.inviterUsername ?? 'host'} invited you',
                                      style: LobbyText.body(weight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Room ${invite.roomCode}'
                                      '${invite.groupId != null ? ' · from a play group' : ''}',
                                      style: LobbyText.bodyMuted(size: 12),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _decline(invite),
                                            child: const Text('Decline'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _accept(invite),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: LobbyColors.gold,
                                              foregroundColor: LobbyColors.ink,
                                            ),
                                            child: const Text('Accept'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

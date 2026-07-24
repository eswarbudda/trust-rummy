import 'package:flutter/material.dart';

import '../lobby/lobby_controller.dart';
import '../services/invitations_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
import '../widgets/lobby/soft_hover_row.dart';
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
      body: ScreenBackground.social(
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
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final invite = _items[index];
                                  return SoftHoverRow(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '@${invite.inviterUsername ?? 'host'} invited you',
                                                style: LobbyText.body(
                                                  weight: FontWeight.w800,
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Room ${invite.roomCode}'
                                                '${invite.groupId != null ? ' · from a play group' : ''}',
                                                style: LobbyText.bodyMuted(size: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => _decline(invite),
                                          style: TextButton.styleFrom(
                                            foregroundColor: LobbyColors.creamMuted,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Decline'),
                                        ),
                                        const SizedBox(width: 4),
                                        TextButton(
                                          onPressed: () => _accept(invite),
                                          style: TextButton.styleFrom(
                                            foregroundColor: LobbyColors.gold,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Accept',
                                            style: LobbyText.body(
                                              weight: FontWeight.w800,
                                              size: 14,
                                              color: LobbyColors.gold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

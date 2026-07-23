import 'package:flutter/material.dart';

import '../lobby/lobby_controller.dart';
import '../services/auth_session_service.dart';
import '../services/room_api_service.dart';
import '../widgets/lobby/active_tables_section.dart';
import '../widgets/lobby/create_table_dialog.dart';
import '../widgets/lobby/game_variant_card.dart';
import '../widgets/lobby/join_room_dialog.dart';
import '../widgets/lobby/lobby_header.dart';
import '../widgets/lobby/lobby_side_menu.dart';
import '../widgets/lobby/recent_games_section.dart';
import '../widgets/lobby/resume_match_section.dart';
import '../widgets/common/screen_background.dart';
import '../theme/lobby_theme.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'recent_players_screen.dart';
import 'waiting_room_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late final LobbyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LobbyController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCreate({String initialVariant = 'POOL_101'}) async {
    final result = await CreateTableDialog.show(context, initialVariant: initialVariant);
    if (result == null || !mounted) return;
    try {
      final room = await _controller.createRoom(
        gameVariant: result.gameVariant,
        maxPlayers: result.maxPlayers,
        stakeAmount: result.stakeAmount,
        dealsPerMatch: result.dealsPerMatch,
      );
      if (!mounted) return;
      await _openWaiting(room, isHost: true);
      await _controller.load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openJoin([String? presetCode]) async {
    final code = presetCode ?? await JoinRoomDialog.show(context);
    if (code == null || !mounted) return;
    try {
      final room = await _controller.joinRoom(code);
      if (!mounted) return;
      await _openWaiting(room, isHost: false);
      await _controller.load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openWaiting(CreatedRoom room, {required bool isHost}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WaitingRoomScreen(
          lobby: _controller,
          roomCode: room.roomCode,
          isHost: isHost,
          initialRoom: room,
        ),
      ),
    );
  }

  Future<void> _resume() async {
    final info = _controller.resumeMatch;
    if (info == null) return;
    try {
      final room = await _controller.refreshRoom(info.roomCode);
      final me = AuthSessionService.instance.username;
      final isHost = room.players.any((p) => p.username == me && p.seatNumber == 0);
      if (!mounted) return;
      await _openWaiting(room, isHost: isHost);
      await _controller.load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      await _controller.load();
    }
  }

  void _openFriends() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
    );
  }

  void _openRecentPlayers() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const RecentPlayersScreen()),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.developer_mode),
                title: const Text('Dev tools'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _controller.logout();
                  if (context.mounted) {
                    // AuthGate rebuilds via session notify.
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sideMenu({required bool compact}) {
    return LobbySideMenu(
      compact: compact,
      onCreateTable: () => _openCreate(),
      onJoinWithCode: () => _openJoin(),
      onFriends: _openFriends,
      onRecentPlayers: _openRecentPlayers,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: AuthSessionService.instance,
          builder: (context, _) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: ScreenBackground.lobby(
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wideMenu = constraints.maxWidth >= 900;
                      final showSideMenu = constraints.maxWidth >= 640;
                      final menuCompact = showSideMenu && !wideMenu;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showSideMenu) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                              child: SingleChildScrollView(
                                child: _sideMenu(compact: menuCompact),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: RefreshIndicator(
                              color: LobbyColors.gold,
                              backgroundColor: LobbyColors.inkSoft,
                              onRefresh: _controller.load,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 960),
                                  child: CustomScrollView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    slivers: [
                                      SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                                        sliver: SliverList(
                                          delegate: SliverChildListDelegate([
                                            LobbyHeader(
                                              controller: _controller,
                                              onSettings: _openSettings,
                                            ),
                                            if (!showSideMenu) ...[
                                              const SizedBox(height: 20),
                                              _sideMenu(compact: false),
                                            ],
                                            const SizedBox(height: 28),
                                            if (_controller.loading && _controller.profile == null)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 48),
                                                child: Center(
                                                  child: CircularProgressIndicator(color: LobbyColors.gold),
                                                ),
                                              )
                                            else ...[
                                              if (_controller.errorMessage != null) ...[
                                                LobbyPanel(
                                                  borderColor: LobbyColors.coral.withValues(alpha: 0.5),
                                                  child: Text(
                                                    _controller.errorMessage!,
                                                    style: LobbyText.body(color: LobbyColors.coral),
                                                  ),
                                                ),
                                                const SizedBox(height: 14),
                                              ],
                                              if (_controller.resumeMatch != null) ...[
                                                ResumeMatchSection(
                                                  info: _controller.resumeMatch!,
                                                  onResume: _resume,
                                                ),
                                                const SizedBox(height: 28),
                                              ],
                                              GameVariantsSection(
                                                onSelectVariant: (v) => _openCreate(initialVariant: v),
                                              ),
                                              const SizedBox(height: 28),
                                              ActiveTablesSection(
                                                rooms: _controller.openRooms,
                                                onJoin: (room) => _openJoin(room.roomCode),
                                              ),
                                              const SizedBox(height: 28),
                                              RecentGamesSection(
                                                matches: _controller.recentMatches,
                                                myUsername: AuthSessionService.instance.username,
                                                page: _controller.historyPage,
                                                totalPages: _controller.historyTotalPages,
                                                totalElements: _controller.historyTotalElements,
                                                loading: _controller.historyLoading,
                                                onPrev: _controller.historyHasPrev
                                                    ? _controller.historyPrev
                                                    : null,
                                                onNext: _controller.historyHasNext
                                                    ? _controller.historyNext
                                                    : null,
                                              ),
                                            ],
                                          ]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../lobby/lobby_controller.dart';
import '../services/play_groups_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
import '../widgets/lobby/create_table_dialog.dart';
import 'waiting_room_screen.dart';

class PlayGroupsScreen extends StatefulWidget {
  const PlayGroupsScreen({super.key});

  @override
  State<PlayGroupsScreen> createState() => _PlayGroupsScreenState();
}

class _PlayGroupsScreenState extends State<PlayGroupsScreen> {
  final PlayGroupsApiService _api = PlayGroupsApiService();
  final LobbyController _lobby = LobbyController();

  List<PlayGroup> _groups = const [];
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
      final groups = await _api.list();
      if (!mounted) return;
      setState(() {
        _groups = groups;
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

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text('Create play group', style: LobbyText.body(weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LobbyText.body(),
          decoration: InputDecoration(
            hintText: 'Group name',
            hintStyle: LobbyText.bodyMuted(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await _api.create(name: name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openGroup(PlayGroup group) async {
    try {
      final detail = await _api.get(group.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: LobbyColors.inkSoft,
        showDragHandle: true,
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(detail.name, style: LobbyText.brand(size: 24)),
                  const SizedBox(height: 4),
                  Text(
                    '${detail.memberCount}/${detail.maxMembers} members · owner @${detail.ownerUsername ?? '?'}',
                    style: LobbyText.bodyMuted(),
                  ),
                  const SizedBox(height: 16),
                  ...detail.members.map(
                    (m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.displayName, style: LobbyText.body(weight: FontWeight.w700)),
                      subtitle: Text('@${m.username} · ${m.role}', style: LobbyText.bodyMuted(size: 12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _addMember(detail.id);
                    },
                    style: FilledButton.styleFrom(backgroundColor: LobbyColors.gold, foregroundColor: LobbyColors.ink),
                    child: const Text('Add friend'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _startGame(detail);
                    },
                    child: const Text('Start game'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _startGame(PlayGroup group) async {
    final result = await CreateTableDialog.show(context);
    if (result == null || !mounted) return;
    try {
      final started = await _api.startGame(
        groupId: group.id,
        name: group.name,
        gameVariant: result.gameVariant,
        maxPlayers: result.maxPlayers,
        stakeAmount: result.stakeAmount,
        dealsPerMatch: result.dealsPerMatch,
      );
      final room = await _lobby.refreshRoom(started.roomCode);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WaitingRoomScreen(
            lobby: _lobby,
            roomCode: room.roomCode,
            isHost: true,
            initialRoom: room,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addMember(int groupId) async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text('Add friend by username', style: LobbyText.body(weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LobbyText.body(),
          decoration: InputDecoration(hintText: 'Username', hintStyle: LobbyText.bodyMuted()),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (username == null || username.isEmpty || !mounted) return;
    try {
      await _api.addMember(groupId, username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added @$username')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: LobbyColors.gold,
        foregroundColor: LobbyColors.ink,
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('New group'),
      ),
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
                    Expanded(child: Text('Play groups', style: LobbyText.brand(size: 26))),
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
                    : _groups.isEmpty
                        ? Center(
                            child: Text(
                              'No play groups yet — create one and add friends.',
                              style: LobbyText.bodyMuted(),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: _groups.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              return LobbyPanel(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  onTap: () => _openGroup(group),
                                  title: Text(group.name, style: LobbyText.body(weight: FontWeight.w800)),
                                  subtitle: Text(
                                    '${group.memberCount}/${group.maxMembers} members',
                                    style: LobbyText.bodyMuted(size: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: LobbyColors.gold),
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

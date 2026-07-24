import 'package:flutter/material.dart';

import '../lobby/lobby_controller.dart';
import '../services/auth_session_service.dart';
import '../services/play_groups_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
import '../widgets/lobby/create_table_dialog.dart';
import '../widgets/lobby/soft_hover_row.dart';
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
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: LobbyPanel(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                borderColor: (AuthSessionService.instance.username != null &&
                        AuthSessionService.instance.username == detail.ownerUsername)
                    ? LobbyColors.groupOwned
                    : LobbyColors.gold.withValues(alpha: 0.45),
                child: _PlayGroupDetailBody(
                  initial: detail,
                  api: _api,
                  onClose: () => Navigator.pop(ctx),
                  onStartGame: (g) async {
                    Navigator.pop(ctx);
                    await _startGame(g);
                  },
                  onAddMember: (groupId) async {
                    Navigator.pop(ctx);
                    await _addMember(groupId);
                  },
                ),
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
    final result = await CreateTableDialog.show(
      context,
      hidePlayerCount: true,
      title: 'Start group game',
      confirmLabel: 'Invite & open table',
    );
    if (result == null || !mounted) return;
    try {
      final started = await _api.startGame(
        groupId: group.id,
        name: group.name,
        gameVariant: result.gameVariant,
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
        title: Text('Invite friend by username', style: LobbyText.body(weight: FontWeight.w700)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite sent to @$username')));
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
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                                itemCount: _groups.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final group = _groups[index];
                                  final me = AuthSessionService.instance.username;
                                  final owned = me != null && me == group.ownerUsername;
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: owned
                                            ? LobbyColors.groupOwned
                                            : LobbyColors.cream.withValues(alpha: 0.12),
                                        width: owned ? 1.6 : 1,
                                      ),
                                      color: owned
                                          ? LobbyColors.groupOwned.withValues(alpha: 0.1)
                                          : LobbyColors.ink.withValues(alpha: 0.25),
                                    ),
                                    child: SoftHoverRow(
                                      onTap: () => _openGroup(group),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        group.name,
                                                        style: LobbyText.body(
                                                          weight: FontWeight.w800,
                                                          size: 14,
                                                          color: owned
                                                              ? LobbyColors.groupOwned
                                                              : LobbyColors.cream,
                                                        ),
                                                      ),
                                                    ),
                                                    if (owned) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: LobbyColors.groupOwned,
                                                          borderRadius: BorderRadius.circular(99),
                                                        ),
                                                        child: Text(
                                                          'Yours',
                                                          style: LobbyText.body(
                                                            size: 10,
                                                            weight: FontWeight.w800,
                                                            color: LobbyColors.ink,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '${group.memberCount}/${group.maxMembers} members',
                                                  style: LobbyText.bodyMuted(size: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: owned ? LobbyColors.groupOwned : LobbyColors.gold,
                                          ),
                                        ],
                                      ),
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

class _PlayGroupDetailBody extends StatefulWidget {
  const _PlayGroupDetailBody({
    required this.initial,
    required this.api,
    required this.onClose,
    required this.onStartGame,
    required this.onAddMember,
  });

  final PlayGroup initial;
  final PlayGroupsApiService api;
  final VoidCallback onClose;
  final Future<void> Function(PlayGroup group) onStartGame;
  final Future<void> Function(int groupId) onAddMember;

  @override
  State<_PlayGroupDetailBody> createState() => _PlayGroupDetailBodyState();
}

class _PlayGroupDetailBodyState extends State<_PlayGroupDetailBody> {
  late PlayGroup _group;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _group = widget.initial;
  }

  bool get _isOwner {
    final me = AuthSessionService.instance.username;
    return me != null && me == _group.ownerUsername;
  }

  Future<void> _removeMember(PlayGroupMember member) async {
    final leavingSelf = member.username == AuthSessionService.instance.username;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text(
          leavingSelf ? 'Leave group?' : 'Remove member?',
          style: LobbyText.body(weight: FontWeight.w700),
        ),
        content: Text(
          leavingSelf
              ? 'You will leave ${_group.name}.'
              : 'Remove @${member.username} from ${_group.name}?',
          style: LobbyText.bodyMuted(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(leavingSelf ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await widget.api.removeMember(_group.id, member.userId);
      if (!mounted) return;
      if (leavingSelf) {
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left ${_group.name}')),
        );
        return;
      }
      setState(() {
        _group = updated;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed @${member.username}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(_group.name, style: LobbyText.brand(size: 22))),
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: LobbyColors.cream),
            ),
          ],
        ),
        Text(
          '${_group.memberCount}/${_group.maxMembers} members · owner @${_group.ownerUsername ?? '?'}',
          style: LobbyText.bodyMuted(size: 12),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _group.members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final m = _group.members[index];
              final action = _memberAction(m);
              return SoftHoverRow(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.displayName, style: LobbyText.body(weight: FontWeight.w700, size: 13)),
                          Text(
                            m.status == 'PENDING'
                                ? '@${m.username} · Pending invite'
                                : '@${m.username} · ${m.role}',
                            style: LobbyText.bodyMuted(size: 11),
                          ),
                        ],
                      ),
                    ),
                    if (action != null) action,
                  ],
                ),
              );
            },
          ),
        ),
        if (_isOwner) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => widget.onAddMember(_group.id),
                  child: const Text('Invite member'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => widget.onStartGame(_group),
                  style: FilledButton.styleFrom(
                    backgroundColor: LobbyColors.gold,
                    foregroundColor: LobbyColors.ink,
                  ),
                  child: const Text('Start game'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _memberAction(PlayGroupMember member) {
    if (member.role == 'OWNER') return null;
    final me = AuthSessionService.instance.username;
    final isSelf = me != null && member.username == me;
    if (!_isOwner && !isSelf) return null;

    return IconButton(
      tooltip: isSelf ? 'Leave group' : 'Remove from group',
      visualDensity: VisualDensity.compact,
      onPressed: _busy ? null : () => _removeMember(member),
      icon: Icon(
        isSelf ? Icons.logout_rounded : Icons.person_remove_rounded,
        color: LobbyColors.coral,
        size: 20,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/notification_api_service.dart';
import '../services/play_groups_api_service.dart';
import '../services/user_presence_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';
import '../widgets/lobby/soft_hover_row.dart';
import 'friends_screen.dart';
import 'invitations_screen.dart';
import 'play_groups_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationApiService _api = NotificationApiService();

  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;

  static const _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.list(size: 50);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
      await UserPresenceService.instance.refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Format: DD Month YYYY HH:MM:SS (local time).
  String _formatSentAt(DateTime utcOrLocal) {
    final t = utcOrLocal.toLocal();
    final dd = t.day.toString().padLeft(2, '0');
    final month = _months[t.month - 1];
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$dd $month ${t.year} $hh:$mm:$ss';
  }

  String _title(AppNotification n) {
    switch (n.type) {
      case 'FRIEND_REQUEST':
        final from = n.payload['fromUsername'] ?? n.payload['username'];
        return from != null ? 'Friend request from @$from' : 'Friend request';
      case 'FRIEND_ACCEPTED':
        final who = n.payload['username'];
        return who != null ? '@$who accepted your friend request' : 'Friend request accepted';
      case 'GROUP_INVITATION':
        final from = n.payload['inviterUsername'];
        return from != null ? 'Group game invite from @$from' : 'Group game invitation';
      case 'GROUP_MEMBER_INVITE':
        final event = n.payload['event'];
        if (event == 'ACCEPTED') {
          final who = n.payload['username'];
          final group = n.payload['groupName'];
          if (who != null && group != null) return '@$who joined $group';
          return 'Someone joined your play group';
        }
        final from = n.payload['inviterUsername'];
        final group = n.payload['groupName'];
        if (from != null && group != null) return '@$from invited you to $group';
        return 'Play group invitation';
      case 'ROOM_INVITATION':
        final event = n.payload['event'];
        if (event == 'ACCEPTED') {
          final who = n.payload['username'];
          return who != null ? '@$who accepted your room invite' : 'Invitation accepted';
        }
        final from = n.payload['inviterUsername'];
        return from != null ? 'Room invite from @$from' : 'Room invitation';
      default:
        return n.type.replaceAll('_', ' ');
    }
  }

  String _subtitle(AppNotification n) {
    final sent = _formatSentAt(n.createdAt);
    final room = n.payload['roomCode'];
    if (room is String && room.isNotEmpty) {
      return '$sent · Room $room';
    }
    final group = n.payload['groupName'];
    if (group is String && group.isNotEmpty && n.type == 'GROUP_MEMBER_INVITE') {
      return '$sent · $group';
    }
    return sent;
  }

  Future<void> _handleGroupMemberInvite(AppNotification n) async {
    final event = n.payload['event'];
    if (event == 'ACCEPTED') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PlayGroupsScreen()),
      );
      return;
    }
    final groupId = (n.payload['groupId'] as num?)?.toInt();
    final groupName = n.payload['groupName'] as String? ?? 'this group';
    if (groupId == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text('Join $groupName?', style: LobbyText.body(weight: FontWeight.w700)),
        content: Text(
          '@${n.payload['inviterUsername'] ?? 'Someone'} invited you to this play group.',
          style: LobbyText.bodyMuted(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'decline'), child: const Text('Decline')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'accept'), child: const Text('Accept')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    final api = PlayGroupsApiService();
    try {
      if (choice == 'accept') {
        await api.acceptMemberInvite(groupId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined $groupName')),
        );
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PlayGroupsScreen()),
        );
      } else {
        await api.declineMemberInvite(groupId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite declined')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _open(AppNotification n) async {
    try {
      if (n.status == 'UNREAD') {
        await _api.markRead(n.id);
        await UserPresenceService.instance.refreshUnreadCount();
      }
    } catch (_) {
      // still navigate
    }
    if (!mounted) return;

    switch (n.type) {
      case 'FRIEND_REQUEST':
      case 'FRIEND_ACCEPTED':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const FriendsScreen(initialTab: 1),
          ),
        );
        break;
      case 'GROUP_MEMBER_INVITE':
        await _handleGroupMemberInvite(n);
        break;
      case 'GROUP_INVITATION':
      case 'ROOM_INVITATION':
        final event = n.payload['event'];
        if (event != 'ACCEPTED') {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const InvitationsScreen()),
          );
        }
        break;
      default:
        break;
    }
    await _load();
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
                    Expanded(child: Text('Notifications', style: LobbyText.brand(size: 26))),
                    IconButton(
                      tooltip: 'Mark all read',
                      onPressed: () async {
                        await UserPresenceService.instance.markAllRead();
                        await _load();
                      },
                      icon: const Icon(Icons.done_all_rounded, color: LobbyColors.gold),
                    ),
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
                            child: Text('No notifications yet.', style: LobbyText.bodyMuted()),
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final n = _items[index];
                                  final unread = n.status == 'UNREAD';
                                  return DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: unread
                                          ? LobbyColors.gold.withValues(alpha: 0.16)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: unread
                                          ? Border.all(
                                              color: LobbyColors.gold.withValues(alpha: 0.55),
                                              width: 1.2,
                                            )
                                          : null,
                                    ),
                                    child: SoftHoverRow(
                                      highlight: unread,
                                      onTap: () => _open(n),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 36,
                                            margin: const EdgeInsets.only(right: 10, top: 2),
                                            decoration: BoxDecoration(
                                              color: unread ? LobbyColors.gold : Colors.transparent,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _title(n),
                                                        style: LobbyText.body(
                                                          size: 14,
                                                          weight: unread
                                                              ? FontWeight.w800
                                                              : FontWeight.w600,
                                                          color: unread
                                                              ? LobbyColors.gold
                                                              : LobbyColors.cream,
                                                        ),
                                                      ),
                                                    ),
                                                    if (unread)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: LobbyColors.gold,
                                                          borderRadius: BorderRadius.circular(99),
                                                        ),
                                                        child: Text(
                                                          'Unread',
                                                          style: LobbyText.body(
                                                            size: 10,
                                                            weight: FontWeight.w800,
                                                            color: LobbyColors.ink,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  _subtitle(n),
                                                  style: LobbyText.bodyMuted(size: 11),
                                                ),
                                              ],
                                            ),
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

import 'package:flutter/material.dart';

import '../services/friends_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  final FriendsApiService _api = FriendsApiService();
  late final TabController _tabs;

  List<FriendUser> _friends = const [];
  FriendRequestsPage _requests = FriendRequestsPage(incoming: const [], outgoing: const []);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await _api.listFriends();
      final requests = await _api.listRequests();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _requests = requests;
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

  Future<void> _sendRequest() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text('Add friend', style: LobbyText.body(weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: LobbyText.body(),
          decoration: InputDecoration(
            hintText: 'Username',
            hintStyle: LobbyText.bodyMuted(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (username == null || username.isEmpty || !mounted) return;
    try {
      await _api.sendRequest(username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to $username')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _accept(FriendRequestItem item) async {
    try {
      await _api.accept(item.friendshipId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _decline(FriendRequestItem item) async {
    try {
      await _api.decline(item.friendshipId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _unfriend(FriendUser friend) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LobbyColors.inkSoft,
        title: Text('Remove ${friend.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.unfriend(friend.userId);
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendRequest,
        backgroundColor: LobbyColors.chipMaroon,
        foregroundColor: LobbyColors.cream,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add friend'),
      ),
      body: ScreenBackground.lobby(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: LobbyColors.cream),
                    ),
                    Expanded(
                      child: Text('Friends', style: LobbyText.brand(size: 28)),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, color: LobbyColors.chipYellow),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelColor: LobbyColors.chipYellow,
                unselectedLabelColor: LobbyColors.creamMuted,
                indicatorColor: LobbyColors.feltBright,
                tabs: [
                  Tab(text: 'Friends (${_friends.length})'),
                  Tab(
                    text:
                        'Requests (${_requests.incoming.length + _requests.outgoing.length})',
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: LobbyText.body(color: LobbyColors.coral)),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: LobbyColors.gold))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _FriendsList(friends: _friends, onUnfriend: _unfriend),
                          _RequestsList(
                            requests: _requests,
                            onAccept: _accept,
                            onDecline: _decline,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({required this.friends, required this.onUnfriend});

  final List<FriendUser> friends;
  final Future<void> Function(FriendUser) onUnfriend;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return Center(
        child: Text('No friends yet — add someone by username.', style: LobbyText.bodyMuted()),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final friend = friends[index];
        return LobbyPanel(
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: LobbyColors.cream,
                foregroundColor: LobbyColors.ink,
                child: Text(friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.displayName, style: LobbyText.body(weight: FontWeight.w700)),
                    Text(
                      '@${friend.username} · ${friend.online ? 'Online' : 'Offline'}',
                      style: LobbyText.bodyMuted(size: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove friend',
                onPressed: () => onUnfriend(friend),
                icon: const Icon(Icons.person_remove_alt_1_rounded, color: LobbyColors.coral),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequestsPage requests;
  final Future<void> Function(FriendRequestItem) onAccept;
  final Future<void> Function(FriendRequestItem) onDecline;

  @override
  Widget build(BuildContext context) {
    final items = [
      ...requests.incoming,
      ...requests.outgoing,
    ];
    if (items.isEmpty) {
      return Center(
        child: Text('No pending requests.', style: LobbyText.bodyMuted()),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final incoming = item.direction == 'INCOMING';
        return LobbyPanel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.otherDisplayName,
                      style: LobbyText.body(weight: FontWeight.w700),
                    ),
                    Text(
                      incoming
                          ? '@${item.otherUsername} wants to be friends'
                          : 'Outgoing to @${item.otherUsername}',
                      style: LobbyText.bodyMuted(size: 12),
                    ),
                  ],
                ),
              ),
              if (incoming) ...[
                TextButton(onPressed: () => onDecline(item), child: const Text('Decline')),
                TextButton(onPressed: () => onAccept(item), child: const Text('Accept')),
              ],
            ],
          ),
        );
      },
    );
  }
}

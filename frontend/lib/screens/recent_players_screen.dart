import 'package:flutter/material.dart';

import '../services/recent_players_api_service.dart';
import '../theme/lobby_theme.dart';
import '../widgets/common/screen_background.dart';

class RecentPlayersScreen extends StatefulWidget {
  const RecentPlayersScreen({super.key});

  @override
  State<RecentPlayersScreen> createState() => _RecentPlayersScreenState();
}

class _RecentPlayersScreenState extends State<RecentPlayersScreen> {
  final RecentPlayersApiService _api = RecentPlayersApiService();

  List<RecentOpponent> _opponents = const [];
  bool _loading = true;
  String? _error;

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
      final opponents = await _api.list();
      if (!mounted) return;
      setState(() {
        _opponents = opponents;
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

  Future<void> _addFriend(RecentOpponent opponent) async {
    try {
      await _api.sendFriendRequest(opponent.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${opponent.displayName}')),
      );
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
                    Expanded(
                      child: Text('Recent players', style: LobbyText.brand(size: 26)),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loading ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, color: LobbyColors.chipYellow),
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
                    : _opponents.isEmpty
                        ? Center(
                            child: Text(
                              'No recent opponents yet — finish a match to see them here.',
                              style: LobbyText.bodyMuted(),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _opponents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final opponent = _opponents[index];
                              return LobbyPanel(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: LobbyColors.cream,
                                      foregroundColor: LobbyColors.ink,
                                      child: Text(
                                        opponent.displayName.isNotEmpty
                                            ? opponent.displayName[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opponent.displayName,
                                            style: LobbyText.body(weight: FontWeight.w700),
                                          ),
                                          Text(
                                            '@${opponent.username} · '
                                            '${opponent.online ? 'Online' : 'Offline'} · '
                                            '${opponent.matchCount} matches',
                                            style: LobbyText.bodyMuted(size: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (opponent.alreadyFriends)
                                      Text('Friends', style: LobbyText.bodyMuted(size: 12))
                                    else
                                      TextButton(
                                        onPressed: () => _addFriend(opponent),
                                        child: const Text('Add'),
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

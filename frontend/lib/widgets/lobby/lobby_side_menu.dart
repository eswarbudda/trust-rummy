import 'package:flutter/material.dart';

import '../../theme/lobby_theme.dart';

/// Left rail with the lobby quick-action destinations.
class LobbySideMenu extends StatelessWidget {
  const LobbySideMenu({
    super.key,
    required this.onCreateTable,
    required this.onJoinWithCode,
    this.onFriends,
    this.onRecentPlayers,
    this.onPlayGroups,
    this.compact = false,
  });

  final VoidCallback onCreateTable;
  final VoidCallback onJoinWithCode;
  final VoidCallback? onFriends;
  final VoidCallback? onRecentPlayers;
  final VoidCallback? onPlayGroups;
  final bool compact;

  static const double wideWidth = 212;
  static const double compactWidth = 76;

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      const _MenuItem(
        icon: Icons.flash_on_rounded,
        label: 'Quick Join',
        subtitle: 'Soon',
        onTap: null,
        tooltip: 'Coming soon — matchmaking API not available yet',
      ),
      _MenuItem(
        icon: Icons.add_rounded,
        label: 'Create Table',
        subtitle: 'Host',
        onTap: onCreateTable,
      ),
      _MenuItem(
        icon: Icons.vpn_key_rounded,
        label: 'Join Code',
        subtitle: '6-char',
        onTap: onJoinWithCode,
      ),
      _MenuItem(
        icon: Icons.people_alt_rounded,
        label: 'Friends',
        subtitle: 'Social',
        onTap: onFriends,
      ),
      _MenuItem(
        icon: Icons.history_rounded,
        label: 'Recent',
        subtitle: 'Players',
        onTap: onRecentPlayers,
      ),
      _MenuItem(
        icon: Icons.groups_rounded,
        label: 'Groups',
        subtitle: 'Play',
        onTap: onPlayGroups,
      ),
    ];

    return SizedBox(
      width: compact ? compactWidth : wideWidth,
      child: LobbyPanel(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: 14,
        ),
        borderColor: LobbyColors.ink.withValues(alpha: 0.35),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBE9925),
            Color(0xFF9F7F1A),
            Color(0xFF735F13),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text('MENU', style: LobbyText.label(size: 12, color: LobbyColors.cream)),
              const SizedBox(height: 4),
              Text('Quick actions', style: LobbyText.section(size: 28, color: LobbyColors.cream)),
              const SizedBox(height: 14),
            ] else ...[
              Icon(Icons.grid_view_rounded, color: LobbyColors.feltBright, size: 22),
              const SizedBox(height: 12),
            ],
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _SideMenuTile(item: items[i], compact: compact),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final String? tooltip;
}

class _SideMenuTile extends StatelessWidget {
  const _SideMenuTile({required this.item, required this.compact});

  final _MenuItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null;
    final tile = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 10,
            vertical: compact ? 10 : 11,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFC9A634).withValues(alpha: enabled ? 1 : 0.55),
                const Color(0xFFAE7F0A).withValues(alpha: enabled ? 1 : 0.55),
                const Color(0xFF846313).withValues(alpha: enabled ? 0.98 : 0.5),
              ],
            ),
            border: Border.all(
              color: LobbyColors.ink.withValues(alpha: enabled ? 0.4 : 0.2),
              width: 1.4,
            ),
          ),
          child: compact
              ? Column(
                  children: [
                    Icon(
                      item.icon,
                      color: LobbyColors.feltBright.withValues(alpha: enabled ? 1 : 0.55),
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label.split(' ').first,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LobbyText.body(
                        size: 12,
                        weight: FontWeight.w700,
                        color: LobbyColors.cream.withValues(alpha: enabled ? 1 : 0.55),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      item.icon,
                      color: LobbyColors.feltBright.withValues(alpha: enabled ? 1 : 0.55),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: LobbyText.body(
                              size: 15,
                              weight: FontWeight.w800,
                              color: LobbyColors.cream.withValues(alpha: enabled ? 1 : 0.6),
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: LobbyText.body(
                              size: 13,
                              color: LobbyColors.cream.withValues(alpha: enabled ? 0.85 : 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (item.tooltip == null) return tile;
    return Tooltip(message: item.tooltip!, child: tile);
  }
}

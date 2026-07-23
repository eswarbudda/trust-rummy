import 'package:flutter/material.dart';

import '../../theme/lobby_theme.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.onCreateTable,
    required this.onJoinWithCode,
  });

  final VoidCallback onCreateTable;
  final VoidCallback onJoinWithCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LobbySectionTitle('Quick actions', eyebrow: 'Deal me in'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final children = [
              const _ActionCard(
                icon: Icons.flash_on_rounded,
                label: 'Quick Join',
                subtitle: 'Matchmaking soon',
                emoji: '⚡',
                colors: [LobbyColors.feltBright, LobbyColors.felt],
                borderColor: LobbyColors.chipYellow,
                borderWidth: 2.5,
                onPressed: null,
                tooltip: 'Coming soon — matchmaking API not available yet',
              ),
              _ActionCard(
                icon: Icons.add_circle_rounded,
                label: 'Create Table',
                subtitle: 'You host the deal',
                emoji: '🃏',
                colors: const [LobbyColors.chipYellow, LobbyColors.jokerOrange],
                foreground: LobbyColors.ink,
                onPressed: onCreateTable,
              ),
              _ActionCard(
                icon: Icons.login_rounded,
                label: 'Join with Code',
                subtitle: '6-letter room code',
                emoji: '🔑',
                colors: const [LobbyColors.openBlue, LobbyColors.feltBright],
                onPressed: onJoinWithCode,
              ),
            ];
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: children[i]),
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.emoji,
    required this.colors,
    required this.onPressed,
    this.foreground = LobbyColors.cream,
    this.borderColor,
    this.borderWidth = 1.5,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final String emoji;
  final List<Color> colors;
  final Color foreground;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Keep "coming soon" tiles vivid (e.g. Quick Join green) instead of greyed out.
    final showVividWhenDisabled = borderColor != null;
    final fill = enabled || showVividWhenDisabled
        ? colors
        : colors.map((c) => c.withValues(alpha: 0.45)).toList();
    final fgAlpha = enabled || showVividWhenDisabled ? 1.0 : 0.55;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fill,
            ),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: enabled ? 0.18 : 0.08),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: (borderColor ?? colors.first).withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: foreground.withValues(alpha: fgAlpha), size: 26),
                    const Spacer(),
                    Text(emoji, style: TextStyle(fontSize: 20, color: foreground.withValues(alpha: fgAlpha))),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  style: LobbyText.body(
                    size: 16,
                    weight: FontWeight.w800,
                    color: foreground.withValues(alpha: enabled || showVividWhenDisabled ? 1 : 0.65),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: LobbyText.body(
                    size: 12,
                    color: foreground.withValues(alpha: enabled || showVividWhenDisabled ? 0.85 : 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return card;
    return Tooltip(message: tooltip!, child: card);
  }
}

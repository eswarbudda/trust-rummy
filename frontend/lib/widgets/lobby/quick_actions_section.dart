import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/lobby_theme.dart';

/// Quick actions as oversized maroon poker chips.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.onCreateTable,
    required this.onJoinWithCode,
    this.onFriends,
  });

  final VoidCallback onCreateTable;
  final VoidCallback onJoinWithCode;
  final VoidCallback? onFriends;

  static const _chipSize = 138.0;
  static const _chipColors = [LobbyColors.chipMaroon, LobbyColors.chipMaroonDeep];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LobbySectionTitle('Quick actions', eyebrow: 'Deal me in'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final chips = [
              const PokerChipAction(
                label: 'Quick\nJoin',
                subtitle: 'Soon',
                colors: _chipColors,
                rimColor: LobbyColors.cream,
                icon: Icons.flash_on_rounded,
                size: _chipSize,
                onPressed: null,
                tooltip: 'Coming soon — matchmaking API not available yet',
              ),
              PokerChipAction(
                label: 'Create\nTable',
                subtitle: 'Host',
                colors: _chipColors,
                rimColor: LobbyColors.cream,
                icon: Icons.add_rounded,
                size: _chipSize,
                onPressed: onCreateTable,
              ),
              PokerChipAction(
                label: 'Join\nCode',
                subtitle: '6-char',
                colors: _chipColors,
                rimColor: LobbyColors.cream,
                icon: Icons.vpn_key_rounded,
                size: _chipSize,
                onPressed: onJoinWithCode,
              ),
              PokerChipAction(
                label: 'Friends',
                subtitle: 'Social',
                colors: _chipColors,
                rimColor: LobbyColors.cream,
                icon: Icons.people_alt_rounded,
                size: _chipSize,
                onPressed: onFriends,
              ),
            ];

            if (wide) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final c in chips) Expanded(child: Center(child: c)),
                ],
              );
            }
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: chips,
            );
          },
        ),
      ],
    );
  }
}

class PokerChipAction extends StatelessWidget {
  const PokerChipAction({
    super.key,
    required this.label,
    required this.subtitle,
    required this.colors,
    required this.rimColor,
    required this.icon,
    required this.onPressed,
    this.foreground = LobbyColors.cream,
    this.tooltip,
    this.size = 138,
  });

  final String label;
  final String subtitle;
  final List<Color> colors;
  final Color rimColor;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final chip = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            border: Border.all(color: rimColor, width: 4.5),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size * 0.78, size * 0.78),
                painter: _ChipRingPainter(color: rimColor.withValues(alpha: 0.55)),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foreground.withValues(alpha: enabled ? 1 : 0.92), size: 30),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: LobbyText.body(
                      size: 14,
                      weight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: LobbyText.body(
                      size: 11,
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}

class _ChipRingPainter extends CustomPainter {
  _ChipRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Offset.zero & size;
    const dashCount = 16;
    const sweep = (2 * math.pi) / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.45, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChipRingPainter oldDelegate) => oldDelegate.color != color;
}

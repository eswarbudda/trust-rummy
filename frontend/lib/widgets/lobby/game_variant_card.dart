import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../theme/lobby_theme.dart';

class GameVariantCard extends StatelessWidget {
  const GameVariantCard({
    super.key,
    required this.entry,
    this.onTap,
  });

  final ({String value, String label, String description, String players}) entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = LobbyColors.accentForVariant(entry.value);
    final suit = LobbyColors.suitForVariant(entry.value);
    final fill = _fillForVariant(entry.value);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: fill,
            ),
            border: Border.all(color: accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      suit,
                      style: TextStyle(
                        fontSize: 22,
                        color: LobbyColors.cream,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        shadows: [
                          Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 8),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: LobbyColors.cream.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        entry.players.replaceAll(' players', ''),
                        style: LobbyText.label(size: 10, color: LobbyColors.cream),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  entry.label,
                  style: LobbyText.body(size: 15, weight: FontWeight.w800, color: LobbyColors.cream),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    entry.description,
                    style: LobbyText.body(
                      size: 12,
                      color: LobbyColors.cream.withValues(alpha: 0.82),
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'Tap to deal →',
                  style: LobbyText.label(size: 10, color: LobbyColors.chipYellow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _fillForVariant(String value) {
    switch (value) {
      case 'POINTS':
        return const [Color(0xFF8B1E2D), Color(0xFFC0392B)];
      case 'DEALS':
        return const [Color(0xFF0E4D7A), Color(0xFF1F8AD8)];
      case 'POOL_101':
        return const [Color(0xFF0B5C3C), Color(0xFF1FB88A)];
      case 'POOL_201':
        return const [Color(0xFF7A5A12), Color(0xFFD4A017)];
      default:
        return const [Color(0xFF123528), Color(0xFF2A6B4F)];
    }
  }
}

class GameVariantsSection extends StatelessWidget {
  const GameVariantsSection({super.key, this.onSelectVariant});

  final void Function(String variant)? onSelectVariant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LobbySectionTitle(
          'Pick your rummy',
          eyebrow: 'Game modes',
          subtitle: 'Tap a format to create a table.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final crossAxisCount = wide ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.05 : 0.92,
              children: [
                for (final e in LobbyVariants.entries)
                  GameVariantCard(
                    entry: e,
                    onTap: onSelectVariant == null ? null : () => onSelectVariant!(e.value),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

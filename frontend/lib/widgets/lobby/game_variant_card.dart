import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';

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
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                entry.description,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
              ),
              const Spacer(),
              Text(
                entry.players,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        Text(
          'Game variants',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final crossAxisCount = wide ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: wide ? 1.15 : 1.05,
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../theme/lobby_theme.dart';

/// Game modes as a fanned hand of playing-card tiles.
class GameVariantCard extends StatelessWidget {
  const GameVariantCard({
    super.key,
    required this.entry,
    this.onTap,
    this.tiltRadians = 0,
  });

  final ({String value, String label, String description, String players}) entry;
  final VoidCallback? onTap;
  final double tiltRadians;

  @override
  Widget build(BuildContext context) {
    final suit = LobbyColors.suitForVariant(entry.value);

    final card = Transform.rotate(
      angle: tiltRadians,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: LobbyColors.gameCardGreen,
              border: Border.all(color: LobbyColors.brandGreen.withValues(alpha: 0.55), width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(2, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suit,
                        style: const TextStyle(
                          fontSize: 42,
                          color: LobbyColors.chipMaroon,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: LobbyColors.brandGreen.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: LobbyColors.brandGreen.withValues(alpha: 0.55)),
                        ),
                        child: Text(
                          entry.players.replaceAll(' players', ''),
                          style: LobbyText.label(size: 9, color: LobbyColors.brandGreen),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    entry.label,
                    style: LobbyText.body(size: 14, weight: FontWeight.w800, color: LobbyColors.gameCardLabel),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LobbyText.body(
                      size: 11,
                      color: LobbyColors.gameRuleText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Text(
                        suit,
                        style: const TextStyle(
                          fontSize: 22,
                          color: LobbyColors.chipMaroon,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return AspectRatio(aspectRatio: 0.72, child: card);
  }
}

class GameVariantsSection extends StatelessWidget {
  const GameVariantsSection({super.key, this.onSelectVariant});

  final void Function(String variant)? onSelectVariant;

  static const _tilts = <double>[-0.06, 0.04, -0.03, 0.07];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LobbySectionTitle(
          'Pick your rummy',
          eyebrow: 'Game modes',
          subtitle: 'Fan through the hand and tap a card to deal.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final crossAxisCount = wide ? 4 : 2;
            return GridView.builder(
              itemCount: LobbyVariants.entries.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final e = LobbyVariants.entries[index];
                return GameVariantCard(
                  entry: e,
                  tiltRadians: _tilts[index % _tilts.length],
                  onTap: onSelectVariant == null ? null : () => onSelectVariant!(e.value),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

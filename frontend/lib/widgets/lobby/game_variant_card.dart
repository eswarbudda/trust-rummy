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
    this.width = 128,
  });

  final ({String value, String label, String description, String players}) entry;
  final VoidCallback? onTap;
  final double tiltRadians;
  final double width;

  @override
  Widget build(BuildContext context) {
    final suit = LobbyColors.suitForVariant(entry.value);
    final height = width / 0.72;

    final card = Transform.rotate(
      angle: tiltRadians,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: LobbyColors.gameCardGreen,
              border: Border.all(color: LobbyColors.gold.withValues(alpha: 0.55), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(2, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suit,
                        style: const TextStyle(
                          fontSize: 28,
                          color: LobbyColors.chipMaroon,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: LobbyColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: LobbyColors.gold.withValues(alpha: 0.55)),
                        ),
                        child: Text(
                          entry.players.replaceAll(' players', ''),
                          style: LobbyText.legacyLabel(size: 10, color: LobbyColors.gold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.label,
                    style: LobbyText.legacyBody(
                      size: 14,
                      weight: FontWeight.w800,
                      color: LobbyColors.gameCardLabel,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: LobbyText.legacyBody(
                      size: 11,
                      color: LobbyColors.gameRuleText,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Transform.rotate(
                      angle: math.pi,
                      child: Text(
                        suit,
                        style: const TextStyle(
                          fontSize: 16,
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

    return card;
  }
}

class GameVariantsSection extends StatelessWidget {
  const GameVariantsSection({super.key, this.onSelectVariant});

  final void Function(String variant)? onSelectVariant;

  static const _tilts = <double>[-0.06, 0.04, -0.03, 0.07];
  static const _cardWidth = 128.0;

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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 16,
          children: [
            for (var index = 0; index < LobbyVariants.entries.length; index++)
              GameVariantCard(
                entry: LobbyVariants.entries[index],
                width: _cardWidth,
                tiltRadians: _tilts[index % _tilts.length],
                onTap: onSelectVariant == null
                    ? null
                    : () => onSelectVariant!(LobbyVariants.entries[index].value),
              ),
          ],
        ),
      ],
    );
  }
}

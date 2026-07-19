import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import 'playing_card_view.dart';

/// The on-board reveal for a `DECLARE_RESULT` event — this is "where the
/// declared/finished cards show up": a banner overlaying the table with
/// the declaring player's melds laid out face-up, exactly as the backend
/// broadcasts them to the *whole room* (winner or not) so everyone can see
/// what was declared and whether the validator accepted it
/// (`RULES_ENGINE.md` §9 — `DECLARE_RESULT`: `userId`, `valid`, `reason`,
/// `melds[]`).
class DeclareResultPanel extends StatelessWidget {
  final String declarerName;
  final DeclareResultEvent result;
  final VoidCallback onClose;

  const DeclareResultPanel({
    super.key,
    required this.declarerName,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final valid = result.valid;
    final accent = valid ? RummyColors.success : RummyColors.danger;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: RummyColors.panelBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.6), width: 1.5),
              boxShadow: [BoxShadow(color: accent.withOpacity(0.35), blurRadius: 24, spreadRadius: 2)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(valid ? Icons.check_circle_rounded : Icons.cancel_rounded, color: accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        valid ? '$declarerName declared — VALID' : '$declarerName declared — WRONG',
                        style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                    ),
                  ],
                ),
                if (result.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(result.reason!, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < result.melds.length; i++) _meldRow(i, result.melds[i]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meldRow(int index, MeldView meld) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_meldLabel(meld.type)} ${index + 1}',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 62,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in meld.cards)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: PlayingCardView(card: card, width: 40, height: 58),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _meldLabel(String type) {
    switch (type) {
      case 'PURE_SEQUENCE':
        return 'Pure Sequence';
      case 'SEQUENCE':
        return 'Sequence';
      case 'SET':
        return 'Set';
      case 'SET_ASIDE':
        return 'Set aside (14th card)';
      default:
        return 'Group';
    }
  }
}

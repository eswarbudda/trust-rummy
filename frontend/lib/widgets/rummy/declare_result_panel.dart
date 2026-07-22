import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import 'playing_card_view.dart';

/// On-board reveal for a `DECLARE_RESULT` event — shown to the whole room.
///
/// On a wrong show, melds include best-effort legal groups plus `UNMATCHED`
/// cards (highlighted) and the set-aside 14th card so everyone can see what
/// failed.
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
    final title = valid
        ? '$declarerName — VALID SHOW'
        : '$declarerName — WRONG SHOW';

    final legal = result.melds.where((m) => m.type != 'SET_ASIDE' && m.ok).toList();
    final wrong = result.melds.where((m) => m.type == 'UNMATCHED' || (!m.ok && m.type != 'SET_ASIDE')).toList();
    final setAside = result.melds.where((m) => m.type == 'SET_ASIDE').toList();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Material(
            color: RummyColors.panelBg,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 28, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: accent,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
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
                    const SizedBox(height: 6),
                    Text(
                      result.reason!,
                      style: TextStyle(
                        color: valid ? Colors.white70 : RummyColors.danger.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: valid ? FontWeight.w400 : FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (legal.isNotEmpty) ...[
                            _sectionLabel(
                              valid ? 'Groups' : 'Valid groups',
                              valid ? RummyColors.success : Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < legal.length; i++)
                              _meldRow(i, legal[i], ok: true),
                          ],
                          if (!valid && wrong.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _sectionLabel('Wrong / unmatched cards', RummyColors.danger),
                            const SizedBox(height: 8),
                            for (var i = 0; i < wrong.length; i++)
                              _meldRow(i, wrong[i], ok: false),
                          ],
                          if (setAside.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _sectionLabel('Finish card (14th)', Colors.white60),
                            const SizedBox(height: 8),
                            for (final m in setAside) _meldRow(0, m, ok: true, muted: true),
                          ],
                          // Fallback if backend sent only untyped melds
                          if (legal.isEmpty && wrong.isEmpty && setAside.isEmpty)
                            for (var i = 0; i < result.melds.length; i++)
                              _meldRow(i, result.melds[i], ok: result.melds[i].ok),
                        ],
                      ),
                    ),
                  ),
                  if (!valid) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Everyone can see this wrong show. The deal is scored accordingly.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: RummyColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Got it — continue'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RummyColors.success,
                          side: BorderSide(color: RummyColors.success.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _meldRow(int index, MeldView meld, {required bool ok, bool muted = false}) {
    final borderColor = muted
        ? Colors.white24
        : (ok ? RummyColors.success.withValues(alpha: 0.55) : RummyColors.danger);
    final bg = muted
        ? Colors.white.withValues(alpha: 0.04)
        : (ok ? RummyColors.success.withValues(alpha: 0.08) : RummyColors.danger.withValues(alpha: 0.14));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: ok ? 1 : 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: muted ? Colors.white54 : (ok ? RummyColors.success : RummyColors.danger),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _meldLabel(meld.type),
                    style: TextStyle(
                      color: muted
                          ? Colors.white60
                          : (ok ? Colors.white : RummyColors.danger),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final card in meld.cards)
                  PlayingCardView(card: card, width: 46, height: 66),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _meldLabel(String type) {
    switch (type) {
      case 'PURE_SEQUENCE':
        return 'Pure sequence';
      case 'SEQUENCE':
      case 'IMPURE_SEQUENCE':
        return 'Sequence (with joker)';
      case 'SET':
        return 'Set';
      case 'UNMATCHED':
        return 'Invalid group — not a set or sequence';
      case 'SET_ASIDE':
        return 'Set aside';
      default:
        return 'Group';
    }
  }
}

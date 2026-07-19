import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';

/// Footer actions — only DROP and SHOW (reference-style, bottom-right).
class RummyActionBar extends StatelessWidget {
  final bool isMyTurn;
  final RummyTurnPhase? phase;
  final VoidCallback? onDrop;
  final VoidCallback? onDeclare;

  const RummyActionBar({
    super.key,
    required this.isMyTurn,
    required this.phase,
    this.onDrop,
    this.onDeclare,
  });

  @override
  Widget build(BuildContext context) {
    final canDrop = isMyTurn && phase == RummyTurnPhase.awaitingDraw;
    final canShow = isMyTurn && phase == RummyTurnPhase.awaitingDiscard;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: 'DROP',
          color: RummyColors.danger,
          enabled: canDrop,
          onTap: canDrop ? onDrop : null,
          tooltip: canDrop ? 'Fold this deal' : 'Drop is only available before you draw',
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: canShow ? 'Claim a winning hand' : 'Draw a card first, then you can Show',
          child: Opacity(
            opacity: canShow ? 1 : 0.5,
            child: _ActionButton(
              label: 'SHOW',
              color: RummyColors.showGreen,
              enabled: canShow,
              onTap: canShow ? onDeclare : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: enabled ? color : color.withOpacity(0.35),
      borderRadius: BorderRadius.circular(10),
      elevation: enabled ? 3 : 0,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 88, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

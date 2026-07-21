import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';

/// Bottom-lane action buttons.
///
/// Left: DRAW / DISCARD · Right: DROP / SHOW — same visual style.
class RummyActionBar extends StatelessWidget {
  final bool isMyTurn;
  final RummyTurnPhase? phase;
  final bool canDiscardSelected;
  final VoidCallback? onDraw;
  final VoidCallback? onDiscard;
  final VoidCallback? onDrop;
  final VoidCallback? onDeclare;
  final RummyLayout layout;

  /// When true, renders DRAW + DISCARD (bottom-left).
  /// When false, renders DROP + SHOW (bottom-right).
  final bool drawDiscard;

  const RummyActionBar({
    super.key,
    required this.isMyTurn,
    required this.phase,
    this.canDiscardSelected = false,
    this.onDraw,
    this.onDiscard,
    this.onDrop,
    this.onDeclare,
    this.layout = RummyLayout.standard,
    this.drawDiscard = false,
  });

  /// Bottom-left DRAW / DISCARD pair.
  const RummyActionBar.drawDiscard({
    super.key,
    required this.isMyTurn,
    required this.phase,
    this.canDiscardSelected = false,
    this.onDraw,
    this.onDiscard,
    this.layout = RummyLayout.standard,
  })  : drawDiscard = true,
        onDrop = null,
        onDeclare = null;

  /// Bottom-right DROP / SHOW pair.
  const RummyActionBar.dropShow({
    super.key,
    required this.isMyTurn,
    required this.phase,
    this.onDrop,
    this.onDeclare,
    this.layout = RummyLayout.standard,
  })  : drawDiscard = false,
        canDiscardSelected = false,
        onDraw = null,
        onDiscard = null;

  @override
  Widget build(BuildContext context) {
    return drawDiscard ? _drawDiscardRow() : _dropShowRow();
  }

  Widget _drawDiscardRow() {
    final canDraw = isMyTurn && phase == RummyTurnPhase.awaitingDraw && onDraw != null;
    final canDiscard =
        isMyTurn && phase == RummyTurnPhase.awaitingDiscard && canDiscardSelected && onDiscard != null;
    final gap = layout.actionButtonGap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: 'DRAW',
          color: RummyColors.info,
          enabled: canDraw,
          layout: layout,
          onTap: canDraw ? onDraw : null,
          tooltip: canDraw ? 'Draw from the closed deck' : 'Draw is only available on your draw turn',
        ),
        SizedBox(width: gap),
        _ActionButton(
          label: 'DISCARD',
          color: RummyColors.gold,
          enabled: canDiscard,
          layout: layout,
          onTap: canDiscard ? onDiscard : null,
          tooltip: canDiscard
              ? 'Discard the selected card'
              : 'Select a card after drawing to discard',
        ),
      ],
    );
  }

  Widget _dropShowRow() {
    final canDrop = isMyTurn && phase == RummyTurnPhase.awaitingDraw;
    final canShow = isMyTurn && phase == RummyTurnPhase.awaitingDiscard;
    final gap = layout.actionButtonGap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          label: 'DROP',
          color: RummyColors.danger,
          enabled: canDrop,
          layout: layout,
          onTap: canDrop ? onDrop : null,
          tooltip: canDrop ? 'Fold this deal' : 'Drop is only available before you draw',
        ),
        SizedBox(width: gap),
        Tooltip(
          message: canShow ? 'Claim a winning hand' : 'Draw a card first, then you can Show',
          child: Opacity(
            opacity: canShow ? 1 : 0.5,
            child: _ActionButton(
              label: 'SHOW',
              color: RummyColors.showGreen,
              enabled: canShow,
              layout: layout,
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
  final RummyLayout layout;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.layout,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(layout.actionButtonRadius);
    final fill = enabled ? color : color.withOpacity(0.32);

    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(fill, Colors.white, enabled ? 0.14 : 0.06)!,
                fill,
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(enabled ? 0.22 : 0.08),
              width: 1,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Container(
            constraints: BoxConstraints(
              minWidth: layout.actionButtonMinWidth,
              minHeight: layout.actionButtonHeight,
              maxHeight: layout.actionButtonHeight,
            ),
            padding: EdgeInsets.symmetric(horizontal: layout.actionButtonHPad),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(enabled ? 1 : 0.7),
                fontWeight: FontWeight.w800,
                fontSize: layout.actionButtonFontSize,
                letterSpacing: 0.7,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

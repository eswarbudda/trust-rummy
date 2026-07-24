import 'package:flutter/material.dart';

import '../../theme/lobby_theme.dart';

/// Borderless list row with a soft hover / press wash.
class SoftHoverRow extends StatefulWidget {
  const SoftHoverRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.highlight = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool highlight;

  @override
  State<SoftHoverRow> createState() => _SoftHoverRowState();
}

class _SoftHoverRowState extends State<SoftHoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.highlight;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: active
            ? LobbyColors.gold.withValues(alpha: widget.highlight ? 0.18 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: LobbyColors.gold.withValues(alpha: 0.1),
          splashColor: LobbyColors.gold.withValues(alpha: 0.14),
          onTap: widget.onTap,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.onCreateTable,
    required this.onJoinWithCode,
  });

  final VoidCallback onCreateTable;
  final VoidCallback onJoinWithCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            const _ActionChip(
              icon: Icons.flash_on_outlined,
              label: 'Quick Join',
              onPressed: null,
              tooltip: 'Coming soon — matchmaking API not available yet',
            ),
            _ActionChip(
              icon: Icons.add_circle_outline,
              label: 'Create Table',
              onPressed: onCreateTable,
            ),
            _ActionChip(
              icon: Icons.login,
              label: 'Join With Room Code',
              onPressed: onJoinWithCode,
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

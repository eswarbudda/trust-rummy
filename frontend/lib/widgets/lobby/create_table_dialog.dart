import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../lobby/lobby_models.dart';

class CreateTableDialog extends StatefulWidget {
  const CreateTableDialog({
    super.key,
    this.initialVariant = 'POOL_101',
  });

  final String initialVariant;

  static Future<CreateTableResult?> show(
    BuildContext context, {
    String initialVariant = 'POOL_101',
  }) {
    return showDialog<CreateTableResult>(
      context: context,
      builder: (_) => CreateTableDialog(initialVariant: initialVariant),
    );
  }

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class CreateTableResult {
  final String gameVariant;
  final int maxPlayers;
  final double stakeAmount;
  final int? dealsPerMatch;

  const CreateTableResult({
    required this.gameVariant,
    required this.maxPlayers,
    required this.stakeAmount,
    this.dealsPerMatch,
  });
}

class _CreateTableDialogState extends State<CreateTableDialog> {
  late String _variant;
  int _maxPlayers = 2;
  int _deals = 2;
  final _stakeController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _variant = widget.initialVariant;
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDeals = _variant == 'DEALS';
    return AlertDialog(
      title: const Text('Create table'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Variant', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in LobbyVariants.entries)
                    ChoiceChip(
                      label: Text(v.label),
                      selected: _variant == v.value,
                      onSelected: (s) {
                        if (!s) return;
                        setState(() => _variant = v.value);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Players', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [2, 3, 4, 5, 6])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _maxPlayers == n,
                      onSelected: (s) {
                        if (!s) return;
                        setState(() => _maxPlayers = n);
                      },
                    ),
                ],
              ),
              if (isDeals) ...[
                const SizedBox(height: 16),
                Text('Deals', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in [2, 3, 4, 5, 6])
                      ChoiceChip(
                        label: Text('$n'),
                        selected: _deals == n,
                        onSelected: (s) {
                          if (!s) return;
                          setState(() => _deals = n);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _stakeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Entry fee (virtual credits)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final stake = double.tryParse(_stakeController.text.trim()) ?? 0;
            Navigator.pop(
              context,
              CreateTableResult(
                gameVariant: _variant,
                maxPlayers: _maxPlayers,
                stakeAmount: stake,
                dealsPerMatch: isDeals ? _deals : null,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

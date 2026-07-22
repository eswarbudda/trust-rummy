import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../lobby/lobby_models.dart';

class JoinRoomDialog extends StatefulWidget {
  const JoinRoomDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const JoinRoomDialog(),
    );
  }

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final _controller = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (!isValidLobbyRoomCode(code)) {
      setState(() => _localError = 'Enter a valid 6-character room code');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join with room code'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: 'Room code',
                border: const OutlineInputBorder(),
                errorText: _localError,
              ),
              onChanged: (_) {
                if (_localError != null) setState(() => _localError = null);
              },
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Join')),
      ],
    );
  }
}

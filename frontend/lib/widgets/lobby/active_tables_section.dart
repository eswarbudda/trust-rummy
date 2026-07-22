import 'package:flutter/material.dart';

import '../../lobby/lobby_models.dart';
import '../../services/room_api_service.dart';

/// Uses list payload only (no per-row getRoom). Seat counts are not available.
class ActiveTablesSection extends StatelessWidget {
  const ActiveTablesSection({
    super.key,
    required this.rooms,
    required this.onJoin,
  });

  final List<CreatedRoom> rooms;
  final void Function(CreatedRoom room) onJoin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Active tables',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Open WAITING rooms. Player counts are not included in the list API.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
        ),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'No open tables right now. Create one or join with a room code.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          ...rooms.map((room) {
            final waiting = room.status.toUpperCase() == 'WAITING';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  title: Text('${room.roomCode} · ${LobbyVariants.labelFor(room.gameVariant)}'),
                  subtitle: Text(
                    '${room.status}'
                    '${room.maxPlayers != null ? ' · max ${room.maxPlayers}' : ''}'
                    '${room.stakeAmount != null ? ' · stake ${room.stakeAmount}' : ''}',
                  ),
                  trailing: FilledButton(
                    onPressed: waiting ? () => onJoin(room) : null,
                    child: const Text('Join'),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

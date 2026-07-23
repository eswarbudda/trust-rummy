import 'package:flutter/material.dart';

import '../../config/ui_config.dart';
import '../../lobby/lobby_models.dart';
import '../../services/room_api_service.dart';
import '../../theme/lobby_theme.dart';

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
        const LobbySectionTitle(
          'Open tables',
          eyebrow: 'Lobby floor',
          subtitle: 'WAITING rooms ready for one more seat.',
        ),
        const SizedBox(height: 14),
        if (rooms.isEmpty)
          LobbyPanel(
            borderColor: LobbyColors.teal.withValues(alpha: 0.3),
            child: Text(
              'No open tables right now. Create one or join with a room code.',
              style: LobbyText.bodyMuted(),
            ),
          )
        else
          ...rooms.map((room) {
            final waiting = room.status.toUpperCase() == 'WAITING';
            final accent = LobbyColors.accentForVariant(room.gameVariant ?? '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LobbyPanel(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                borderColor: accent.withValues(alpha: 0.4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${room.roomCode} · ${LobbyVariants.labelFor(room.gameVariant)}',
                            style: LobbyText.body(size: 16, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${room.status}'
                            '${room.maxPlayers != null ? ' · max ${room.maxPlayers}' : ''}'
                            '${room.stakeAmount != null ? ' · stake ${UiConfig.formatMoney(room.stakeAmount!)}' : ''}',
                            style: LobbyText.bodyMuted(size: 14),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: waiting ? () => onJoin(room) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: LobbyColors.ink,
                        disabledBackgroundColor: Colors.white12,
                      ),
                      child: const Text('Join'),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

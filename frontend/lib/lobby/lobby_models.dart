import 'package:flutter/foundation.dart';

/// Shared lobby / waiting-room labels for game variants.
class LobbyVariants {
  LobbyVariants._();

  static const entries = <({String value, String label, String description, String players})>[
    (
      value: 'POINTS',
      label: 'Points Rummy',
      description: 'Single deal. Lowest score wins the pot.',
      players: '2–6 players',
    ),
    (
      value: 'DEALS',
      label: 'Deals Rummy',
      description: 'Fixed number of deals. Lowest cumulative score wins.',
      players: '2–6 players',
    ),
    (
      value: 'POOL_101',
      label: 'Pool 101',
      description: 'Elimination at 101 points. Last player standing wins.',
      players: '2–6 players',
    ),
    (
      value: 'POOL_201',
      label: 'Pool 201',
      description: 'Elimination at 201 points. Last player standing wins.',
      players: '2–6 players',
    ),
  ];

  static String labelFor(String? code) {
    if (code == null || code.isEmpty) return 'Rummy';
    for (final e in entries) {
      if (e.value == code) return e.label;
    }
    return code;
  }
}

/// Backend room-code alphabet (see RoomService) — length 6.
final RegExp lobbyRoomCodePattern = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

bool isValidLobbyRoomCode(String raw) =>
    lobbyRoomCodePattern.hasMatch(raw.trim().toUpperCase());

@immutable
class ResumeMatchInfo {
  final String roomCode;
  final String status;
  final String? gameVariant;
  final int playerCount;
  final int? maxPlayers;

  const ResumeMatchInfo({
    required this.roomCode,
    required this.status,
    this.gameVariant,
    required this.playerCount,
    this.maxPlayers,
  });
}

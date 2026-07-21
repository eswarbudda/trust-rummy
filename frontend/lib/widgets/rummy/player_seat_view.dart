import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../theme/rummy_colors.dart';
import '../../theme/rummy_layout.dart';

/// Seat chip: circular avatar with a dark name pill.
/// Opponents keep the name under the avatar; the local seat can flip
/// [nameAbove] so the label sits above the avatar when needed.
/// [showScoreOnPlate] adds SCORE under the username (rim local seat).
class PlayerSeatView extends StatelessWidget {
  final PlayerView player;
  final bool isCurrentTurn;
  final bool isMe;
  final bool compact;
  final int? turnSecondsRemaining;
  final RummyLayout layout;
  /// Place SCORE under the username on the nameplate (local rim seat).
  final bool showScoreOnPlate;
  /// Place the nameplate above the avatar.
  final bool nameAbove;

  const PlayerSeatView({
    super.key,
    required this.player,
    required this.isCurrentTurn,
    this.isMe = false,
    this.compact = false,
    this.turnSecondsRemaining,
    this.layout = RummyLayout.standard,
    this.showScoreOnPlate = false,
    this.nameAbove = false,
  });

  @override
  Widget build(BuildContext context) {
    return _compactSeat();
  }

  Widget _compactSeat() {
    final avatarSize = layout.seatAvatarSize;
    final hasTimer = isCurrentTurn && turnSecondsRemaining != null;
    const timeout = 30;
    final progress = hasTimer ? (turnSecondsRemaining!.clamp(0, timeout) / timeout) : 1.0;
    final urgent = hasTimer && turnSecondsRemaining! <= 5;
    final ringColor = urgent ? RummyColors.danger : RummyColors.success;
    final gap = SizedBox(height: 5 * layout.scale);
    final avatar = _avatar(avatarSize, hasTimer, progress, ringColor, showSecondsBadge: isMe);
    final plate = _nameplate();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: nameAbove ? [plate, gap, avatar] : [avatar, gap, plate],
    );
  }

  Widget _nameplate() {
    final status = _statusLabel();
    return Container(
      constraints: BoxConstraints(maxWidth: layout.seatNameplateMaxWidth),
      padding: EdgeInsets.symmetric(horizontal: 9 * layout.scale, vertical: 3.5 * layout.scale),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1020).withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentTurn ? RummyColors.gold.withOpacity(0.7) : Colors.white24,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.username,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11 * layout.scale,
            ),
          ),
          if (showScoreOnPlate)
            Text(
              'SCORE: ${player.cumulativeScore}',
              style: TextStyle(
                color: RummyColors.gold,
                fontSize: 9 * layout.scale,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (status != null)
            Text(
              status,
              style: TextStyle(
                color: _statusColor(),
                fontSize: 8.5 * layout.scale,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(
    double avatarSize,
    bool hasTimer,
    double progress,
    Color ringColor, {
    bool showSecondsBadge = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (hasTimer)
          SizedBox(
            width: avatarSize + layout.seatTimerRingPad,
            height: avatarSize + layout.seatTimerRingPad,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: layout.seatTimerStroke,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(ringColor),
            ),
          ),
        Container(
          width: avatarSize,
          height: avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? RummyColors.gold.withOpacity(0.35) : _avatarColor(),
            border: Border.all(
              color: isCurrentTurn ? RummyColors.gold : Colors.white.withOpacity(0.4),
              width: isCurrentTurn ? 2.4 : 1.5,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            _initials(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: avatarSize * 0.34,
            ),
          ),
        ),
        if (hasTimer && showSecondsBadge)
          Positioned(
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: RummyColors.feltDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ringColor),
              ),
              child: Text(
                '${turnSecondsRemaining!}',
                style: TextStyle(color: ringColor, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }

  String? _statusLabel() {
    if (player.matchPlayerStatus == RummyMatchPlayerStatus.eliminated) return 'OUT';
    if (player.roundStatus == RummyRoundStatus.dropped) return 'DROP';
    return null;
  }

  Color _statusColor() {
    if (player.matchPlayerStatus == RummyMatchPlayerStatus.eliminated) return RummyColors.danger;
    if (player.roundStatus == RummyRoundStatus.dropped) return RummyColors.gold;
    return Colors.white70;
  }

  String _initials() {
    final parts = player.username.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final n = player.username.trim();
    if (n.length >= 2) return n.substring(0, 2).toUpperCase();
    return n.toUpperCase();
  }

  Color _avatarColor() {
    const palette = [
      Color(0xFF2E7D6F),
      Color(0xFF3D5A80),
      Color(0xFF8B5A2B),
      Color(0xFF6B3A5B),
      Color(0xFF4A6B3A),
      Color(0xFF5B4A6B),
    ];
    return palette[player.userId.abs() % palette.length];
  }
}

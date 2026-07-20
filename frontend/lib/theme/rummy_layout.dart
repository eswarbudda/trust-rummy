import 'package:flutter/material.dart';

import 'rummy_colors.dart';

/// Tunable layout metrics for the gameplay table.
///
/// Pass [scale] (or use [scaled]) to grow/shrink the whole table UI without
/// hunting magic numbers across widgets. Defaults match the approved mockup.
class RummyLayout {
  final double scale;

  const RummyLayout({this.scale = 1.0});

  static const RummyLayout standard = RummyLayout();

  RummyLayout scaled(double factor) => RummyLayout(scale: scale * factor);

  double _s(double value) => value * scale;

  // --- Cards ---
  double get cardWidth => _s(78);
  double get cardHeight => _s(104);
  double get handCardHeight => _s(102);

  // --- Hand fan ---
  double get handSlotMin => _s(44);
  double get handSlotMax => _s(58);
  double get handSoftGap => _s(3);
  double get handMeldGap => _s(20);
  double get handHeightPlain => _s(140);
  double get handHeightWithMelds => _s(150);
  double get handEmptyHeight => _s(140);

  /// Room under the hand for the local avatar on the wood rim (name sits below).
  double get handBottomInset => _s(52);

  // --- Center piles ---
  double get pileSpacingDeckToDiscard => _s(32);
  double get pileSpacingDiscardToFinish => _s(22);
  double get jokerPeekLeft => _s(48);
  double get pileStackOffsetX => _s(1.6);
  double get pileStackOffsetY => _s(1.4);

  // --- Seats ---
  double get seatAvatarSize => _s(52);
  double get seatNameplateMaxWidth => _s(88);
  double get seatTimerRingPad => _s(12);
  double get seatTimerStroke => _s(3.2);

  // --- Table chrome ---
  EdgeInsets get tablePadding => EdgeInsets.fromLTRB(_s(4), _s(2), _s(4), _s(2));
  /// Prefer filling the viewport — only clamp extreme ultrawide / tall shapes.
  double get tableMaxAspect => 2.2;
  double get tableMinAspect => 0.65;

  // --- Meld tray (valid set / sequence only) ---
  Color get meldTrayFill => const Color(0xFFDDF5E0);
  Color get meldTrayBorder => RummyColors.success;
  double get meldTrayRadius => _s(14);
  double get meldTrayBorderWidth => 2.5;

  // --- Cut-joker chip ---
  static const LinearGradient jokerChipGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

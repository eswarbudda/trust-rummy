import 'package:flutter/material.dart';

import 'rummy_colors.dart';

/// Tunable layout metrics for the gameplay table.
///
/// Pass [scale] (or use [scaled]) to grow/shrink the whole table UI without
/// hunting magic numbers across widgets. Defaults match the approved mockup.
///
/// Chrome outside the felt: [headerMinHeight] + [bottomLaneHeight].
/// The Table Area is [Expanded] and consumes all remaining space.
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

  // --- Hand fan (width-first; advance clamped for overlap, never scale cards) ---
  /// Minimum left-edge advance between overlapping cards.
  double get handSlotMin => _s(44);
  /// Soft gap when cards sit side-by-side without overlap.
  double get handSoftGap => _s(3);
  double get handMeldGap => _s(20);
  /// Fixed hand-strip height inside the table (includes selection lift budget).
  double get handHeightPlain => _s(128);
  double get handHeightWithMelds => _s(148);
  double get handEmptyHeight => _s(128);

  // --- Local seat band inside the felt (below the hand, on the oval rim) ---
  double get localSeatBandHeight => _s(108);

  // --- Reserved chrome outside the felt ---
  double get headerMinHeight => _s(52);
  /// Group controls + DRAW/DISCARD + DROP/SHOW share one lane under the table.
  double get bottomLaneHeight => _s(60);
  /// Outer inset that pulls action clusters toward the group controls.
  double get bottomLaneSideInset => _s(28);
  /// Space between an action cluster and the center group-controls slot.
  double get bottomLaneActionToGroupGap => _s(16);
  /// Gap between paired action buttons (DRAW↔DISCARD, DROP↔SHOW).
  double get actionButtonGap => _s(18);
  /// Compact action-button metrics (DRAW / DISCARD / DROP / SHOW).
  double get actionButtonMinWidth => _s(78);
  double get actionButtonHeight => _s(34);
  double get actionButtonRadius => _s(8);
  double get actionButtonFontSize => _s(12);
  double get actionButtonHPad => _s(12);
  /// Gap between Left / Create Group / Right chips.
  double get groupControlGap => _s(10);

  /// Vertical bias for center piles inside the upper felt (0 = center, 1 = bottom).
  /// Positive values push Deck / Open / Finish toward the visual middle of the oval.
  double get pileAlignY => 0.42;

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
  /// Fraction of available width inset on each horizontal side of the felt (8% L/R).
  double get tableHorizontalInsetFraction => 0.08;
  EdgeInsets get tableVerticalPadding => EdgeInsets.symmetric(vertical: _s(2));

  // --- Meld tray (only after the player creates groups) ---
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

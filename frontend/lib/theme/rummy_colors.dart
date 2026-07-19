import 'package:flutter/material.dart';

/// Palette for the gameplay table — felt green on a deep crimson board,
/// matching the common Indian online-rummy look used for the visual mockup.
class RummyColors {
  RummyColors._();

  /// Outer board behind the oval table.
  static const Color boardBg = Color(0xFF6B1520);
  static const Color boardBgDeep = Color(0xFF4A0E16);

  static const Color feltDark = Color(0xFF0A3D2E);
  static const Color feltMid = Color(0xFF147A52);
  static const Color feltLight = Color(0xFF1FA86A);

  static const Color rimOuter = Color(0xFF5C3A22);
  static const Color rimInner = Color(0xFF3E2616);

  static const Color panelBg = Color(0xFF1A0A0E);
  static const Color headerPill = Color(0xFF2A1218);
  static const Color panelBorder = Color(0x33FFFFFF);

  static const Color cardFace = Color(0xFFFDFBF5);
  static const Color cardBack = Color(0xFF8B1E2D);
  static const Color cardBackAccent = Color(0xFFD4A84B);

  static const Color suitRed = Color(0xFFC0392B);
  static const Color suitBlack = Color(0xFF1A1A1A);

  static const Color gold = Color(0xFFE8B94A);
  static const Color success = Color(0xFF2EAF5A);
  static const Color danger = Color(0xFFE53935);
  static const Color info = Color(0xFF64B5F6);
  static const Color showGreen = Color(0xFF43A047);

  static const RadialGradient tableGradient = RadialGradient(
    center: Alignment(0, -0.15),
    radius: 1.15,
    colors: [feltLight, feltMid, feltDark],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardBackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardBack, Color(0xFF5A101C)],
  );

  static const LinearGradient boardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8B1E2D), boardBg, boardBgDeep],
    stops: [0.0, 0.45, 1.0],
  );
}

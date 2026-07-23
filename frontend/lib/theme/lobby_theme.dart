import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Funky online-rummy lobby palette — felt green, card red, chip yellow.
/// Playful table-night energy (not luxury lounge).
class LobbyColors {
  LobbyColors._();

  static const Color ink = Color(0xFF0A1F18);
  static const Color inkSoft = Color(0xFF123528);
  static const Color felt = Color(0xFF148F5A);
  static const Color feltBright = Color(0xFF22C57A);
  static const Color cream = Color(0xFFFFF8EE);
  static const Color creamMuted = Color(0xFFD7CBB8);
  static const Color chipYellow = Color(0xFFFFD84D);
  static const Color cardRed = Color(0xFFE63946);
  static const Color openBlue = Color(0xFF3DBBFF);
  static const Color jokerOrange = Color(0xFFFF8A3D);
  static const Color wildPink = Color(0xFFFF5CA8);
  static const Color chipMaroon = Color(0xFF8B1A3A);
  static const Color chipMaroonDeep = Color(0xFF5C0F26);
  static const Color suitRed = Color(0xFFD32F2F);
  static const Color suitBlack = Color(0xFF1A1A1A);
  /// Hero title ("Hit the tables")
  static const Color heroTitle = Color(0xFFFFD84D);
  /// Brand / accent green — same as "TRUST RUMMY" label
  static const Color brandGreen = feltBright;
  /// Dark green fill for Pick-your-rummy game-mode cards
  static const Color gameCardGreen = Color(0xFF0D3D2C);
  /// Section titles ("Quick actions", "Pick your rummy", …)
  static const Color sectionTitle = brandGreen;
  /// Rule blurbs on game-mode cards (warm gold on dark green)
  static const Color gameRuleText = Color(0xFFFFE08A);
  /// Primary label text on dark green game cards
  static const Color gameCardLabel = Color(0xFFFFF8EE);

  // Aliases used by existing widgets
  static const Color gold = chipYellow;
  static const Color emerald = feltBright;
  static const Color teal = openBlue;
  static const Color coral = cardRed;
  static const Color sapphire = openBlue;
  static const Color plum = chipMaroon;
  static const Color chipPurple = chipMaroon;
  static const Color chipPurpleDeep = chipMaroonDeep;

  static const LinearGradient pageFallback = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3D2C), Color(0xFF122018), Color(0xFF2A1014)],
  );

  static const LinearGradient brandTint = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x2222C57A),
      Color(0x18148F5A),
      Color(0x332A1014),
    ],
  );

  static const LinearGradient quickActionMaroon = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [chipMaroon, chipMaroonDeep],
  );

  static Color accentForVariant(String value) {
    switch (value) {
      case 'POINTS':
        return cardRed;
      case 'DEALS':
        return openBlue;
      case 'POOL_101':
        return feltBright;
      case 'POOL_201':
        return chipYellow;
      default:
        return jokerOrange;
    }
  }

  static String suitForVariant(String value) {
    switch (value) {
      case 'POINTS':
        return '♥';
      case 'DEALS':
        return '♠';
      case 'POOL_101':
        return '♣';
      case 'POOL_201':
        return '♦';
      default:
        return '★';
    }
  }

  /// Suit symbols for game-mode tiles — shared maroon.
  static Color suitColorForVariant(String value) => chipMaroon;
}

class LobbyText {
  LobbyText._();

  static TextStyle brand({double size = 34, Color? color}) => GoogleFonts.fredoka(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        height: 1.05,
        color: color ?? LobbyColors.heroTitle,
      );

  static TextStyle section({double size = 22, Color? color}) => GoogleFonts.fredoka(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: color ?? LobbyColors.sectionTitle,
      );

  static TextStyle label({double size = 12, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.4,
        color: color ?? LobbyColors.chipYellow,
      );

  static TextStyle body({double size = 14, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        height: 1.35,
        color: color ?? LobbyColors.cream,
      );

  static TextStyle bodyMuted({double size = 13}) => body(size: size, color: LobbyColors.creamMuted, weight: FontWeight.w600);
}

/// Soft felt-panel used across lobby sections.
class LobbyPanel extends StatelessWidget {
  const LobbyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.gradient,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Gradient? gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                LobbyColors.inkSoft.withValues(alpha: 0.88),
                LobbyColors.ink.withValues(alpha: 0.78),
              ],
            ),
        border: Border.all(color: borderColor ?? LobbyColors.feltBright.withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LobbySectionTitle extends StatelessWidget {
  const LobbySectionTitle(
    this.title, {
    super.key,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(eyebrow!.toUpperCase(), style: LobbyText.label(size: 11)),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            Text(title, style: LobbyText.section()),
            const SizedBox(width: 8),
            Text('♠ ♥', style: LobbyText.body(size: 14, color: LobbyColors.brandGreen.withValues(alpha: 0.9))),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          height: 4,
          width: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(colors: [LobbyColors.brandGreen, LobbyColors.chipYellow]),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: LobbyText.bodyMuted()),
        ],
      ],
    );
  }
}

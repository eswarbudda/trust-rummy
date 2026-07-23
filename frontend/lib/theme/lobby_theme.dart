import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Funky online-rummy lobby palette — forest felt with gold accents.
/// Playful table-night energy (not luxury lounge).
class LobbyColors {
  LobbyColors._();

  static const Color ink = Color(0xFF071A12);
  static const Color inkSoft = Color(0xFF0F2A1C);
  /// Forest green felt (table base).
  static const Color felt = Color(0xFF1B4332);
  static const Color feltBright = Color(0xFF2D6A4F);
  static const Color cream = Color(0xFFFFF8EE);
  static const Color creamMuted = Color(0xFFD7CBB8);
  static const Color chipYellow = Color(0xFFFFD84D);
  static const Color cardRed = Color(0xFFE63946);
  static const Color openBlue = Color(0xFF3DBBFF);
  static const Color jokerOrange = Color(0xFFFF8A3D);
  static const Color wildPink = Color(0xFFFF5CA8);
  static const Color chipMaroon = Color(0xFF8B1A3A);
  static const Color chipMaroonDeep = Color(0xFF5C0F26);
  /// Warm brown for quick-action tiles / wood chrome (lightened for readability).
  static const Color woodBrown = Color(0xFF8B5E3C);
  static const Color woodBrownDeep = Color(0xFF6A452C);
  static const Color woodBrownLight = Color(0xFFA0724A);
  static const Color suitRed = Color(0xFFD32F2F);
  static const Color suitBlack = Color(0xFF1A1A1A);

  /// Primary lobby accent (titles, borders, highlights).
  static const Color gold = chipYellow;
  /// Hero title ("Hit the tables")
  static const Color heroTitle = gold;
  /// Brand accent stays gold; forest green lives on felt/table surfaces.
  static const Color brandGreen = gold;
  /// Dark forest fill for Pick-your-rummy game-mode cards.
  static const Color gameCardGreen = Color(0xFF0D2818);
  /// Section titles ("Quick actions", "Pick your rummy", …)
  static const Color sectionTitle = gold;
  /// Rule blurbs on game-mode cards
  static const Color gameRuleText = Color(0xFFFFE08A);
  /// Primary label text on dark game cards
  static const Color gameCardLabel = cream;
  /// Muted copy on dark panels
  static const Color textMuted = creamMuted;

  // Aliases used by existing widgets
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
    colors: [Color(0xFF0D2818), Color(0xFF122018), Color(0xFF2A1014)],
  );

  static const LinearGradient brandTint = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x221B4332),
      Color(0x18FFD84D),
      Color(0x332A1014),
    ],
  );

  static const LinearGradient quickActionBrown = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [woodBrownLight, woodBrown, woodBrownDeep],
  );

  /// @Deprecated Prefer [quickActionBrown].
  static const LinearGradient quickActionMaroon = quickActionBrown;

  static Color accentForVariant(String value) {
    switch (value) {
      case 'POINTS':
        return cardRed;
      case 'DEALS':
        return openBlue;
      case 'POOL_101':
        return feltBright;
      case 'POOL_201':
        return gold;
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

  // Previous fonts (kept for easy rollback): display = Fredoka, body = Nunito.
  // Current trial: display = Rowdies (catchy slab), body = Rubik (clean readable).

  static TextStyle brand({double size = 40, Color? color}) => GoogleFonts.rowdies(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        height: 1.05,
        color: color ?? LobbyColors.heroTitle,
      );

  static TextStyle section({double size = 24, Color? color}) => GoogleFonts.rowdies(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: color ?? LobbyColors.sectionTitle,
      );

  static TextStyle label({double size = 14, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.rubik(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.4,
        color: color ?? LobbyColors.gold,
      );

  static TextStyle body({double size = 16, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.rubik(
        fontSize: size,
        fontWeight: weight,
        height: 1.35,
        color: color ?? LobbyColors.cream,
      );

  static TextStyle bodyMuted({double size = 15}) =>
      body(size: size, color: LobbyColors.textMuted, weight: FontWeight.w600);

  /// Previous body font (Nunito) — used on Pick-your-rummy cards.
  static TextStyle legacyBody({double size = 16, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        height: 1.35,
        color: color ?? LobbyColors.cream,
      );

  /// Previous label font (Nunito) — used on Pick-your-rummy cards.
  static TextStyle legacyLabel({double size = 14, Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.nunito(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 1.4,
        color: color ?? LobbyColors.gold,
      );
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
        border: Border.all(color: borderColor ?? LobbyColors.gold.withValues(alpha: 0.4), width: 1.4),
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
          Text(eyebrow!.toUpperCase(), style: LobbyText.label(size: 13)),
          const SizedBox(height: 2),
        ],
        Row(
          children: [
            Text(title, style: LobbyText.section()),
            const SizedBox(width: 8),
            Text('♠ ♥', style: LobbyText.body(size: 16, color: LobbyColors.gold.withValues(alpha: 0.9))),
          ],
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          height: 4,
          width: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(colors: [LobbyColors.gold, Color(0xFFFFF1A8)]),
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

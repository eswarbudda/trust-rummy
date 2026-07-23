import 'package:flutter/material.dart';

import '../../config/ui_config.dart';
import '../../theme/lobby_theme.dart';
import '../../theme/rummy_colors.dart';

/// Full-bleed background: optional asset/network image + scrim, with a
/// solid/gradient fallback when images are disabled or fail to load.
class ScreenBackground extends StatelessWidget {
  const ScreenBackground({
    super.key,
    required this.child,
    this.enabled = true,
    this.assetPath,
    this.networkUrl,
    this.scrimOpacity = 0.55,
    this.fallback,
    this.brandTint,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.showSuitWatermark = false,
  });

  /// Soften crop toward the left so most of the hostess body stays in frame.
  factory ScreenBackground.lobby({Key? key, required Widget child}) {
    return ScreenBackground(
      key: key,
      enabled: UiConfig.lobbyBackgroundEnabled,
      assetPath: UiConfig.lobbyBackgroundAsset,
      networkUrl: UiConfig.lobbyBackgroundUrl,
      scrimOpacity: UiConfig.lobbyScrimOpacity,
      fallback: const BoxDecoration(gradient: LobbyColors.pageFallback),
      brandTint: LobbyColors.brandTint,
      alignment: const Alignment(-0.7, 0.15),
      showSuitWatermark: true,
      child: child,
    );
  }

  /// Game-board outer frame preset from [UiConfig].
  factory ScreenBackground.board({Key? key, required Widget child}) {
    return ScreenBackground(
      key: key,
      enabled: UiConfig.boardBackgroundEnabled,
      assetPath: UiConfig.boardBackgroundAsset,
      networkUrl: UiConfig.boardBackgroundUrl,
      scrimOpacity: UiConfig.boardScrimOpacity,
      fallback: const BoxDecoration(gradient: RummyColors.boardGradient),
      brandTint: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B1E2D).withValues(alpha: 0.38),
          const Color(0xFF6B1520).withValues(alpha: 0.48),
          const Color(0xFF4A0E16).withValues(alpha: 0.58),
        ],
      ),
      child: child,
    );
  }

  final Widget child;
  final bool enabled;
  final String? assetPath;
  final String? networkUrl;
  final double scrimOpacity;
  final Decoration? fallback;
  /// Optional brand color wash drawn above the photo (board only).
  final Gradient? brandTint;
  final BoxFit fit;
  final Alignment alignment;
  final bool showSuitWatermark;

  bool get _hasNetwork => networkUrl != null && networkUrl!.trim().isNotEmpty;

  bool get _hasAsset => assetPath != null && assetPath!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final showImage = enabled && (_hasNetwork || _hasAsset);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: fallback ?? const BoxDecoration(color: Colors.black),
        ),
        if (showImage)
          Positioned.fill(
            child: _BackgroundImage(
              networkUrl: _hasNetwork ? networkUrl!.trim() : null,
              assetPath: _hasAsset ? assetPath!.trim() : null,
              fit: fit,
              alignment: alignment,
            ),
          ),
        if (showImage && scrimOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: scrimOpacity * 0.72),
                      Colors.black.withValues(alpha: scrimOpacity),
                      Colors.black.withValues(alpha: (scrimOpacity + 0.1).clamp(0.0, 1.0)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (showImage && brandTint != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(decoration: BoxDecoration(gradient: brandTint)),
            ),
          ),
        if (showSuitWatermark)
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _SparseSuitWatermarkPainter()),
            ),
          ),
        child,
      ],
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({
    this.networkUrl,
    this.assetPath,
    required this.fit,
    required this.alignment,
  });

  final String? networkUrl;
  final String? assetPath;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (networkUrl != null) {
      return Image.network(
        networkUrl!,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => assetPath != null
            ? Image.asset(
                assetPath!,
                fit: fit,
                alignment: alignment,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : const SizedBox.shrink(),
      );
    }
    return Image.asset(
      assetPath!,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Sparse card-suit marks for empty lobby space — intentionally not a full pattern.
class _SparseSuitWatermarkPainter extends CustomPainter {
  const _SparseSuitWatermarkPainter();

  static const _marks = <(double, double, String, double, double)>[
    // xFrac, yFrac, suit, fontSize, rotation
    (0.78, 0.12, '♠', 54, -0.25),
    (0.88, 0.38, '♦', 40, 0.35),
    (0.72, 0.62, '♥', 48, -0.15),
    (0.92, 0.78, '♣', 36, 0.4),
    (0.08, 0.55, '♦', 32, -0.5),
    (0.14, 0.82, '♠', 44, 0.2),
    (0.55, 0.90, '♥', 30, -0.3),
    (0.22, 0.18, '♣', 38, 0.28),
    (0.35, 0.08, '♥', 42, -0.4),
    (0.48, 0.22, '♠', 28, 0.15),
    (0.62, 0.14, '♦', 34, -0.22),
    (0.05, 0.32, '♥', 36, 0.45),
    (0.18, 0.42, '♣', 26, -0.18),
    (0.30, 0.68, '♦', 40, 0.32),
    (0.42, 0.78, '♠', 33, -0.35),
    (0.68, 0.48, '♣', 30, 0.5),
    (0.82, 0.55, '♥', 28, -0.12),
    (0.95, 0.22, '♠', 32, 0.25),
    (0.10, 0.70, '♦', 24, -0.28),
    (0.58, 0.58, '♣', 22, 0.4),
    (0.75, 0.85, '♦', 36, -0.45),
    (0.38, 0.92, '♠', 26, 0.18),
    (0.86, 0.08, '♥', 24, 0.55),
    (0.02, 0.12, '♣', 30, -0.33),
    (0.50, 0.40, '♥', 20, -0.55),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final mark in _marks) {
      final (xFrac, yFrac, suit, fontSize, rotation) = mark;
      final offset = Offset(size.width * xFrac, size.height * yFrac);
      final tp = TextPainter(
        text: TextSpan(
          text: suit,
          style: TextStyle(
            fontSize: fontSize,
            color: LobbyColors.gold.withValues(alpha: 0.11),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(rotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

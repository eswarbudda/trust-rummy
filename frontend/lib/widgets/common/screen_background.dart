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
  });

  /// Lobby preset from [UiConfig].
  factory ScreenBackground.lobby({Key? key, required Widget child}) {
    return ScreenBackground(
      key: key,
      enabled: UiConfig.lobbyBackgroundEnabled,
      assetPath: UiConfig.lobbyBackgroundAsset,
      networkUrl: UiConfig.lobbyBackgroundUrl,
      scrimOpacity: UiConfig.lobbyScrimOpacity,
      fallback: const BoxDecoration(gradient: LobbyColors.pageFallback),
      brandTint: LobbyColors.brandTint,
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

/// Visual theming knobs for full-screen backgrounds.
///
/// Defaults ship with bundled assets under `assets/images/`. Override at
/// build/run time with `--dart-define` (same pattern as [ApiConfig]):
///
/// ```bash
/// flutter run --dart-define=LOBBY_BG_ASSET=assets/images/lobby_bg.png \
///   --dart-define=LOBBY_SCRIM_PERCENT=65 \
///   --dart-define=BOARD_BG_ASSET=assets/images/board_bg.png \
///   --dart-define=BOARD_SCRIM_PERCENT=45
/// ```
///
/// Set `LOBBY_BG_ENABLED=false` / `BOARD_BG_ENABLED=false` to fall back to the
/// solid/gradient look. Optional `*_BG_URL` loads a network image instead of
/// the asset (useful for remote theming without a rebuild).
class UiConfig {
  UiConfig._();

  // ---- Lobby ----

  static const bool lobbyBackgroundEnabled = bool.fromEnvironment(
    'LOBBY_BG_ENABLED',
    defaultValue: true,
  );

  static const String lobbyBackgroundAsset = String.fromEnvironment(
    'LOBBY_BG_ASSET',
    defaultValue: 'assets/images/lobby_bg.png',
  );

  /// When non-empty, preferred over [lobbyBackgroundAsset].
  static const String lobbyBackgroundUrl = String.fromEnvironment(
    'LOBBY_BG_URL',
    defaultValue: '',
  );

  /// Dark scrim over the lobby image so cards/CTAs stay readable (0–100).
  static const int lobbyScrimPercent = int.fromEnvironment(
    'LOBBY_SCRIM_PERCENT',
    defaultValue: 64,
  );

  // ---- Game board ----

  static const bool boardBackgroundEnabled = bool.fromEnvironment(
    'BOARD_BG_ENABLED',
    defaultValue: true,
  );

  static const String boardBackgroundAsset = String.fromEnvironment(
    'BOARD_BG_ASSET',
    defaultValue: 'assets/images/board_bg.png',
  );

  /// When non-empty, preferred over [boardBackgroundAsset].
  static const String boardBackgroundUrl = String.fromEnvironment(
    'BOARD_BG_URL',
    defaultValue: '',
  );

  /// Scrim over the board photo before the crimson gradient (0–100).
  static const int boardScrimPercent = int.fromEnvironment(
    'BOARD_SCRIM_PERCENT',
    defaultValue: 42,
  );

  static double get lobbyScrimOpacity => (lobbyScrimPercent.clamp(0, 100)) / 100.0;

  static double get boardScrimOpacity => (boardScrimPercent.clamp(0, 100)) / 100.0;
}

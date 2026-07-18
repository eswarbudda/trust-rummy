/// Central place for backend endpoint configuration.
///
/// Defaults target the Spring Boot dev server started via
/// `mvn spring-boot:run` on the default port 8080. Override at build/run
/// time with `--dart-define=API_HOST=<host:port>` if the backend runs
/// elsewhere.
class ApiConfig {
  ApiConfig._();

  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'localhost:8080',
  );

  static String get httpBaseUrl => 'http://$_host';

  static String get wsBaseUrl => 'ws://$_host';

  static String get telemetryWsPath => '/ws/telemetry';

  static Uri telemetryWsUri(String token) =>
      Uri.parse('$wsBaseUrl$telemetryWsPath?token=$token');

  // ---- Auth & onboarding (/api/v1/auth) ----

  static Uri get registerUri => Uri.parse('$httpBaseUrl/api/v1/auth/register');

  static Uri get loginUri => Uri.parse('$httpBaseUrl/api/v1/auth/login');

  static Uri get refreshUri => Uri.parse('$httpBaseUrl/api/v1/auth/refresh');

  static Uri get logoutUri => Uri.parse('$httpBaseUrl/api/v1/auth/logout');

  // ---- User profile (/api/v1/users) ----

  static Uri get profileUri => Uri.parse('$httpBaseUrl/api/v1/users/me');

  static Uri get changePasswordUri => Uri.parse('$httpBaseUrl/api/v1/users/me/password');

  // ---- Wallet (/api/v1/wallet) ----

  static Uri get walletBalanceUri => Uri.parse('$httpBaseUrl/api/v1/wallet/balance');

  static Uri get walletDepositUri => Uri.parse('$httpBaseUrl/api/v1/wallet/deposit');

  static Uri get walletWithdrawUri => Uri.parse('$httpBaseUrl/api/v1/wallet/withdraw');

  static Uri walletTransactionsUri({int page = 0, int size = 20}) =>
      Uri.parse('$httpBaseUrl/api/v1/wallet/transactions?page=$page&size=$size');

  // ---- Rooms / lobby (/api/v1/rooms) ----

  static Uri get roomsUri => Uri.parse('$httpBaseUrl/api/v1/rooms');

  static Uri roomUri(String roomCode) => Uri.parse('$httpBaseUrl/api/v1/rooms/$roomCode');

  static Uri roomJoinUri(String roomCode) => Uri.parse('$httpBaseUrl/api/v1/rooms/$roomCode/join');

  static Uri roomLeaveUri(String roomCode) => Uri.parse('$httpBaseUrl/api/v1/rooms/$roomCode/leave');

  static Uri roomReadyUri(String roomCode) => Uri.parse('$httpBaseUrl/api/v1/rooms/$roomCode/ready');

  // ---- Match history & audit (/api/v1/history) ----

  static Uri matchHistoryUri({int page = 0, int size = 20}) =>
      Uri.parse('$httpBaseUrl/api/v1/history/matches?page=$page&size=$size');

  static Uri matchDetailUri(int sessionId) => Uri.parse('$httpBaseUrl/api/v1/history/matches/$sessionId');

  static Uri matchMovesUri(int sessionId, {int page = 0, int size = 50}) =>
      Uri.parse('$httpBaseUrl/api/v1/history/matches/$sessionId/moves?page=$page&size=$size');

  static Uri get scorecardUri => Uri.parse('$httpBaseUrl/api/v1/history/scorecard');

  /// Gameplay WebSocket for a specific room, per `RULES_ENGINE.md` section 9.
  static Uri gameWsUri(String roomCode, String token) =>
      Uri.parse('$wsBaseUrl/ws/game/$roomCode?token=$token');
}

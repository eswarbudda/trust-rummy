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

  static Uri get registerUri => Uri.parse('$httpBaseUrl/api/auth/register');

  static Uri get loginUri => Uri.parse('$httpBaseUrl/api/auth/login');

  static Uri get roomsUri => Uri.parse('$httpBaseUrl/api/v1/rooms');

  /// Gameplay WebSocket for a specific room, per `RULES_ENGINE.md` section 9.
  static Uri gameWsUri(String roomCode, String token) =>
      Uri.parse('$wsBaseUrl/ws/game/$roomCode?token=$token');
}

abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.minegrow.local',
  );

  static const apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: 'v1',
  );

  static const networkTimeout = Duration(seconds: 30);

  static String get apiUrl => '$apiBaseUrl/$apiVersion';
}

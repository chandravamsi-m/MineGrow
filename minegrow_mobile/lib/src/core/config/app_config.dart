abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const apiVersion = String.fromEnvironment(
    'API_VERSION',
    defaultValue: 'api/v1',
  );

  static const networkTimeout = Duration(seconds: 30);

  static String get apiUrl => '$apiBaseUrl/$apiVersion';
}

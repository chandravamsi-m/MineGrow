import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppConfig {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://10.0.2.2:3000';

  static String get apiVersion =>
      dotenv.maybeGet('API_VERSION') ?? 'api/v1';

  static const networkTimeout = Duration(seconds: 30);

  static String get apiUrl => '$apiBaseUrl/$apiVersion';
}

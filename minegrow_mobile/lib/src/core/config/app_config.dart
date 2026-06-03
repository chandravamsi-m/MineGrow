import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppConfig {
  static String get apiBaseUrl => _trimTrailingSlashes(
    dotenv.maybeGet('API_BASE_URL') ?? 'http://10.0.2.2:3000',
  );

  static String get apiVersion =>
      _trimEdgeSlashes(dotenv.maybeGet('API_VERSION') ?? 'api/v1');

  static const networkTimeout = Duration(seconds: 30);

  static String get apiUrl {
    final base = apiBaseUrl;
    final version = apiVersion;
    if (base.endsWith('/$version') || base == version) return base;
    return '$base/$version';
  }

  static String get paymentUpiId =>
      (dotenv.maybeGet('PAYMENT_UPI_ID') ?? '').trim();

  static String _trimTrailingSlashes(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static String _trimEdgeSlashes(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'/+$'), '');
}

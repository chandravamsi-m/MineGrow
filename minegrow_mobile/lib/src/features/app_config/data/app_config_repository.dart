import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

// ── Remote App Config model ───────────────────────────────────────────────────

class RemoteAppConfig {
  const RemoteAppConfig({
    required this.paymentUpiId,
  });

  /// UPI ID to show on the payment screen QR code / deep-link.
  /// Falls back to [AppConfig.paymentUpiId] when the API is unreachable.
  final String paymentUpiId;

  factory RemoteAppConfig.fallback() => RemoteAppConfig(
        paymentUpiId: AppConfig.paymentUpiId,
      );

  factory RemoteAppConfig.fromJson(Object? json) {
    final map = (json as Map?)?.cast<String, dynamic>() ?? {};
    return RemoteAppConfig(
      paymentUpiId: map['payment_upi_id']?.toString() ??
          map['paymentUpiId']?.toString() ??
          AppConfig.paymentUpiId,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepository(ref.watch(apiClientProvider));
});

/// Caches the remote app config for the session lifetime.
/// Silently falls back to env-var values if the endpoint is unavailable.
final appConfigProvider = FutureProvider<RemoteAppConfig>((ref) {
  return ref.watch(appConfigRepositoryProvider).fetchConfig();
});

// ── Repository ────────────────────────────────────────────────────────────────

class AppConfigRepository {
  const AppConfigRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<RemoteAppConfig> fetchConfig() async {
    try {
      return await _apiClient.getData<RemoteAppConfig>(
        '/app/config',
        parser: RemoteAppConfig.fromJson,
      );
    } catch (_) {
      // Network error or endpoint not yet implemented — use env fallback.
      return RemoteAppConfig.fallback();
    }
  }
}

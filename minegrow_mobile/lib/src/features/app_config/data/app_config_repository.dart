import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';

// ── Remote App Config model ───────────────────────────────────────────────────

class RemoteAppConfig {
  const RemoteAppConfig({
    required this.paymentUpiId,
    required this.supportEmail,
    required this.supportPhone,
    required this.termsUrl,
    required this.privacyUrl,
    required this.riskDisclosure,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minSupportedVersion,
    this.updateUrl,
  });

  /// UPI ID to show on the payment screen QR code / deep-link.
  /// Falls back to [AppConfig.paymentUpiId] when the API is unreachable.
  final String paymentUpiId;
  final String supportEmail;
  final String supportPhone;
  final String termsUrl;
  final String privacyUrl;
  final String riskDisclosure;

  /// When true the backend is down for maintenance and the app should show a
  /// blocking screen instead of letting the user in.
  final bool maintenanceMode;
  final String? maintenanceMessage;

  /// Minimum app version (semver "x.y.z") the backend still supports. Clients
  /// older than this are forced to update. Null disables the gate.
  final String? minSupportedVersion;

  /// Store URL opened by the force-update screen's primary action.
  final String? updateUrl;

  factory RemoteAppConfig.fallback() => RemoteAppConfig(
        paymentUpiId: AppConfig.paymentUpiId,
        supportEmail: 'support@minegrow.app',
        supportPhone: '+91 90000 00000',
        termsUrl: 'https://minegrow.app/terms',
        privacyUrl: 'https://minegrow.app/privacy',
        riskDisclosure:
            'Mining investment returns depend on active plan terms, approved deposits, and wallet eligibility rules.',
      );

  factory RemoteAppConfig.fromJson(Object? json) {
    final map = (json as Map?)?.cast<String, dynamic>() ?? {};
    final fallback = RemoteAppConfig.fallback();
    return RemoteAppConfig(
      paymentUpiId: map['payment_upi_id']?.toString() ??
          map['paymentUpiId']?.toString() ??
          AppConfig.paymentUpiId,
      supportEmail: map['support_email']?.toString() ??
          map['supportEmail']?.toString() ??
          fallback.supportEmail,
      supportPhone: map['support_phone']?.toString() ??
          map['supportPhone']?.toString() ??
          fallback.supportPhone,
      termsUrl: map['terms_url']?.toString() ??
          map['termsUrl']?.toString() ??
          fallback.termsUrl,
      privacyUrl: map['privacy_url']?.toString() ??
          map['privacyUrl']?.toString() ??
          fallback.privacyUrl,
      riskDisclosure: map['risk_disclosure']?.toString() ??
          map['riskDisclosure']?.toString() ??
          fallback.riskDisclosure,
      maintenanceMode: _boolValue(
        map['maintenance_mode'] ?? map['maintenanceMode'],
      ),
      maintenanceMessage: (map['maintenance_message'] ??
              map['maintenanceMessage'])
          ?.toString(),
      minSupportedVersion: (map['min_supported_version'] ??
              map['minSupportedVersion'])
          ?.toString(),
      updateUrl:
          (map['update_url'] ?? map['updateUrl'])?.toString(),
    );
  }

  static bool _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
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

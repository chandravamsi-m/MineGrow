import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/utils/upi_validator.dart';

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

  bool get hasValidPaymentUpiId => isValidUpiId(paymentUpiId);

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
    return RemoteAppConfig(
      paymentUpiId: normalizeUpiId(
        map['payment_upi_id']?.toString() ??
            map['paymentUpiId']?.toString() ??
            AppConfig.paymentUpiId,
      ),
      supportEmail:
          map['support_email']?.toString() ??
          map['supportEmail']?.toString() ??
          'support@minegrow.app',
      supportPhone:
          map['support_phone']?.toString() ??
          map['supportPhone']?.toString() ??
          '+91 90000 00000',
      termsUrl:
          map['terms_url']?.toString() ??
          map['termsUrl']?.toString() ??
          'https://minegrow.app/terms',
      privacyUrl:
          map['privacy_url']?.toString() ??
          map['privacyUrl']?.toString() ??
          'https://minegrow.app/privacy',
      riskDisclosure:
          map['risk_disclosure']?.toString() ??
          map['riskDisclosure']?.toString() ??
          'Mining investment returns depend on active plan terms, approved deposits, and wallet eligibility rules.',
      maintenanceMode: _boolValue(
        map['maintenance_mode'] ?? map['maintenanceMode'],
      ),
      maintenanceMessage:
          (map['maintenance_message'] ?? map['maintenanceMessage'])?.toString(),
      minSupportedVersion:
          (map['min_supported_version'] ?? map['minSupportedVersion'])
              ?.toString(),
      updateUrl: (map['update_url'] ?? map['updateUrl'])?.toString(),
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

/// Payment screens fail closed: do not generate a QR from env defaults when
/// the backend payment account cannot be loaded.
final paymentAppConfigProvider = FutureProvider<RemoteAppConfig>((ref) {
  return ref.watch(appConfigRepositoryProvider).fetchRemoteConfig();
});

// ── Repository ────────────────────────────────────────────────────────────────

class AppConfigRepository {
  const AppConfigRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<RemoteAppConfig> fetchRemoteConfig() {
    return _apiClient.getData<RemoteAppConfig>(
      '/app/config',
      parser: RemoteAppConfig.fromJson,
    );
  }

  Future<RemoteAppConfig> fetchConfig() async {
    try {
      return await fetchRemoteConfig();
    } catch (_) {
      // Network error or endpoint not yet implemented — use env fallback.
      return RemoteAppConfig.fallback();
    }
  }
}

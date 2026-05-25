import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/data/app_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    storage: ref.watch(localStorageProvider),
  );
});

class AuthRepository {
  const AuthRepository({
    required ApiClient apiClient,
    required LocalStorage storage,
  }) : _apiClient = apiClient,
       _storage = storage;

  final ApiClient _apiClient;
  final LocalStorage _storage;

  /// Sends an OTP and returns the resend cooldown in seconds (default 30).
  /// The delay is stored in [AuthStorageKeys.otpResendDelay] so the OTP screen
  /// can read it without relying on a hardcoded value.
  Future<int> sendOtp({
    required String mobile,
    required String purpose,
  }) async {
    final String fullMobile = mobile.startsWith('+91') ? mobile : '+91$mobile';
    final delay = await _apiClient.postData<int>(
      '/auth/send-otp',
      data: {'mobile': fullMobile, 'purpose': purpose},
      parser: (json) {
        if (json is Map) {
          final d = json['resend_delay'] ?? json['resendDelay'];
          if (d is num) return d.toInt();
        }
        return 30;
      },
    );
    await _storage.writeString(AuthStorageKeys.mobile, fullMobile);
    await _storage.writeString(AuthStorageKeys.otpPurpose, purpose);
    await _storage.writeString(
        AuthStorageKeys.otpResendDelay, delay.toString());
    return delay;
  }

  Future<AuthSession> verifyOtp({
    required String mobile,
    required String otp,
    required String purpose,
  }) async {
    final String fullMobile = mobile.startsWith('+91') ? mobile : '+91$mobile';
    final session = await _apiClient.postData<AuthSession>(
      '/auth/verify-otp',
      data: {'mobile': fullMobile, 'otp': otp, 'purpose': purpose},
      parser: AuthSession.fromJson,
    );
    await _saveSession(session, fullMobile);
    return session;
  }

  Future<UserProfile> onboardStep1({
    required String fullName,
    required String email,
    required String address,
  }) async {
    final profile = await _apiClient.postData<UserProfile>(
      '/auth/onboard/step1',
      data: {
        'fullName': fullName,
        'email': email,
        'address': address,
      },
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return UserProfile.fromJson(map['user']);
      },
    );
    return profile;
  }

  Future<void> logout() async {
    try {
      await _apiClient.postData<void>(
        '/auth/logout',
        parser: (_) {},
      );
    } catch (_) {
      // Local logout should still complete if the session is already invalid
      // or the device is offline.
    } finally {
      await _storage.removeAll();
    }
  }

  String? readSavedMobile() => _storage.readString(AuthStorageKeys.mobile);

  Future<String?> readSavedMobileAsync() =>
      _storage.readStringAsync(AuthStorageKeys.mobile);

  String readSavedOtpPurpose() {
    return _storage.readString(AuthStorageKeys.otpPurpose) ?? 'login';
  }

  /// Returns the resend cooldown last saved by [sendOtp], defaulting to 30 s.
  Future<int> readSavedOtpResendDelayAsync() async {
    final raw =
        await _storage.readStringAsync(AuthStorageKeys.otpResendDelay);
    return int.tryParse(raw ?? '') ?? 30;
  }

  Future<void> _saveSession(AuthSession session, String mobile) async {
    await _storage.writeString(
      AuthStorageKeys.accessToken,
      session.accessToken,
    );
    await _storage.writeString(
      AuthStorageKeys.refreshToken,
      session.refreshToken,
    );
    await _storage.writeString(AuthStorageKeys.mobile, mobile);
  }
}

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

  Future<void> sendOtp({
    required String mobile,
    required String purpose,
  }) async {
    final String fullMobile = mobile.startsWith('+91') ? mobile : '+91$mobile';
    await _apiClient.postData<void>(
      '/auth/send-otp',
      data: {'mobile': fullMobile, 'purpose': purpose},
      parser: (_) {},
    );
    await _storage.writeString(AuthStorageKeys.mobile, fullMobile);
    await _storage.writeString(AuthStorageKeys.otpPurpose, purpose);
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
    await _storage.remove(AuthStorageKeys.accessToken);
    await _storage.remove(AuthStorageKeys.refreshToken);
  }

  String? readSavedMobile() => _storage.readString(AuthStorageKeys.mobile);

  String readSavedOtpPurpose() {
    return _storage.readString(AuthStorageKeys.otpPurpose) ?? 'login';
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

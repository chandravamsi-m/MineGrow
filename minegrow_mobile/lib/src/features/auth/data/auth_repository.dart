import 'package:dio/dio.dart';
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

  Future<void> login({required String mobile, required String password}) async {
    final String fullMobile = mobile.startsWith('+91') ? mobile : '+91$mobile';
    await _apiClient.postData<void>(
      '/auth/login',
      data: {'mobile': fullMobile, 'password': password},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
      parser: (_) {},
    );
    await _storage.writeString(AuthStorageKeys.mobile, fullMobile);
    await _storage.writeString(AuthStorageKeys.otpPurpose, 'login');
  }

  Future<void> register({
    required String fullName,
    required String mobile,
    required String password,
    String? email,
  }) async {
    final String fullMobile = mobile.startsWith('+91') ? mobile : '+91$mobile';
    await _apiClient.postData<void>(
      '/auth/register',
      data: {
        'fullName': fullName,
        'mobile': fullMobile,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      parser: (_) {},
    );
    await _storage.writeString(AuthStorageKeys.mobile, fullMobile);
    await _storage.writeString(AuthStorageKeys.otpPurpose, 'register');
  }

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

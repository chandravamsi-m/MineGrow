import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/data/app_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    ref.watch(apiClientProvider),
    ref.watch(dioProvider),
  );
});

// Cache-first profile: serves stored data instantly on cold start,
// then refreshes from network in background and silently updates state.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);

final bankAccountsProvider = FutureProvider<List<BankAccount>>((ref) {
  return ref.watch(profileRepositoryProvider).getBankAccounts();
});

class ProfileNotifier extends AsyncNotifier<UserProfile> {
  static const _cacheKey = 'cache.profile';

  @override
  Future<UserProfile> build() async {
    final storage = ref.read(localStorageProvider);
    final raw = await storage.readStringAsync(_cacheKey);

    if (raw != null) {
      _refreshInBackground();
      return UserProfile.fromJson(jsonDecode(raw));
    }

    return _fetchAndPersist();
  }

  void _refreshInBackground() {
    Future(() async {
      try {
        final fresh = await _fetchAndPersist();
        state = AsyncData(fresh);
      } catch (_) {
        // Silently fail — user already sees cached data
      }
    });
  }

  Future<UserProfile> _fetchAndPersist() async {
    final profile = await ref.read(profileRepositoryProvider).getProfile();
    final storage = ref.read(localStorageProvider);
    await storage.writeString(
      _cacheKey,
      jsonEncode({
        'id': profile.id,
        'full_name': profile.fullName,
        'mobile': profile.mobile,
        if (profile.email != null) 'email': profile.email,
        if (profile.address != null) 'address': profile.address,
        'status': profile.status,
        'kyc_verified': profile.kycVerified,
        'notification_preferences': profile.notificationPreferences.toJson(),
      }),
    );
    return profile;
  }
}

class ProfileRepository {
  const ProfileRepository(this._apiClient, this._dio);

  final ApiClient _apiClient;
  final Dio _dio;

  Future<UserProfile> getProfile() {
    return _apiClient.getData<UserProfile>(
      '/users/profile',
      parser: UserProfile.fromJson,
    );
  }

  Future<List<BankAccount>> getBankAccounts() {
    return _apiClient.getData<List<BankAccount>>(
      '/users/bank-accounts',
      parser: (json) => (json as List)
          .map((item) => BankAccount.fromJson(item))
          .toList(growable: false),
    );
  }

  Future<UserProfile> updateProfile({
    required String fullName,
    required String email,
    required String address,
  }) {
    return _apiClient.putData<UserProfile>(
      '/users/profile',
      data: {'fullName': fullName, 'email': email, 'address': address},
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return UserProfile.fromJson(map['user'] ?? map);
      },
    );
  }

  Future<BankAccount> addBankAccount({
    required String bankName,
    required String accountHolder,
    required String accountNumber,
    required String ifscCode,
  }) {
    return _apiClient.postData<BankAccount>(
      '/users/bank-accounts',
      data: {
        'account_type': 'bank',
        'bank_name': bankName,
        'account_holder': accountHolder,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
      },
      parser: BankAccount.fromJson,
    );
  }

  Future<BankAccount> addUpiId({required String upiId, String? accountHolder}) {
    return _apiClient.postData<BankAccount>(
      '/users/bank-accounts',
      data: {
        'account_type': 'upi',
        'upi_id': upiId,
        'bank_name': 'UPI',
        'account_number': upiId,
        'ifsc_code': '',
        'account_holder': ?accountHolder,
      },
      parser: BankAccount.fromJson,
    );
  }

  Future<List<KycDocument>> getKycDocuments() {
    return _apiClient.getData<List<KycDocument>>(
      '/users/kyc',
      parser: parseKycDocuments,
    );
  }

  Future<KycDocument?> uploadKycDocument({
    required String docType,
    required MultipartFile file,
  }) {
    return _apiClient.postData<KycDocument?>(
      '/users/kyc',
      data: buildKycUploadFormData(docType: docType, file: file),
      options: Options(contentType: 'multipart/form-data'),
      parser: parseKycUploadResponse,
    );
  }

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final response = await _dio.patch<Object?>(
      '/users/notification-preferences',
      data: notificationPreferencesPayload(preferences),
    );
    final data = _unwrapData(response.data);
    return NotificationPreferences.fromJson(
      data is Map<String, dynamic>
          ? data['notification_preferences'] ??
                data['notificationPreferences'] ??
                data['preferences'] ??
                data
          : data,
    );
  }

  Future<void> deleteAccount(int id) async {
    await _apiClient.delete<Object?>('/users/bank-accounts/$id');
  }
}

final kycDocumentsProvider = FutureProvider<List<KycDocument>>((ref) {
  return ref.watch(profileRepositoryProvider).getKycDocuments();
});

FormData buildKycUploadFormData({
  required String docType,
  required MultipartFile file,
}) {
  return FormData.fromMap({'docType': docType, 'file': file});
}

Map<String, bool> notificationPreferencesPayload(
  NotificationPreferences preferences,
) {
  return preferences.toJson();
}

List<KycDocument> parseKycDocuments(Object? json) {
  final documents = switch (json) {
    final List list => list,
    final Map map =>
      (map['documents'] ?? map['kycDocuments'] ?? map['kyc'] ?? const [])
          as List,
    _ => const [],
  };
  return documents
      .map((item) => KycDocument.fromJson(item))
      .toList(growable: false);
}

KycDocument? parseKycUploadResponse(Object? json) {
  if (json == null) return null;
  if (json is Map<String, dynamic>) {
    final document =
        json['document'] ?? json['kycDocument'] ?? json['kyc'] ?? json;
    if (document is Map<String, dynamic>) {
      return KycDocument.fromJson(document);
    }
  }
  return null;
}

Object? _unwrapData(Object? body) {
  if (body case {'data': final Object? data}) {
    return data;
  }
  return body;
}

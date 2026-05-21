import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/data/app_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
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
      }),
    );
    return profile;
  }
}

class ProfileRepository {
  const ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

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
      data: {
        'fullName': fullName,
        'email': email,
        'address': address,
      },
      parser: (json) {
        final map = json as Map<String, dynamic>;
        return UserProfile.fromJson(map['user'] ?? map);
      },
    );
  }
}

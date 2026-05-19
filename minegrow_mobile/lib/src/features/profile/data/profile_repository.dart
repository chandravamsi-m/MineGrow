import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/data/app_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final profileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final bankAccountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(profileRepositoryProvider).getBankAccounts();
});

class ProfileRepository {
  const ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> getProfile() {
    return _apiClient.getData<UserProfile>(
      '/users/profile',
      parser: UserProfile.fromJson,
    );
  }

  Future<List<Map<String, dynamic>>> getBankAccounts() {
    return _apiClient.getData<List<Map<String, dynamic>>>(
      '/users/bank-accounts',
      parser: (json) => (json as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
    );
  }
}

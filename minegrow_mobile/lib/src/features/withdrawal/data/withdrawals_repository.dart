import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/data/app_models.dart';

final withdrawalsRepositoryProvider = Provider<WithdrawalsRepository>((ref) {
  return WithdrawalsRepository(ref.watch(apiClientProvider));
});

final withdrawalEligibilityProvider = FutureProvider<WithdrawalEligibility>((
  ref,
) {
  return ref.watch(withdrawalsRepositoryProvider).getEligibility();
});

final withdrawalsProvider = FutureProvider<List<WithdrawalItem>>((ref) {
  return ref.watch(withdrawalsRepositoryProvider).getWithdrawals();
});

class WithdrawalsRepository {
  const WithdrawalsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WithdrawalEligibility> getEligibility() {
    return _apiClient.getData<WithdrawalEligibility>(
      '/withdrawals/eligibility',
      parser: WithdrawalEligibility.fromJson,
    );
  }

  Future<List<WithdrawalItem>> getWithdrawals() {
    return _apiClient.getData<List<WithdrawalItem>>(
      '/withdrawals',
      parser: (json) => (json as List)
          .map((item) => WithdrawalItem.fromJson(item))
          .toList(growable: false),
    );
  }

  Future<void> requestRoiWithdrawal({
    required num amount,
    int? bankAccountId,
    String? upiId,
  }) {
    final payload = <String, dynamic>{'amount': amount};
    if (bankAccountId != null) {
      payload['bankAccountId'] = bankAccountId;
    }
    if (upiId != null && upiId.isNotEmpty) {
      payload['upiId'] = upiId;
    }

    return _apiClient.postData<void>(
      '/withdrawals/roi',
      data: payload,
      parser: (_) {},
    );
  }

  Future<void> requestPrincipalWithdrawal({
    required num amount,
    int? bankAccountId,
    String? upiId,
  }) {
    final payload = <String, dynamic>{'amount': amount};
    if (bankAccountId != null) {
      payload['bankAccountId'] = bankAccountId;
    }
    if (upiId != null && upiId.isNotEmpty) {
      payload['upiId'] = upiId;
    }

    return _apiClient.postData<void>(
      '/withdrawals/principal',
      data: payload,
      parser: (_) {},
    );
  }
}

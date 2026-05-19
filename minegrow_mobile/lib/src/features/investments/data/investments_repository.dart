import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/data/app_models.dart';

final investmentsRepositoryProvider = Provider<InvestmentsRepository>((ref) {
  return InvestmentsRepository(ref.watch(apiClientProvider));
});

final investmentPlansProvider = FutureProvider<List<InvestmentPlan>>((ref) {
  return ref.watch(investmentsRepositoryProvider).getPlans();
});

final ownInvestmentsProvider = FutureProvider<List<InvestmentRecord>>((ref) {
  return ref.watch(investmentsRepositoryProvider).getOwnInvestments();
});

class InvestmentsRepository {
  const InvestmentsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<InvestmentPlan>> getPlans() {
    return _apiClient.getData<List<InvestmentPlan>>(
      '/plans',
      parser: (json) => (json as List)
          .map((item) => InvestmentPlan.fromJson(item))
          .toList(growable: false),
    );
  }

  Future<List<InvestmentRecord>> getOwnInvestments() {
    return _apiClient.getData<List<InvestmentRecord>>(
      '/investments',
      parser: (json) => (json as List)
          .map((item) => InvestmentRecord.fromJson(item))
          .toList(growable: false),
    );
  }

  Future<void> createInvestment({
    required int planId,
    required num amount,
    String? utrNumber,
    MultipartFile? paymentProof,
  }) {
    if (paymentProof == null) {
      throw const ApiException(message: 'Payment proof file is required.');
    }

    return _apiClient.postData<void>(
      '/investments',
      data: FormData.fromMap({
        'planId': planId,
        'amount': amount,
        if (utrNumber != null && utrNumber.isNotEmpty) 'utrNumber': utrNumber,
        'paymentProof': paymentProof,
      }),
      options: Options(contentType: 'multipart/form-data'),
      parser: (_) {},
    );
  }
}

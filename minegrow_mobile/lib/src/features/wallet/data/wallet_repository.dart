import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../shared/data/app_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

final walletSummaryProvider = FutureProvider<WalletSummary>((ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
});

final roiHistoryProvider = FutureProvider<List<RoiHistoryItem>>((ref) {
  return ref.watch(walletRepositoryProvider).getRoiHistory();
});

class WalletRepository {
  const WalletRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WalletSummary> getWallet() {
    return _apiClient.getData<WalletSummary>(
      '/wallet',
      parser: WalletSummary.fromJson,
    );
  }

  Future<List<RoiHistoryItem>> getRoiHistory() {
    return _apiClient.getData<List<RoiHistoryItem>>(
      '/wallet/roi-history',
      parser: (json) => (json as List)
          .map((item) => RoiHistoryItem.fromJson(item))
          .toList(growable: false),
    );
  }
}

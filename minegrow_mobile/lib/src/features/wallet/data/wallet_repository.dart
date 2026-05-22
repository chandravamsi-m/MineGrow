import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

class MonthlyRoiSummary {
  const MonthlyRoiSummary({
    required this.monthKey,
    required this.label,
    required this.total,
    required this.entries,
  });

  final String monthKey;
  final String label;
  final num total;
  final int entries;
}

List<MonthlyRoiSummary> summarizeRoiByMonth(List<RoiHistoryItem> history) {
  final totals = <String, ({DateTime month, num total, int entries})>{};

  for (final item in history) {
    final creditedAt = _parseRoiDate(item.creditedDate);
    if (creditedAt == null) continue;

    final month = DateTime(creditedAt.year, creditedAt.month);
    final key = DateFormat('yyyy-MM').format(month);
    final current = totals[key];
    totals[key] = (
      month: month,
      total: (current?.total ?? 0) + item.amount,
      entries: (current?.entries ?? 0) + 1,
    );
  }

  final summaries = totals.entries.map((entry) {
    final value = entry.value;
    return MonthlyRoiSummary(
      monthKey: entry.key,
      label: DateFormat('MMM yyyy').format(value.month),
      total: value.total,
      entries: value.entries,
    );
  }).toList()
    ..sort((a, b) => b.monthKey.compareTo(a.monthKey));

  return summaries;
}

DateTime? _parseRoiDate(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(raw);
    } catch (_) {
      return null;
    }
  }
}

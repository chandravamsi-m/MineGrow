import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../withdrawal/data/withdrawals_repository.dart';

class WithdrawalHistoryScreen extends ConsumerStatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  ConsumerState<WithdrawalHistoryScreen> createState() =>
      _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState
    extends ConsumerState<WithdrawalHistoryScreen> {
  int _filter = 0; // 0=All, 1=ROI, 2=Principal

  List<WithdrawalItem> _applyFilter(List<WithdrawalItem> all) {
    return switch (_filter) {
      1 => all.where((item) => item.type == 'roi').toList(),
      2 => all.where((item) => item.type == 'principal').toList(),
      _ => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(withdrawalsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'Withdrawal History', showBack: true),
      mainNavigationIndex: 3,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            MGSegmentedControl<int>(
              value: _filter,
              onChanged: (value) => setState(() => _filter = value),
              items: const [
                MGSegment(label: 'All', value: 0),
                MGSegment(label: 'ROI', value: 1),
                MGSegment(label: 'Principal', value: 2),
              ],
            ),
            const SizedBox(height: 16),
            historyState.when(
              loading: () => const MGLoadingList(),
              error: (error, stackTrace) => MGFriendlyState(
                icon: Icons.receipt_long_outlined,
                title: 'Withdrawals could not load',
                message:
                    'Your requests are still recorded. Please retry to refresh the list.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(withdrawalsProvider),
              ),
              data: (history) {
                final filtered = _applyFilter(history);
                if (filtered.isEmpty) {
                  return MGFriendlyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: history.isEmpty
                        ? 'No withdrawals yet'
                        : 'No ${_filter == 1 ? 'ROI' : 'Principal'} withdrawals',
                    message: history.isEmpty
                        ? 'Requested withdrawals and their approval status will appear here.'
                        : 'Switch to "All" to see all your withdrawal requests.',
                  );
                }

                return Column(
                  children: [
                    for (final item in filtered) ...[
                      _WithdrawalRow(item: item),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalRow extends StatelessWidget {
  const _WithdrawalRow({required this.item});

  final WithdrawalItem item;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(item.amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.type.toUpperCase()} Withdrawal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MGStatusChip(status: item.chipStatus),
              const SizedBox(height: 8),
              Text(
                item.requestedAt,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

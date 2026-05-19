import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../withdrawal/data/withdrawals_repository.dart';

class WithdrawalHistoryScreen extends ConsumerWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(withdrawalsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'Withdrawal History', showBack: true),
      mainNavigationIndex: 3,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            MGSegmentedControl<int>(
              value: 0,
              onChanged: (_) {},
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
                if (history.isEmpty) {
                  return const MGFriendlyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No withdrawals yet',
                    message:
                        'Requested withdrawals and their approval status will appear here.',
                  );
                }

                return Column(
                  children: [
                    for (final item in history) ...[
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

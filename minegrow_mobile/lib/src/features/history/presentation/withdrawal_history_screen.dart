import 'package:flutter/material.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/widgets/mg_widgets.dart';

class WithdrawalHistoryScreen extends StatelessWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = mockIsLoading('withdrawalHistory');
    final hasLoadError = mockHasLoadError('withdrawalHistory');
    final history = withdrawalHistory;

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
            if (isLoading)
              const MGLoadingList()
            else if (hasLoadError)
              MGFriendlyState(
                icon: Icons.receipt_long_outlined,
                title: 'Withdrawals could not load',
                message:
                    'Your requests are still recorded. Please retry to refresh the list.',
                actionLabel: 'Retry',
                onAction: () {},
              )
            else if (history.isEmpty)
              MGFriendlyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No withdrawals yet',
                message:
                    'Requested withdrawals and their approval status will appear here.',
              )
            else
              for (final item in history) ...[
                MGCard(
                  padding: EdgeInsets.all(context.metrics.compactPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.tokens.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          MGStatusChip(status: item.status!),
                          const SizedBox(height: 8),
                          Text(
                            item.date,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

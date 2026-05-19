import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../wallet/data/wallet_repository.dart';

class RoiHistoryScreen extends ConsumerWidget {
  const RoiHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(roiHistoryProvider);

    return MGScaffold(
      appBar: MGAppBar(
        title: 'ROI History',
        action: TextButton(
          onPressed: () => context.go(AppRoutes.withdrawalHistory),
          child: const Text('Withdrawals'),
        ),
      ),
      mainNavigationIndex: 3,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            MGCard(
              gradient: context.tokens.principalGradient,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total ROI Earned',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.tokens.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        historyState.maybeWhen(
                          data: (history) {
                            final total = history.fold<num>(
                              0,
                              (sum, item) => sum + item.amount,
                            );
                            return Text(
                              formatCurrency(total),
                              style: Theme.of(context).textTheme.headlineSmall,
                            );
                          },
                          orElse: () => Text(
                            formatCurrency(0),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      context.metrics.radiusSmall,
                    ),
                    child: Image.asset(
                      AppAssets.historyScroll,
                      width: 86,
                      height: 66,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            historyState.when(
              loading: () => const MGLoadingList(),
              error: (error, stackTrace) => MGFriendlyState(
                icon: Icons.sync_problem_outlined,
                title: 'ROI history is unavailable',
                message:
                    'We could not fetch your latest credits. Try again in a moment.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(roiHistoryProvider),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return const MGFriendlyState(
                    icon: Icons.history_toggle_off_outlined,
                    title: 'No ROI credits yet',
                    message:
                        'Your daily ROI entries will show here once your plan starts earning.',
                  );
                }

                return Column(
                  children: [
                    for (final item in history) _HistoryRow(item: item),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final RoiHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MGCard(
        padding: EdgeInsets.all(context.metrics.compactPadding),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.creditedDate,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Investment ID : #INV${item.investmentId}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${formatCurrency(item.amount)}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: context.tokens.success),
            ),
          ],
        ),
      ),
    );
  }
}

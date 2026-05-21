import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../investments/data/investments_repository.dart';
import '../data/wallet_repository.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletSummaryProvider);
    final investmentsState = ref.watch(ownInvestmentsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'My Wallet'),
      mainNavigationIndex: 2,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: walletState.when(
          loading: () => const MGLoadingList(itemCount: 2),
          error: (error, stackTrace) => MGFriendlyState(
            icon: Icons.wallet_outlined,
            title: 'Wallet could not load',
            message:
                'Login again or check your connection to refresh wallet balances.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(walletSummaryProvider),
          ),
          data: (wallet) {
            final activePlans = investmentsState.maybeWhen(
              data: (list) => list.where((i) => i.isActive).toList(),
              orElse: () => const <InvestmentRecord>[],
            );
            final roiLabel = activePlans.isNotEmpty
                ? '+${activePlans.first.dailyRoiPct.toStringAsFixed(activePlans.first.dailyRoiPct % 1 == 0 ? 0 : 1)}% daily'
                : null;

            if (wallet.totalBalance == 0 && wallet.totalRoiEarned == 0) {
              return MGFriendlyState(
                icon: Icons.wallet_outlined,
                title: 'Wallet is not active yet',
                message:
                    'Your ROI and principal balances will appear after your first approved investment.',
              );
            }

            return Column(
              children: [
                MGCard(
                  gradient: context.tokens.walletGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ROI Wallet',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          if (roiLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.tokens.success.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                roiLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: context.tokens.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatCurrency(wallet.roiBalance),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Total Earnings',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                      Text(
                        formatCurrency(wallet.totalRoiEarned),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: MGMiniLineChart(
                              color: context.tokens.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              context.metrics.radiusSmall,
                            ),
                            child: Image.asset(
                              AppAssets.walletCards,
                              width: 92,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                MGCard(
                  gradient: context.tokens.principalGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Principal Wallet',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          const MGStatusChip(status: MGStatus.locked),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        formatCurrency(wallet.principalBalance),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Total Invested',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                      Text(
                        formatCurrency(wallet.totalBalance),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      MGMiniLineChart(color: context.tokens.brandGold),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                MGGradientButton(
                  label: 'Withdraw ROI',
                  icon: Icons.arrow_upward,
                  onPressed: () => context.go(AppRoutes.withdrawal),
                ),
                const SizedBox(height: 14),
                MGInlineMessage(
                  message:
                      'Principal balance is locked until the plan term ends. ROI balance can be withdrawn when eligible.',
                  tone: MGMessageTone.warning,
                  icon: Icons.lock_outline,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

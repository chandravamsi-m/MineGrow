import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../investments/data/investments_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../wallet/data/wallet_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletSummaryProvider);
    final profileState = ref.watch(profileProvider);
    final investmentsState = ref.watch(ownInvestmentsProvider);
    final wallet = walletState.maybeWhen(
      data: (value) => value,
      orElse: WalletSummary.empty,
    );
    final profileName = profileState.maybeWhen(
      data: (value) => value.fullName,
      orElse: () => 'Investor',
    );
    final investments = investmentsState.maybeWhen(
      data: (value) => value,
      orElse: () => const <InvestmentRecord>[],
    );
    final activePlans = investments.where((item) => item.isActive).length;
    final totalInvested = investments.fold<num>(
      0,
      (sum, item) => sum + item.amount,
    );
    final hasActivePlan = activePlans > 0 || wallet.totalBalance > 0;

    return MGScaffold(
      appBar: MGAppBar(
        title: 'Hello, $profileName',
        action: IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: () => context.go(AppRoutes.notifications),
        ),
      ),
      mainNavigationIndex: 0,
      backFallbackRoute: null,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            walletState.when(
              loading: () => const MGLoadingList(itemCount: 1),
              error: (error, stackTrace) => MGFriendlyState(
                icon: Icons.cloud_off_outlined,
                title: 'Dashboard could not refresh',
                message:
                    'Login again or check your connection to load wallet totals.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(walletSummaryProvider),
              ),
              data: (wallet) => MGCard(
                gradient: context.tokens.walletGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Wallet Balance',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                        ),
                        const Icon(Icons.visibility_outlined, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCurrency(wallet.totalBalance),
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _BalanceMetric(
                            'ROI Wallet',
                            formatCurrency(wallet.roiBalance),
                          ),
                        ),
                        Expanded(
                          child: _BalanceMetric(
                            'Principal Wallet',
                            formatCurrency(wallet.principalBalance),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                MGStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Investment',
                  value: formatCurrency(totalInvested),
                ),
                MGStatCard(
                  icon: Icons.trending_up,
                  label: 'Total Earnings',
                  value: formatCurrency(wallet.totalRoiEarned),
                ),
                MGStatCard(
                  icon: Icons.savings_outlined,
                  label: 'ROI Wallet',
                  value: formatCurrency(wallet.roiBalance),
                ),
                MGStatCard(
                  icon: Icons.layers_outlined,
                  label: 'Active Plans',
                  value: activePlans.toString(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (hasActivePlan)
              MGCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Principal Unlock',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track active plans from Investments',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          const MGProgressBar(value: 0.5),
                          const SizedBox(height: 10),
                          Text(
                            'Synced from backend wallet data',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const MGCircularProgress(value: 0.5, label: '50%'),
                  ],
                ),
              )
            else
              MGFriendlyState(
                icon: Icons.layers_clear_outlined,
                title: 'No active investment yet',
                message:
                    'Start with a plan to unlock daily ROI, wallet insights, and principal tracking.',
                actionLabel: 'View Plans',
                onAction: () => context.go(AppRoutes.investments),
              ),
            const SizedBox(height: 14),
            MGInlineMessage(
              message:
                  'Principal withdrawals unlock after the lock period. ROI remains available based on plan rules.',
              tone: MGMessageTone.info,
              icon: Icons.lock_clock_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.tokens.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

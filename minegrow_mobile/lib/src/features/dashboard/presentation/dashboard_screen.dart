import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/widgets/mg_widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasActivePlan = mockHasData('activePlan');

    return MGScaffold(
      appBar: MGAppBar(
        title: 'Hello, Ramesh 👋',
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
            MGCard(
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
                    '₹ 45,750.00',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _BalanceMetric('ROI Wallet', '₹ 15,750.00'),
                      ),
                      Expanded(
                        child: _BalanceMetric(
                          'Principal Wallet',
                          '₹ 30,000.00',
                        ),
                      ),
                    ],
                  ),
                ],
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
              children: const [
                MGStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Investment',
                  value: '₹ 1,00,000.00',
                ),
                MGStatCard(
                  icon: Icons.trending_up,
                  label: 'Total Earnings',
                  value: '₹ 25,750.00',
                ),
                MGStatCard(
                  icon: Icons.savings_outlined,
                  label: 'Daily ROI',
                  value: '₹ 1,000.00',
                ),
                MGStatCard(
                  icon: Icons.layers_outlined,
                  label: 'Active Plans',
                  value: '2',
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
                            '90 Days Lock',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                          const SizedBox(height: 18),
                          const MGProgressBar(value: 0.5),
                          const SizedBox(height: 10),
                          Text(
                            '45 Days Completed',
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

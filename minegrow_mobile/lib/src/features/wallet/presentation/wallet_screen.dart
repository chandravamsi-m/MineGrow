import 'package:flutter/material.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/widgets/mg_widgets.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hasWalletData = mockHasData('wallet');

    return MGScaffold(
      appBar: const MGAppBar(title: 'My Wallet'),
      mainNavigationIndex: 2,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          children: [
            if (!hasWalletData)
              MGFriendlyState(
                icon: Icons.wallet_outlined,
                title: 'Wallet is not active yet',
                message:
                    'Your ROI and principal balances will appear after your first approved investment.',
              )
            else ...[
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
                            '+12.5%',
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
                      '₹ 15,750.00',
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
                      '₹ 25,750.00',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: MGMiniLineChart(color: context.tokens.success),
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
                      '₹ 30,000.00',
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
                      '₹ 1,00,000.00',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    MGMiniLineChart(color: context.tokens.brandGold),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              MGInlineMessage(
                message:
                    'Principal balance is locked until the plan term ends. ROI balance can be withdrawn when eligible.',
                tone: MGMessageTone.warning,
                icon: Icons.lock_outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

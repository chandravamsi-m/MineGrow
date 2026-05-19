import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/investments_repository.dart';

class InvestmentPlansScreen extends ConsumerWidget {
  const InvestmentPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansState = ref.watch(investmentPlansProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'Investment Plans'),
      mainNavigationIndex: 1,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a plan and start investing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            plansState.when(
              loading: () => const MGLoadingList(),
              error: (error, stackTrace) => MGFriendlyState(
                icon: Icons.cloud_off_outlined,
                title: 'Plans could not load',
                message:
                    'Check your connection and try again. Your wallet balance is safe.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(investmentPlansProvider),
              ),
              data: (plans) {
                if (plans.isEmpty) {
                  return MGFriendlyState(
                    icon: Icons.landscape_outlined,
                    title: 'No plans available',
                    message:
                        'Investment plans will appear here as soon as they are opened.',
                    actionLabel: 'Refresh',
                    onAction: () => ref.invalidate(investmentPlansProvider),
                  );
                }

                return Column(
                  children: [
                    for (final plan in plans) ...[
                      _PlanCard(plan: plan),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final InvestmentPlan plan;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      onTap: () => context.go(AppRoutes.investmentDetails, extra: plan),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  context.metrics.radiusSmall,
                ),
                child: Image.asset(
                  plan.assetPath,
                  width: 64,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.range,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                    Text(
                      plan.lockPeriod,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.dailyRoi,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.tokens.brandGold,
                    ),
                  ),
                  Text(
                    'Daily ROI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          MGGradientButton(
            label: 'Invest Now',
            onPressed: () =>
                context.go(AppRoutes.investmentDetails, extra: plan),
          ),
        ],
      ),
    );
  }
}

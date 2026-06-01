import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../profile/data/profile_repository.dart';
import '../data/investments_repository.dart';

class InvestmentPlansScreen extends ConsumerStatefulWidget {
  const InvestmentPlansScreen({super.key});

  @override
  ConsumerState<InvestmentPlansScreen> createState() =>
      _InvestmentPlansScreenState();
}

class _InvestmentPlansScreenState extends ConsumerState<InvestmentPlansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(investmentPlansProvider);
    final ownState = ref.watch(ownInvestmentsProvider);
    final metrics = context.metrics;

    final allOwn = ownState.maybeWhen(
      data: (list) => list,
      orElse: () => const <InvestmentRecord>[],
    );
    final activeInvestments = allOwn.where((i) => i.isActive).toList();
    final nonActiveInvestments = allOwn.where((i) => !i.isActive).toList();
    final pendingCount =
        nonActiveInvestments.where((i) => i.status == 'pending').length;

    return MGScaffold(
      appBar: MGAppBar(
        title: 'Investments',
        action: IconButton(
          tooltip: 'Investment history',
          icon: const Icon(Icons.history),
          onPressed: () => context.go(AppRoutes.investmentHistory),
        ),
      ),
      mainNavigationIndex: 1,
      scrollable: false,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.screenPadding,
              metrics.screenPadding,
              metrics.screenPadding,
              0,
            ),
            child: _InvestmentTabBar(
              controller: _tabController,
              activeCount: activeInvestments.length,
              pendingCount: pendingCount,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PlansTab(
                  plansState: plansState,
                  onRetry: () => ref.invalidate(investmentPlansProvider),
                ),
                _ActiveTab(
                  ownState: ownState,
                  investments: activeInvestments,
                  plans: plansState.maybeWhen(
                    data: (list) => list,
                    orElse: () => const <InvestmentPlan>[],
                  ),
                  onGoToPlans: () => _tabController.animateTo(0),
                ),
                _PendingTab(
                  ownState: ownState,
                  investments: nonActiveInvestments,
                  plans: plansState.maybeWhen(
                    data: (list) => list,
                    orElse: () => const <InvestmentPlan>[],
                  ),
                  onGoToPlans: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Bar ──────────────────────────────────────────────────────────────────

class _InvestmentTabBar extends StatelessWidget {
  const _InvestmentTabBar({
    required this.controller,
    required this.activeCount,
    required this.pendingCount,
  });

  final TabController controller;
  final int activeCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metrics = context.metrics;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(metrics.radiusMedium),
        border: Border.all(color: tokens.borderMuted),
      ),
      child: TabBar(
        controller: controller,
        labelColor: tokens.textPrimary,
        unselectedLabelColor: tokens.textSecondary,
        labelStyle: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          gradient: tokens.primaryGradient,
          borderRadius: BorderRadius.circular(metrics.radiusSmall),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(metrics.radiusSmall),
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        tabs: [
          const Tab(height: 38, text: 'Plans'),
          Tab(
            height: 38,
            child: _TabLabel(
              'Active',
              count: activeCount,
              color: tokens.success,
            ),
          ),
          Tab(
            height: 38,
            child: _TabLabel(
              'Pending',
              count: pendingCount,
              color: tokens.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, {required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Plans Tab ────────────────────────────────────────────────────────────────

class _PlansTab extends ConsumerWidget {
  const _PlansTab({required this.plansState, required this.onRetry});

  final AsyncValue<List<InvestmentPlan>> plansState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = context.metrics;
    final profile = ref.watch(profileProvider);
    final accountStatus = profile.maybeWhen(
      data: (p) => p.status,
      orElse: () => '',
    );
    final isPendingKyc = accountStatus == 'pending_kyc';
    final isSuspended = accountStatus == 'suspended';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding + 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a plan and start investing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          if (isPendingKyc || isSuspended) ...[
            const SizedBox(height: 12),
            MGInlineMessage(
              tone: isSuspended ? MGMessageTone.danger : MGMessageTone.warning,
              icon: isSuspended
                  ? Icons.block_outlined
                  : Icons.verified_user_outlined,
              message: isSuspended
                  ? 'Your account is suspended. New investments are blocked until support reactivates the account.'
                  : 'KYC review is in progress. New investments are paused until verification completes — you can still browse plans below.',
            ),
          ],
          const SizedBox(height: 16),
          plansState.when(
            loading: () => const MGLoadingList(),
            error: (error, _) => mgErrorView(
              error: error,
              onRetry: onRetry,
              fallbackIcon: Icons.cloud_off_outlined,
              fallbackTitle: 'Plans could not load',
              fallbackMessage:
                  'Check your connection and try again. Your wallet is safe.',
            ),
            data: (plans) {
              if (plans.isEmpty) {
                return MGFriendlyState(
                  icon: Icons.landscape_outlined,
                  title: 'No plans available',
                  message:
                      'Investment plans will appear here once they are opened.',
                  actionLabel: 'Refresh',
                  onAction: onRetry,
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
    );
  }
}

// ── Active Tab ───────────────────────────────────────────────────────────────

class _ActiveTab extends StatelessWidget {
  const _ActiveTab({
    required this.ownState,
    required this.investments,
    required this.plans,
    required this.onGoToPlans,
  });

  final AsyncValue<List<InvestmentRecord>> ownState;
  final List<InvestmentRecord> investments;
  final List<InvestmentPlan> plans;
  final VoidCallback onGoToPlans;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    if (ownState.isLoading) {
      return Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: const MGLoadingList(itemCount: 2),
      );
    }

    if (ownState.hasError) {
      return Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: const MGFriendlyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load investments',
          message: 'Pull down on the dashboard to refresh.',
        ),
      );
    }

    if (investments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: MGFriendlyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No active investments',
          message:
              'Your approved plans and daily ROI credits will appear here once activated.',
          actionLabel: 'Browse Plans',
          onAction: onGoToPlans,
        ),
      );
    }

    final totalInvested =
        investments.fold<num>(0, (s, i) => s + i.amount);
    final totalDailyRoi = investments.fold<num>(
      0,
      (s, i) => s + (i.amount * i.dailyRoiPct / 100),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding + 80,
      ),
      child: Column(
        children: [
          // Summary row
          Row(
            children: [
              Expanded(
                child: MGStatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Total Invested',
                  value: formatCurrency(totalInvested),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MGStatCard(
                  icon: Icons.trending_up,
                  label: 'Daily Earnings',
                  value: formatCurrency(totalDailyRoi),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final inv in investments) ...[
            _ActiveInvestmentCard(record: inv, plans: plans),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ── Pending Tab ──────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  const _PendingTab({
    required this.ownState,
    required this.investments,
    required this.plans,
    required this.onGoToPlans,
  });

  final AsyncValue<List<InvestmentRecord>> ownState;
  final List<InvestmentRecord> investments;
  final List<InvestmentPlan> plans;
  final VoidCallback onGoToPlans;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    if (ownState.isLoading) {
      return Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: const MGLoadingList(itemCount: 2),
      );
    }

    if (investments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: MGFriendlyState(
          icon: Icons.hourglass_empty_outlined,
          title: 'No submissions yet',
          message:
              'After you pay for a plan it will appear here while our team verifies the payment.',
          actionLabel: 'Browse Plans',
          onAction: onGoToPlans,
        ),
      );
    }

    final hasPending =
        investments.any((i) => i.status == 'pending');
    final hasRejected =
        investments.any((i) => i.status == 'rejected');

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding,
        metrics.screenPadding + 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPending) ...[
            MGInlineMessage(
              message:
                  'Verification typically completes within 24 hours. You will be notified once your plan is activated.',
              tone: MGMessageTone.info,
              icon: Icons.access_time_outlined,
            ),
            const SizedBox(height: 14),
          ],
          for (final inv in investments) ...[
            _PendingInvestmentCard(record: inv, plans: plans),
            const SizedBox(height: 12),
          ],
          if (hasRejected) ...[
            const SizedBox(height: 4),
            MGInlineMessage(
              message:
                  'Rejected payments may have an incorrect UTR or unreadable proof. Contact support to resubmit.',
              tone: MGMessageTone.warning,
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Plan Card (Plans Tab) ─────────────────────────────────────────────────────

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
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
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

// ── Active Investment Card ────────────────────────────────────────────────────

class _ActiveInvestmentCard extends StatelessWidget {
  const _ActiveInvestmentCard({required this.record, required this.plans});

  final InvestmentRecord record;
  final List<InvestmentPlan> plans;

  @override
  Widget build(BuildContext context) {
    final start =
        DateTime.tryParse(record.createdAt)?.toLocal() ?? DateTime.now();
    final elapsed = DateTime.now().difference(start).inDays;
    final lockDays = record.lockDays < 1 ? 1 : record.lockDays;
    final progress = (elapsed / lockDays).clamp(0.0, 1.0);
    final daysRemaining = (record.lockDays - elapsed).clamp(0, record.lockDays);
    final dailyEarnings = record.amount * record.dailyRoiPct / 100;
    final matchedPlan = _findPlanById(plans, record.planId);
    final planName =
        record.planName ?? matchedPlan?.name ?? _fallbackPlanName(record.planId);
    final planIcon = matchedPlan?.icon ?? _fallbackPlanIcon(record.planId);
    final planColor = matchedPlan?.planColor ?? _fallbackPlanColor(record.planId);

    return MGCard(
      gradient: context.tokens.principalGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(planIcon, color: planColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          size: 13,
                          color: context.tokens.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${record.dailyRoiPct}% · ${formatCurrency(dailyEarnings)}/day',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: context.tokens.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(record.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.tokens.brandGold,
                    ),
                  ),
                  Text(
                    'invested',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Lock Progress ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lock Period',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.tokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progress >= 1.0
                      ? context.tokens.success.withValues(alpha: 0.14)
                      : context.tokens.brandOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  progress >= 1.0
                      ? 'Unlocked'
                      : '$daysRemaining days left',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: progress >= 1.0
                        ? context.tokens.success
                        : context.tokens.brandOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MGProgressBar(value: progress.toDouble()),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}% of ${record.lockDays}-day lock elapsed · started ${_formatDate(record.createdAt)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${m[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }
}

// ── Pending Investment Card ───────────────────────────────────────────────────

class _PendingInvestmentCard extends StatelessWidget {
  const _PendingInvestmentCard({required this.record, required this.plans});

  final InvestmentRecord record;
  final List<InvestmentPlan> plans;

  @override
  Widget build(BuildContext context) {
    final isPending = record.status == 'pending';
    final statusColor =
        isPending ? context.tokens.warning : context.tokens.danger;

    return MGCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPending
                  ? Icons.hourglass_top_rounded
                  : Icons.cancel_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(record.amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  record.planName ??
                      _findPlanById(plans, record.planId)?.name ??
                      _fallbackPlanName(record.planId),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                Text(
                  'Submitted ${_formatDate(record.createdAt)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          MGStatusChip(status: _toMGStatus(record.status)),
        ],
      ),
    );
  }

  static MGStatus _toMGStatus(String status) => switch (status) {
    'approved' || 'active' => MGStatus.approved,
    'rejected' => MGStatus.rejected,
    _ => MGStatus.pending,
  };

  static String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Shared plan-lookup helpers ────────────────────────────────────────────────
// These replace the hardcoded per-class switch statements.  The primary path
// looks up the actual InvestmentPlan loaded from the API; the _fallback*
// variants are used only when the plans list hasn't loaded yet.

InvestmentPlan? _findPlanById(List<InvestmentPlan> plans, int planId) {
  for (final plan in plans) {
    if (plan.id == planId) return plan;
  }
  return null;
}

String _fallbackPlanName(int planId) => switch (planId) {
      1 => 'Starter Plan',
      2 => 'Silver Plan',
      3 => 'Gold Plan',
      _ => 'Investment Plan',
    };

IconData _fallbackPlanIcon(int planId) => switch (planId) {
      1 => Icons.landscape_outlined,
      2 => Icons.account_balance_outlined,
      3 => Icons.diamond_outlined,
      _ => Icons.savings_outlined,
    };

Color _fallbackPlanColor(int planId) => switch (planId) {
      1 => const Color(0xFFF59E0B), // brandOrange
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFFDBA2D), // brandGold
      _ => const Color(0xFFFDBA2D),
    };

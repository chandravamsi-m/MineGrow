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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(walletSummaryProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(ownInvestmentsProvider);
    try {
      await Future.wait([
        ref.read(walletSummaryProvider.future),
        ref.read(profileProvider.future),
        ref.read(ownInvestmentsProvider.future),
      ]);
    } catch (_) {
      // Errors are shown via the error states in the UI
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final lockProgress = _lockProgress(investments);

    final screenPad = context.metrics.screenPadding;

    return MGScaffold(
      appBar: MGAppBar(
        title: 'Hello, $profileName',
        action: Semantics(
          label: 'Notifications',
          button: true,
          child: IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.go(AppRoutes.notifications),
          ),
        ),
      ),
      mainNavigationIndex: 0,
      backFallbackRoute: null,
      scrollable: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: context.tokens.brandGold,
        backgroundColor: context.tokens.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              screenPad,
              screenPad,
              screenPad,
              screenPad + 80,
            ),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: context.tokens.textSecondary),
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
                // ── Active Plans section ────────────────────────────────────
                if (investments.any((i) => i.isActive)) ...[
                  const SizedBox(height: 14),
                  SectionTitle(
                    'Active Plans',
                    trailing: TextButton(
                      onPressed: () => context.go(AppRoutes.investments),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'View All',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: context.tokens.brandGold,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final inv in investments.where((i) => i.isActive)) ...[
                    MGActivePlanCard(record: inv),
                    const SizedBox(height: 10),
                  ],
                ],
                // ───────────────────────────────────────────────────────────
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
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Track active plans from Investments',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        color: context.tokens.textSecondary),
                              ),
                              const SizedBox(height: 18),
                              MGProgressBar(value: lockProgress),
                              const SizedBox(height: 10),
                              Text(
                                lockProgress >= 1.0
                                    ? 'Lock period complete — withdrawal available'
                                    : '${(lockProgress * 100).round()}% of lock period elapsed',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: context.tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        MGCircularProgress(
                          value: lockProgress,
                          label: '${(lockProgress * 100).round()}%',
                        ),
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
        ),
      ),
    );
  }
}

double _lockProgress(List<InvestmentRecord> investments) {
  final active = investments.where((i) => i.isActive).toList();
  if (active.isEmpty) return 0;
  active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final rec = active.first;
  final start = DateTime.tryParse(rec.createdAt)?.toLocal() ?? DateTime.now();
  final elapsed = DateTime.now().difference(start).inDays;
  return (elapsed / rec.lockDays).clamp(0.0, 1.0);
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
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: context.tokens.textSecondary),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

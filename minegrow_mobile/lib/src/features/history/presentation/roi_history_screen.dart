import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
            // ── Total ROI header card ─────────────────────────────────────
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
                              style:
                                  Theme.of(context).textTheme.headlineSmall,
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
                  // Decorative asset — excluded from semantics
                  ExcludeSemantics(
                    child: ClipRRect(
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            historyState.maybeWhen(
              data: (history) {
                final monthly = summarizeRoiByMonth(history);
                if (monthly.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _MonthlyRoiSummaryStrip(monthly: monthly),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // ── History list ──────────────────────────────────────────────
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

// ── History Row ───────────────────────────────────────────────────────────────

class _MonthlyRoiSummaryStrip extends StatelessWidget {
  const _MonthlyRoiSummaryStrip({required this.monthly});

  final List<MonthlyRoiSummary> monthly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: monthly.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = monthly[index];
          return SizedBox(
            width: 166,
            child: MGCard(
              padding: EdgeInsets.all(context.metrics.compactPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  Text(
                    formatCurrency(item.total),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.tokens.success,
                    ),
                  ),
                  Text(
                    '${item.entries} ROI credits',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final RoiHistoryItem item;

  /// Formats "2026-05-21" → "21 May 2026".
  /// Falls back to the raw string if parsing fails.
  static String _formatDate(String raw) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(raw);
      return DateFormat('d MMM yyyy').format(date);
    } catch (_) {
      // Might already be a formatted string or a full ISO datetime
      try {
        final dt = DateTime.parse(raw).toLocal();
        return DateFormat('d MMM yyyy').format(dt);
      } catch (_) {
        return raw;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDate(item.creditedDate);
    final creditLabel = '+${formatCurrency(item.amount)}';

    return Semantics(
      label: 'ROI credit of $creditLabel on $formattedDate, '
          'Investment #${item.investmentId}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MGCard(
          padding: EdgeInsets.all(context.metrics.compactPadding),
          child: Row(
            children: [
              // Income icon — green to reinforce positive credit
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.tokens.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: context.tokens.success,
                ),
              ),
              const SizedBox(width: 12),

              // Date & Investment ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Investment #${item.investmentId}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.tokens.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),

              // Amount
              Text(
                creditLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.tokens.success,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

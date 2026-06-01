import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../investments/data/investments_repository.dart';

/// Chronological ledger of every investment/deposit the user has made,
/// including approved, pending, and rejected entries. Complements the ROI and
/// withdrawal history screens (which cover credits and payouts).
class InvestmentHistoryScreen extends ConsumerWidget {
  const InvestmentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsState = ref.watch(ownInvestmentsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'Investment History', showBack: true),
      mainNavigationIndex: 1,
      body: investmentsState.when(
        loading: () => const MGLoadingList(),
        error: (error, _) => mgErrorView(
          error: error,
          onRetry: () => ref.invalidate(ownInvestmentsProvider),
          fallbackIcon: Icons.receipt_long_outlined,
          fallbackTitle: 'History unavailable',
          fallbackMessage:
              'We could not load your investment history. Please try again.',
        ),
        data: (records) {
          if (records.isEmpty) {
            return const MGFriendlyState(
              icon: Icons.savings_outlined,
              title: 'No investments yet',
              message:
                  'Your deposits will appear here once you fund an investment plan.',
            );
          }
          final sorted = [...records]..sort((a, b) => b.id.compareTo(a.id));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final record in sorted) ...[
                _InvestmentRow(record: record),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.record});

  final InvestmentRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final date = _formatDate(record.createdAt);

    return MGCard(
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.planName ?? 'Investment plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  formatCurrency(record.amount),
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: tokens.brandGold),
                ),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: tokens.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          MGStatusChip(status: _toMGStatus(record.status)),
        ],
      ),
    );
  }

  MGStatus _toMGStatus(String status) {
    final s = status.toLowerCase();
    if (s == 'approved' || s == 'active') return MGStatus.approved;
    if (s.contains('reject') || s.contains('fail') || s.contains('cancel')) {
      return MGStatus.rejected;
    }
    return MGStatus.pending;
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }
}

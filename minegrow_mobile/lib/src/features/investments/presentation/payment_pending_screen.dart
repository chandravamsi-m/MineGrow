import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/investments_repository.dart';

/// Shows the submitted payment as a receipt and tracks its review status live.
///
/// After a payment is submitted the server holds it as `pending` until a human
/// approves or rejects it. This screen polls [ownInvestmentsProvider] so the
/// user sees the outcome without leaving — and stops polling as soon as the
/// status resolves (or after a few minutes) to avoid draining the battery.
class PaymentPendingScreen extends ConsumerStatefulWidget {
  const PaymentPendingScreen({super.key, this.args});

  /// Details of the payment just submitted, used to render the receipt
  /// immediately. Null when the screen is reached without that context (e.g.
  /// deep link), in which case the most recent investment is used.
  final PaymentArgs? args;

  @override
  ConsumerState<PaymentPendingScreen> createState() =>
      _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends ConsumerState<PaymentPendingScreen> {
  static const _pollInterval = Duration(seconds: 12);
  static const _maxPolls = 15; // ~3 minutes of active polling.

  Timer? _timer;
  int _polls = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _polls = 0;
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _poll() {
    final records = ref.read(ownInvestmentsProvider).value ?? const [];
    final status = _statusFor(_resolveRecord(records));
    if (status != _PaymentStatus.pending || _polls >= _maxPolls) {
      _timer?.cancel();
      return;
    }
    _polls++;
    ref.invalidate(ownInvestmentsProvider);
  }

  void _refreshNow() {
    ref.invalidate(ownInvestmentsProvider);
    _startPolling();
  }

  /// Picks the investment this screen represents: the newest record for the
  /// submitted plan when known, otherwise the newest record overall.
  InvestmentRecord? _resolveRecord(List<InvestmentRecord> records) {
    if (records.isEmpty) return null;
    Iterable<InvestmentRecord> pool = records;
    final planId = widget.args?.plan.id;
    if (planId != null) {
      final matching = records.where((r) => r.planId == planId);
      if (matching.isNotEmpty) pool = matching;
    }
    return pool.reduce((a, b) => a.id >= b.id ? a : b);
  }

  _PaymentStatus _statusFor(InvestmentRecord? record) {
    if (record == null) return _PaymentStatus.pending;
    if (record.isActive) return _PaymentStatus.approved;
    final s = record.status.toLowerCase();
    if (s.contains('reject') || s.contains('fail') || s.contains('cancel')) {
      return _PaymentStatus.rejected;
    }
    return _PaymentStatus.pending;
  }

  @override
  Widget build(BuildContext context) {
    final investmentsState = ref.watch(ownInvestmentsProvider);

    return MGScaffold(
      backFallbackRoute: AppRoutes.investments,
      mainNavigationIndex: 1,
      body: investmentsState.when(
        loading: () => widget.args == null
            ? const MGLoadingList(itemCount: 2)
            : _buildContent(context, _PaymentStatus.pending, null),
        error: (error, _) => widget.args == null
            ? mgErrorView(
                error: error,
                onRetry: _refreshNow,
                fallbackIcon: Icons.hourglass_top_rounded,
                fallbackTitle: 'Could not load payment status',
                fallbackMessage:
                    'Your payment is still recorded. Pull to refresh to check again.',
              )
            : _buildContent(context, _PaymentStatus.pending, null),
        data: (records) {
          final record = _resolveRecord(records);
          return _buildContent(context, _statusFor(record), record);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    _PaymentStatus status,
    InvestmentRecord? record,
  ) {
    final tokens = context.tokens;
    final (color, icon, title, message) = switch (status) {
      _PaymentStatus.pending => (
          tokens.warning,
          Icons.hourglass_top_rounded,
          'Payment Under Review',
          'Your payment details have been received. Our team will verify your '
              'transaction and activate your investment plan.',
        ),
      _PaymentStatus.approved => (
          tokens.success,
          Icons.check_circle_outline_rounded,
          'Investment Active',
          'Your payment was approved and your plan is now active. Daily ROI '
              'will start accruing as per your plan terms.',
        ),
      _PaymentStatus.rejected => (
          tokens.danger,
          Icons.cancel_outlined,
          'Payment Not Approved',
          'We could not verify this payment. If you believe this is a mistake, '
              'contact support or submit a new payment with a valid proof.',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.28), width: 2),
            ),
            child: Icon(icon, size: 46, color: color),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
                height: 1.55,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        _ReceiptCard(args: widget.args, record: record, status: status),
        const SizedBox(height: 20),
        if (status == _PaymentStatus.pending) ...[
          MGInlineMessage(
            message: _timer?.isActive ?? false
                ? 'Checking for updates automatically. Verification usually '
                    'completes within 24 hours.'
                : 'Verification usually completes within 24 hours. Tap refresh '
                    'to check the latest status.',
            tone: MGMessageTone.info,
            icon: Icons.access_time_outlined,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _refreshNow,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: tokens.textPrimary,
                side: BorderSide(color: tokens.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(context.metrics.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        MGGradientButton(
          label: status == _PaymentStatus.approved
              ? 'View My Investment'
              : 'View My Investments',
          icon: Icons.account_balance_wallet_outlined,
          onPressed: () => context.go(AppRoutes.investments),
        ),
      ],
    );
  }
}

enum _PaymentStatus { pending, approved, rejected }

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.args,
    required this.record,
    required this.status,
  });

  final PaymentArgs? args;
  final InvestmentRecord? record;
  final _PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final planName =
        args?.plan.name ?? record?.planName ?? 'Investment plan';
    final amount = args?.amount ?? record?.amount;
    final submittedAt = _formatDate(record?.createdAt);

    final (statusLabel, statusColor) = switch (status) {
      _PaymentStatus.pending => ('Pending review', tokens.warning),
      _PaymentStatus.approved => ('Approved', tokens.success),
      _PaymentStatus.rejected => ('Not approved', tokens.danger),
    };

    return MGCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment receipt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          _row(context, 'Plan', planName),
          if (amount != null) ...[
            const SizedBox(height: 10),
            _row(context, 'Amount', formatCurrency(amount)),
          ],
          if (record?.id != null) ...[
            const SizedBox(height: 10),
            _row(context, 'Reference', '#${record!.id}'),
          ],
          if (submittedAt != null) ...[
            const SizedBox(height: 10),
            _row(context, 'Submitted', submittedAt),
          ],
          const SizedBox(height: 10),
          _row(context, 'Status', statusLabel, valueColor: statusColor),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final tokens = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: tokens.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? tokens.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy, hh:mm a').format(parsed.toLocal());
  }
}

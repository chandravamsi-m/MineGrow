import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/withdrawals_repository.dart';

enum WithdrawalWallet { roi, principal }

enum WithdrawalMethod { bank, upi }

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController(text: '5000');
  WithdrawalWallet _wallet = WithdrawalWallet.roi;
  WithdrawalMethod? _method = WithdrawalMethod.bank;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _requestWithdrawal() async {
    final amount = num.tryParse(_amountController.text.trim());

    setState(() {
      if (amount == null || amount <= 0) {
        _errorText = 'Enter a valid withdrawal amount.';
        return;
      }

      if (_method == null) {
        _errorText = 'Choose a withdrawal method before requesting payout.';
        return;
      }

      _errorText = null;
      _isSubmitting = true;
    });

    if (_errorText != null || amount == null) {
      return;
    }

    try {
      final repository = ref.read(withdrawalsRepositoryProvider);
      if (_wallet == WithdrawalWallet.roi) {
        await repository.requestRoiWithdrawal(
          amount: amount,
          upiId: 'demo@upi',
        );
      } else {
        await repository.requestPrincipalWithdrawal(
          amount: amount,
          upiId: 'demo@upi',
        );
      }
      ref.invalidate(withdrawalEligibilityProvider);
      ref.invalidate(withdrawalsProvider);
      setState(() {
        _errorText = 'Withdrawal request submitted successfully.';
      });
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() {
        _errorText = 'Could not submit withdrawal. Try again later.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibilityState = ref.watch(withdrawalEligibilityProvider);
    final isPrincipal = _wallet == WithdrawalWallet.principal;
    final eligibility = eligibilityState.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final balance = eligibility == null
        ? 0
        : isPrincipal
        ? eligibility.principalBalance
        : eligibility.roiBalance;
    final eligibilityMessage = eligibility == null
        ? 'Login to check withdrawal eligibility.'
        : isPrincipal
        ? eligibility.principalMessage
        : eligibility.roiMessage;

    return MGScaffold(
      appBar: const MGAppBar(title: 'Withdraw', showBack: true),
      mainNavigationIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MGSegmentedControl<WithdrawalWallet>(
            value: _wallet,
            onChanged: (value) {
              setState(() {
                _wallet = value;
                _errorText = value == WithdrawalWallet.principal
                    ? 'Principal wallet is locked for 45 more days.'
                    : null;
              });
            },
            items: const [
              MGSegment(label: 'ROI Withdrawal', value: WithdrawalWallet.roi),
              MGSegment(
                label: 'Principal Withdrawal',
                value: WithdrawalWallet.principal,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MGCard(
            gradient: context.tokens.walletGradient,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available for Withdrawal',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(balance),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          if (eligibilityState.isLoading) ...[
            const SizedBox(height: 14),
            const MGLoadingList(itemCount: 1),
          ] else if (eligibilityState.hasError) ...[
            const SizedBox(height: 14),
            MGFriendlyState(
              icon: Icons.sync_problem_outlined,
              title: 'Eligibility could not load',
              message: 'Check your connection before requesting a withdrawal.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(withdrawalEligibilityProvider),
              compact: true,
            ),
          ] else ...[
            const SizedBox(height: 14),
            MGInlineMessage(
              message: _errorText ?? eligibilityMessage,
              tone: _errorText == 'Withdrawal request submitted successfully.'
                  ? MGMessageTone.success
                  : isPrincipal
                  ? MGMessageTone.warning
                  : MGMessageTone.info,
              icon: _errorText == 'Withdrawal request submitted successfully.'
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
            ),
          ],
          const SizedBox(height: 20),
          MGTextField(
            label: 'Enter Amount',
            hintText: '5000',
            keyboardType: TextInputType.number,
            controller: _amountController,
            prefix: const Text('Rs'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              AmountChip('Rs 1,000'),
              AmountChip('Rs 5,000'),
              AmountChip('Rs 10,000'),
              AmountChip('All'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Select Withdrawal Method',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _method = WithdrawalMethod.bank);
                  },
                  icon: const Icon(Icons.account_balance_outlined),
                  label: const Text('Bank Account'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _method = WithdrawalMethod.upi);
                  },
                  icon: const Icon(Icons.phone_android),
                  label: const Text('UPI'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          MGGradientButton(
            label: _isSubmitting ? 'Submitting...' : 'Request Withdrawal',
            onPressed: _isSubmitting ? null : _requestWithdrawal,
          ),
        ],
      ),
    );
  }
}

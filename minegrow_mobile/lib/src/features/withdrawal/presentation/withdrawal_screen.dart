import 'package:flutter/material.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/widgets/mg_widgets.dart';

enum WithdrawalWallet { roi, principal }

enum WithdrawalMethod { bank, upi }

class WithdrawalScreen extends StatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _amountController = TextEditingController(text: '5000');
  WithdrawalWallet _wallet = WithdrawalWallet.roi;
  WithdrawalMethod? _method = WithdrawalMethod.bank;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _requestWithdrawal() {
    final amount = num.tryParse(_amountController.text.trim());
    setState(() {
      if (_wallet == WithdrawalWallet.principal) {
        _errorText =
            'Principal withdrawals are locked until the plan lock period ends.';
        return;
      }

      if (amount == null || amount <= 0) {
        _errorText = 'Enter a valid withdrawal amount.';
        return;
      }

      if (amount > 15750) {
        _errorText = 'Amount cannot be higher than your available ROI wallet.';
        return;
      }

      if (_method == null) {
        _errorText = 'Choose a withdrawal method before requesting payout.';
        return;
      }

      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPrincipal = _wallet == WithdrawalWallet.principal;

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
                  isPrincipal ? '₹ 0.00' : '₹ 15,750.00',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            MGInlineMessage(
              message: _errorText!,
              tone: isPrincipal ? MGMessageTone.warning : MGMessageTone.danger,
              icon: isPrincipal
                  ? Icons.lock_clock_outlined
                  : Icons.error_outline,
            ),
          ],
          const SizedBox(height: 20),
          MGTextField(
            label: 'Enter Amount',
            hintText: '5000',
            keyboardType: TextInputType.number,
            controller: _amountController,
            prefix: const Text('₹'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              AmountChip('₹1,000'),
              AmountChip('₹5,000'),
              AmountChip('₹10,000'),
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
            label: 'Request Withdrawal',
            onPressed: _requestWithdrawal,
          ),
        ],
      ),
    );
  }
}

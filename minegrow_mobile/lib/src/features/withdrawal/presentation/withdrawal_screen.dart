import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../profile/data/profile_repository.dart';
import '../data/withdrawals_repository.dart';

enum WithdrawalWallet { roi, principal }

enum WithdrawalMethod { bank, upi }

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _upiController = TextEditingController();
  WithdrawalWallet _wallet = WithdrawalWallet.roi;
  WithdrawalMethod _method = WithdrawalMethod.bank;
  int? _selectedBankAccountId;
  String? _errorText;
  bool _isSubmitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _amountController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _requestWithdrawal(num balance) async {
    final amount = num.tryParse(_amountController.text.trim());
    final upi = _upiController.text.trim();

    setState(() {
      if (amount == null || amount <= 0) {
        _errorText = 'Enter a valid withdrawal amount.';
        return;
      }
      if (amount > balance) {
        _errorText = 'Amount exceeds your available balance.';
        return;
      }
      if (_method == WithdrawalMethod.upi && upi.isEmpty) {
        _errorText = 'Enter your UPI ID to proceed.';
        return;
      }
      if (_method == WithdrawalMethod.bank &&
          _selectedBankAccountId == null) {
        _errorText = 'Select a bank account to proceed.';
        return;
      }
      _errorText = null;
      _isSubmitting = true;
      _submitted = false;
    });

    if (_errorText != null || amount == null) return;

    try {
      final repo = ref.read(withdrawalsRepositoryProvider);
      if (_wallet == WithdrawalWallet.roi) {
        await repo.requestRoiWithdrawal(
          amount: amount,
          upiId: _method == WithdrawalMethod.upi ? upi : null,
          bankAccountId:
              _method == WithdrawalMethod.bank ? _selectedBankAccountId : null,
        );
      } else {
        await repo.requestPrincipalWithdrawal(
          amount: amount,
          upiId: _method == WithdrawalMethod.upi ? upi : null,
          bankAccountId:
              _method == WithdrawalMethod.bank ? _selectedBankAccountId : null,
        );
      }
      ref.invalidate(withdrawalEligibilityProvider);
      ref.invalidate(withdrawalsProvider);
      if (mounted) {
        setState(() {
          _submitted = true;
          _errorText = null;
          _amountController.text = '';
          _upiController.text = '';
          _selectedBankAccountId = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorText = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorText = 'Could not submit withdrawal. Try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligibilityState = ref.watch(withdrawalEligibilityProvider);
    final bankAccountsState = ref.watch(bankAccountsProvider);
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
    final isEligible = eligibility == null
        ? false
        : isPrincipal
        ? eligibility.principalEligible
        : eligibility.roiEligible;

    return MGScaffold(
      appBar: const MGAppBar(title: 'Withdraw', showBack: true),
      mainNavigationIndex: 2,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MGSegmentedControl<WithdrawalWallet>(
            value: _wallet,
            onChanged: (value) => setState(() {
              _wallet = value;
              _errorText = null;
              _submitted = false;
            }),
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
            if (_submitted)
              MGInlineMessage(
                message: 'Withdrawal request submitted. You will be notified once processed.',
                tone: MGMessageTone.success,
                icon: Icons.check_circle_outline,
              )
            else if (_errorText != null)
              MGInlineMessage(
                message: _errorText!,
                tone: MGMessageTone.warning,
                icon: Icons.warning_amber_outlined,
              )
            else
              MGInlineMessage(
                message: eligibilityMessage,
                tone: isPrincipal ? MGMessageTone.warning : MGMessageTone.info,
                icon: isPrincipal
                    ? Icons.lock_clock_outlined
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
            children: [
              _AmountChip(
                label: '25%',
                onTap: () => setState(() => _amountController.text =
                    (balance * 0.25).round().toString()),
              ),
              _AmountChip(
                label: '50%',
                onTap: () => setState(() => _amountController.text =
                    (balance * 0.50).round().toString()),
              ),
              _AmountChip(
                label: '75%',
                onTap: () => setState(() => _amountController.text =
                    (balance * 0.75).round().toString()),
              ),
              _AmountChip(
                label: 'All',
                onTap: () => setState(
                  () => _amountController.text = balance.toStringAsFixed(0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Withdrawal Method',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MethodButton(
                  icon: Icons.account_balance_outlined,
                  label: 'Bank Account',
                  selected: _method == WithdrawalMethod.bank,
                  onTap: () =>
                      setState(() => _method = WithdrawalMethod.bank),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodButton(
                  icon: Icons.phone_android,
                  label: 'UPI',
                  selected: _method == WithdrawalMethod.upi,
                  onTap: () =>
                      setState(() => _method = WithdrawalMethod.upi),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_method == WithdrawalMethod.upi) ...[
            MGTextField(
              label: 'UPI ID',
              hintText: 'yourname@upi',
              controller: _upiController,
              keyboardType: TextInputType.emailAddress,
              prefix: const Icon(Icons.phone_android, size: 18),
            ),
          ] else ...[
            _BankAccountSelector(
              bankAccountsState: bankAccountsState,
              selectedId: _selectedBankAccountId,
              onSelect: (id) =>
                  setState(() => _selectedBankAccountId = id),
            ),
          ],
          const SizedBox(height: 28),
          MGGradientButton(
            label: _isSubmitting ? 'Submitting...' : 'Request Withdrawal',
            onPressed:
                (_isSubmitting || !isEligible) ? null : () => _requestWithdrawal(balance),
          ),
          if (!isEligible && eligibility != null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Withdrawal not available for this wallet yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Method Button ─────────────────────────────────────────────────────────────

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: selected ? context.tokens.primaryGradient : null,
          color: selected ? null : context.tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : context.tokens.borderMuted,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? context.tokens.textPrimary
                  : context.tokens.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? context.tokens.textPrimary
                    : context.tokens.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Amount Chip ───────────────────────────────────────────────────────────────

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AmountChip(label),
    );
  }
}

// ── Bank Account Selector ─────────────────────────────────────────────────────

class _BankAccountSelector extends StatelessWidget {
  const _BankAccountSelector({
    required this.bankAccountsState,
    required this.selectedId,
    required this.onSelect,
  });

  final AsyncValue<List<BankAccount>> bankAccountsState;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return bankAccountsState.when(
      loading: () => const MGLoadingList(itemCount: 1),
      error: (e, st) => const MGInlineMessage(
        message: 'Could not load bank accounts. Check Profile settings.',
        tone: MGMessageTone.warning,
        icon: Icons.warning_amber_outlined,
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const MGInlineMessage(
            message:
                'No bank accounts linked. Add one via Profile → Bank Accounts.',
            tone: MGMessageTone.warning,
            icon: Icons.account_balance_outlined,
          );
        }
        return Column(
          children: [
            for (final account in accounts) ...[
              _BankAccountTile(
                account: account,
                selected: account.id == selectedId,
                onTap: () => onSelect(account.id),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _BankAccountTile extends StatelessWidget {
  const _BankAccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final BankAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.tokens.brandGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_outlined,
              size: 18,
              color: context.tokens.brandGold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bankName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  account.maskedNumber,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected
                ? context.tokens.success
                : context.tokens.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

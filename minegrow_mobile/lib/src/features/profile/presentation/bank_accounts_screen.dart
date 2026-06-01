import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/profile_repository.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(bankAccountsProvider);

    return MGScaffold(
      appBar: MGAppBar(
        title: 'Bank Accounts',
        showBack: true,
        backRoute: AppRoutes.profile,
        action: Semantics(
          label: 'Add bank account',
          button: true,
          child: IconButton(
            tooltip: 'Add bank account',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSheet(context),
          ),
        ),
      ),
      mainNavigationIndex: 4,
      backFallbackRoute: AppRoutes.profile,
      body: accountsState.when(
        loading: () => const MGLoadingList(itemCount: 3),
        error: (error, stackTrace) => mgErrorView(
          error: error,
          onRetry: () => ref.invalidate(bankAccountsProvider),
          fallbackIcon: Icons.account_balance_outlined,
          fallbackTitle: 'Bank accounts unavailable',
          fallbackMessage: 'We could not load your bank accounts. Try again.',
        ),
        data: (accounts) {
          final bankAccounts = accounts
              .where((a) => a.isBank)
              .toList(growable: false);

          if (bankAccounts.isEmpty) {
            return Column(
              children: [
                const MGFriendlyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No bank account linked',
                  message: 'Add your bank account to enable bank withdrawals.',
                ),
                const SizedBox(height: 20),
                MGGradientButton(
                  label: 'Add Bank Account',
                  icon: Icons.add,
                  onPressed: () => _showAddSheet(context),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '${bankAccounts.length} Linked '
                'Account${bankAccounts.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              for (final account in bankAccounts) ...[
                _BankAccountCard(
                  account: account,
                  onDelete: () => _confirmDelete(context, ref, account),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const MGInlineMessage(
                message:
                    'Only verified bank accounts are used for withdrawals. '
                    'Contact support if an account is missing.',
                tone: MGMessageTone.info,
                icon: Icons.verified_user_outlined,
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddBankAccountSheet(),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BankAccount account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.metrics.radiusLarge),
        ),
        title: Text(
          'Remove account?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Text(
          'Remove ${account.bankName} (${account.maskedNumber})? '
          'This cannot be undone.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
        ),
        actions: [
          TextButton(
            // autofocus safe action so keyboard users don't land on "Remove" (WCAG 2.1.1)
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(profileRepositoryProvider).deleteAccount(account.id);
      ref.invalidate(bankAccountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bank account removed')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove account. Try again.')),
        );
      }
    }
  }
}

// ── Bank Account Card ─────────────────────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.account, required this.onDelete});

  final BankAccount account;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final last4 = account.accountNumber.length > 4
        ? account.accountNumber.substring(account.accountNumber.length - 4)
        : account.accountNumber;

    return Semantics(
      label:
          '${account.bankName}, account ending $last4'
          '${account.isPrimary ? ', primary account' : ''}',
      child: MGCard(
        padding: EdgeInsets.all(context.metrics.compactPadding),
        child: Row(
          children: [
            // Bank icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.tokens.brandGold.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance_outlined,
                size: 20,
                color: context.tokens.brandGold,
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.bankName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    account.maskedNumber,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  if (account.accountHolder?.isNotEmpty == true)
                    Text(
                      account.accountHolder!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    ),
                  if (account.ifscCode.isNotEmpty)
                    Text(
                      'IFSC: ${account.ifscCode}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    ),
                ],
              ),
            ),

            // Primary badge
            if (account.isPrimary)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: MGStatusChip(status: MGStatus.verified),
              ),

            // Delete button — min 44×44 touch target
            Semantics(
              label: 'Remove ${account.bankName} account',
              button: true,
              excludeSemantics: true,
              child: IconButton(
                tooltip: 'Remove account',
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: context.tokens.danger,
                ),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Bank Account Sheet ────────────────────────────────────────────────────

class _AddBankAccountSheet extends ConsumerStatefulWidget {
  const _AddBankAccountSheet();

  @override
  ConsumerState<_AddBankAccountSheet> createState() =>
      _AddBankAccountSheetState();
}

class _AddBankAccountSheetState extends ConsumerState<_AddBankAccountSheet> {
  final _bankNameCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _confirmAccCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _holderCtrl.dispose();
    _accNumCtrl.dispose();
    _confirmAccCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bankName = _bankNameCtrl.text.trim();
    final holder = _holderCtrl.text.trim();
    final accNum = _accNumCtrl.text.trim();
    final confirmNum = _confirmAccCtrl.text.trim();
    final ifsc = _ifscCtrl.text.trim().toUpperCase();

    if (bankName.isEmpty) {
      _setError('Enter the bank name.');
      return;
    }
    if (holder.isEmpty) {
      _setError('Enter the account holder name.');
      return;
    }
    if (accNum.length < 9) {
      _setError('Enter a valid account number (minimum 9 digits).');
      return;
    }
    if (accNum != confirmNum) {
      _setError('Account numbers do not match. Please re-enter.');
      return;
    }
    // Standard IFSC: 4 letters + 0 + 6 alphanumeric
    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    if (!ifscRegex.hasMatch(ifsc)) {
      _setError('Enter a valid IFSC code (e.g. SBIN0001234).');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .addBankAccount(
            bankName: bankName,
            accountHolder: holder,
            accountNumber: accNum,
            ifscCode: ifsc,
          );
      ref.invalidate(bankAccountsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        _setError('Could not save bank account. Try again.');
      }
    }
  }

  void _setError(String msg) => setState(() {
    _errorText = msg;
    _isSubmitting = false;
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + bottomSafeArea + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle — labeled for switch-access users (WCAG 2.1.1)
          Semantics(
            label: 'Drag to dismiss',
            excludeSemantics: true,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.tokens.borderMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sheet header row: title + explicit close button (WCAG 2.1.1)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Add Bank Account',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Semantics(
                label: 'Close',
                button: true,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Details must match your bank records exactly.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Fields
          MGTextField(
            label: 'Bank Name',
            hintText: 'e.g. State Bank of India',
            controller: _bankNameCtrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          MGTextField(
            label: 'Account Holder Name',
            hintText: 'Full name as on bank records',
            controller: _holderCtrl,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          MGTextField(
            label: 'Account Number',
            hintText: 'Enter account number',
            controller: _accNumCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          MGTextField(
            label: 'Confirm Account Number',
            hintText: 'Re-enter account number',
            controller: _confirmAccCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),
          MGTextField(
            label: 'IFSC Code',
            hintText: 'e.g. SBIN0001234',
            controller: _ifscCtrl,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              // Auto-uppercase so lowercase input never causes a validation mismatch (WCAG 3.3.1)
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(11),
            ],
            onSubmitted: (_) => _submit(),
          ),

          // Error message — role=alert equivalent for screen readers
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: MGInlineMessage(
                message: _errorText!,
                tone: MGMessageTone.danger,
                icon: Icons.error_outline,
              ),
            ),
          ],

          const SizedBox(height: 20),
          MGGradientButton(
            label: _isSubmitting ? 'Saving…' : 'Add Bank Account',
            icon: _isSubmitting ? null : Icons.add,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Forces every character to uppercase as the user types.
/// Prevents validation mismatches on IFSC fields. (WCAG 3.3.1)
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

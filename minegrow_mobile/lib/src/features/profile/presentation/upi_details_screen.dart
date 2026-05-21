import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/profile_repository.dart';

class UpiDetailsScreen extends ConsumerWidget {
  const UpiDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(bankAccountsProvider);

    return MGScaffold(
      appBar: MGAppBar(
        title: 'UPI Details',
        showBack: true,
        backRoute: AppRoutes.profile,
        action: Semantics(
          label: 'Add UPI ID',
          button: true,
          child: IconButton(
            tooltip: 'Add UPI ID',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSheet(context),
          ),
        ),
      ),
      mainNavigationIndex: 4,
      backFallbackRoute: AppRoutes.profile,
      body: accountsState.when(
        loading: () => const MGLoadingList(itemCount: 2),
        error: (error, stackTrace) => MGFriendlyState(
          icon: Icons.payments_outlined,
          title: 'UPI details unavailable',
          message: 'We could not load your UPI details. Try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(bankAccountsProvider),
        ),
        data: (accounts) {
          final upiAccounts = accounts
              .where((a) => a.isUpi)
              .toList(growable: false);

          if (upiAccounts.isEmpty) {
            return Column(
              children: [
                const MGFriendlyState(
                  icon: Icons.payments_outlined,
                  title: 'No UPI ID linked',
                  message: 'Add a UPI ID to enable instant UPI withdrawals.',
                ),
                const SizedBox(height: 20),
                MGGradientButton(
                  label: 'Add UPI ID',
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
                '${upiAccounts.length} Linked '
                'UPI ID${upiAccounts.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              for (final account in upiAccounts) ...[
                _UpiAccountCard(
                  account: account,
                  onDelete: () => _confirmDelete(context, ref, account),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const MGInlineMessage(
                message:
                    'Use a verified UPI ID that matches your registered name '
                    'for smooth payouts.',
                tone: MGMessageTone.info,
                icon: Icons.verified_outlined,
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
      builder: (_) => const _AddUpiSheet(),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BankAccount account,
  ) async {
    final upiId = account.upiId ?? account.accountNumber;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.metrics.radiusLarge),
        ),
        title: Text(
          'Remove UPI ID?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Text(
          'Remove $upiId? This cannot be undone.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
        ),
        actions: [
          TextButton(
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
        ).showSnackBar(const SnackBar(content: Text('UPI ID removed')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove UPI ID. Try again.')),
        );
      }
    }
  }
}

// ── UPI Account Card ──────────────────────────────────────────────────────────

class _UpiAccountCard extends StatelessWidget {
  const _UpiAccountCard({required this.account, required this.onDelete});

  final BankAccount account;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final upiId = account.upiId ?? account.accountNumber;

    return Semantics(
      label:
          'UPI ID: $upiId'
          '${account.isPrimary ? ', default payout' : ''}',
      child: MGCard(
        padding: EdgeInsets.all(context.metrics.compactPadding),
        child: Row(
          children: [
            // UPI icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.tokens.brandPurple.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 20,
                color: context.tokens.brandPurple,
              ),
            ),
            const SizedBox(width: 12),

            // UPI ID & label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(upiId, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    account.isPrimary ? 'Default payout UPI' : 'UPI payout ID',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Copy button — min 44×44 touch target
            Semantics(
              label: 'Copy UPI ID',
              button: true,
              excludeSemantics: true,
              child: IconButton(
                tooltip: 'Copy UPI ID',
                icon: const Icon(Icons.copy_outlined, size: 18),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: upiId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('UPI ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),

            // Delete button — min 44×44 touch target
            Semantics(
              label: 'Remove UPI ID',
              button: true,
              excludeSemantics: true,
              child: IconButton(
                tooltip: 'Remove UPI ID',
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
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

// ── Add UPI Sheet ─────────────────────────────────────────────────────────────

class _AddUpiSheet extends ConsumerStatefulWidget {
  const _AddUpiSheet();

  @override
  ConsumerState<_AddUpiSheet> createState() => _AddUpiSheetState();
}

class _AddUpiSheetState extends ConsumerState<_AddUpiSheet> {
  final _upiCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _upiCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final upiId = _upiCtrl.text.trim();
    final holder = _holderCtrl.text.trim();

    // Basic UPI validation: anything@word (covers vpa@bankname format)
    final upiRegex = RegExp(r'^[\w.\-]+@[a-zA-Z]+$');
    if (upiId.isEmpty || !upiRegex.hasMatch(upiId)) {
      _setError('Enter a valid UPI ID (e.g. yourname@oksbi).');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .addUpiId(
            upiId: upiId,
            accountHolder: holder.isEmpty ? null : holder,
          );
      ref.invalidate(bankAccountsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _setError('Could not save UPI ID. Try again.');
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add UPI ID',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Enter the UPI ID you want to use for withdrawals.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 20),

          // UPI ID field — Tab moves to next field (WCAG 2.4.3)
          MGTextField(
            label: 'UPI ID',
            hintText: 'e.g. yourname@oksbi',
            controller: _upiCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 14),

          // Optional holder name — submit triggers form submit
          MGTextField(
            label: 'Account Holder Name (optional)',
            hintText: 'Name linked to this UPI ID',
            controller: _holderCtrl,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),

          // Error message — live region for screen readers
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
            label: _isSubmitting ? 'Saving…' : 'Add UPI ID',
            icon: _isSubmitting ? null : Icons.add,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

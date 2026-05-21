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
      appBar: const MGAppBar(
        title: 'UPI Details',
        showBack: true,
        backRoute: AppRoutes.profile,
      ),
      mainNavigationIndex: 4,
      backFallbackRoute: AppRoutes.profile,
      body: accountsState.when(
        loading: () => const MGLoadingList(itemCount: 3),
        error: (error, stackTrace) => MGFriendlyState(
          icon: Icons.payments_outlined,
          title: 'UPI details unavailable',
          message: 'We could not refresh your UPI details. Try again later.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(bankAccountsProvider),
        ),
        data: (accounts) {
          final upiAccounts = accounts
              .where((account) => account.isUpi)
              .toList(growable: false);

          if (upiAccounts.isEmpty) {
            return const MGFriendlyState(
              icon: Icons.payments_outlined,
              title: 'No UPI ID linked',
              message:
                  'Contact support to link a UPI ID for direct UPI withdrawals.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '${upiAccounts.length} Linked UPI ID${upiAccounts.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              for (final account in upiAccounts) ...[
                _UpiAccountCard(account: account),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const MGInlineMessage(
                message:
                    'Use a verified UPI ID that matches your payout profile.',
                tone: MGMessageTone.info,
                icon: Icons.verified_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpiAccountCard extends StatelessWidget {
  const _UpiAccountCard({required this.account});

  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    final upiId = account.upiId ?? account.accountNumber;

    return MGCard(
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
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
          IconButton(
            tooltip: 'Copy UPI ID',
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: upiId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UPI ID copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

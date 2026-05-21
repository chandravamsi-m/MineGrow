import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/profile_repository.dart';

class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(bankAccountsProvider);

    return MGScaffold(
      appBar: const MGAppBar(
        title: 'Bank Accounts',
        showBack: true,
        backRoute: AppRoutes.profile,
      ),
      mainNavigationIndex: 4,
      backFallbackRoute: AppRoutes.profile,
      body: accountsState.when(
        loading: () => const MGLoadingList(itemCount: 3),
        error: (error, stackTrace) => MGFriendlyState(
          icon: Icons.account_balance_outlined,
          title: 'Bank accounts unavailable',
          message: 'We could not refresh your bank accounts. Try again later.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(bankAccountsProvider),
        ),
        data: (accounts) {
          final bankAccounts = accounts
              .where((account) => account.isBank)
              .toList(growable: false);

          if (bankAccounts.isEmpty) {
            return const MGFriendlyState(
              icon: Icons.account_balance_outlined,
              title: 'No bank accounts linked',
              message:
                  'Contact support to link your bank account for withdrawals.',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                '${bankAccounts.length} Linked Account${bankAccounts.length == 1 ? '' : 's'}',
              ),
              const SizedBox(height: 12),
              for (final account in bankAccounts) ...[
                _BankAccountCard(account: account),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              const MGInlineMessage(
                message:
                    'Only verified bank accounts are used for bank withdrawals.',
                tone: MGMessageTone.info,
                icon: Icons.verified_user_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.account});

  final BankAccount account;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
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
          if (account.isPrimary) const MGStatusChip(status: MGStatus.verified),
        ],
      ),
    );
  }
}

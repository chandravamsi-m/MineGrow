import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final bankAccountsState = ref.watch(bankAccountsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'My Profile'),
      mainNavigationIndex: 4,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: profileState.when(
          loading: () => const MGLoadingList(itemCount: 3),
          error: (error, stackTrace) => MGFriendlyState(
            icon: Icons.person_off_outlined,
            title: 'Profile could not load',
            message:
                'Login again or check your connection to refresh account details.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(profileProvider),
          ),
          data: (profile) {
            final bankAccountCount = bankAccountsState.maybeWhen(
              data: (accounts) => accounts.length,
              orElse: () => 0,
            );

            return Column(
              children: [
                MGCard(
                  gradient: context.tokens.walletGradient,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: context.tokens.brandGold,
                        child: Icon(
                          Icons.person,
                          color: context.tokens.background,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.mobile,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: context.tokens.textSecondary,
                                  ),
                            ),
                            Text(
                              profile.email ?? 'Email not added',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: context.tokens.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ProfileTile(
                  icon: Icons.verified_user_outlined,
                  title: 'KYC Verification',
                  trailing: MGStatusChip(
                    status: profile.kycVerified
                        ? MGStatus.verified
                        : MGStatus.pending,
                  ),
                ),
                _ProfileTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Bank Accounts',
                  value: '$bankAccountCount Accounts',
                ),
                const _ProfileTile(
                  icon: Icons.payments_outlined,
                  title: 'UPI Details',
                  value: 'Linked with bank accounts',
                ),
                const _ProfileTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                ),
                _ProfileTile(
                  icon: Icons.notifications_none,
                  title: 'Notification Settings',
                  onTap: () => context.go(AppRoutes.notifications),
                ),
                const MGInlineMessage(
                  message:
                      'Keep KYC, bank account, and UPI details updated to avoid payout delays.',
                  tone: MGMessageTone.info,
                  icon: Icons.verified_user_outlined,
                ),
                const SizedBox(height: 10),
                _ProfileTile(
                  icon: Icons.logout,
                  title: 'Logout',
                  titleColor: context.tokens.danger,
                  onTap: () async {
                    await ref.read(authRepositoryProvider).logout();
                    ref.invalidate(profileProvider);
                    ref.invalidate(bankAccountsProvider);
                    if (context.mounted) {
                      context.go(AppRoutes.auth);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    this.value,
    this.trailing,
    this.titleColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MGCard(
        padding: EdgeInsets.all(context.metrics.compactPadding),
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: titleColor ?? context.tokens.textPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: titleColor),
              ),
            ),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Text(
                  value!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: context.tokens.textMuted,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/widgets/mg_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      appBar: const MGAppBar(title: 'My Profile'),
      mainNavigationIndex: 4,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
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
                          'Ramesh Kumar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+91 9876543210',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.tokens.textSecondary),
                        ),
                        Text(
                          'ramesh@gmail.com',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.tokens.textSecondary),
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
              trailing: const MGStatusChip(status: MGStatus.verified),
            ),
            const _ProfileTile(
              icon: Icons.account_balance_outlined,
              title: 'Bank Accounts',
              value: '2 Accounts',
            ),
            const _ProfileTile(
              icon: Icons.payments_outlined,
              title: 'UPI Details',
              value: '1 UPI Added',
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
            ),
          ],
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

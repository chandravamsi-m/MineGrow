import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
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
            final bankAccounts = bankAccountsState.maybeWhen(
              data: (accounts) => accounts.where((account) => account.isBank),
              orElse: () => const Iterable<BankAccount>.empty(),
            );
            final upiAccounts = bankAccountsState.maybeWhen(
              data: (accounts) => accounts.where((account) => account.isUpi),
              orElse: () => const Iterable<BankAccount>.empty(),
            );
            final bankAccountCount = bankAccounts.length;
            final upiAccountCount = upiAccounts.length;
            final upiValue = bankAccountsState.maybeWhen(
              loading: () => 'Loading...',
              error: (error, stackTrace) => 'Unavailable',
              data: (accounts) => upiAccountCount == 0
                  ? 'Not linked'
                  : '$upiAccountCount UPI ID${upiAccountCount == 1 ? '' : 's'}',
              orElse: () => 'Not linked',
            );

            return Column(
              children: [
                MGCard(
                  gradient: context.tokens.walletGradient,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: context.tokens.brandGold.withValues(
                          alpha: 0.18,
                        ),
                        child: Text(
                          _initials(profile.fullName),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: context.tokens.brandGold,
                                fontWeight: FontWeight.w700,
                              ),
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
                            if (profile.email != null)
                              Text(
                                profile.email!,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: context.tokens.textSecondary,
                                    ),
                              )
                            else
                              Text(
                                'Email not added',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: context.tokens.textMuted),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditDialog(context, profile),
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
                  value:
                      '$bankAccountCount Account${bankAccountCount == 1 ? '' : 's'}',
                  onTap: () => context.go(AppRoutes.bankAccounts),
                ),
                _ProfileTile(
                  icon: Icons.payments_outlined,
                  title: 'UPI Details',
                  value: upiValue.toString(),
                  onTap: () => context.go(AppRoutes.upiDetails),
                ),
                _ProfileTile(
                  icon: Icons.notifications_none,
                  title: 'Notification Settings',
                  onTap: () => context.go(AppRoutes.notificationSettings),
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
                  onTap: () => _confirmLogout(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static void _showEditDialog(BuildContext context, UserProfile profile) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditProfileDialog(profile: profile),
    );
  }

  static Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.tokens.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.metrics.radiusLarge),
        ),
        title: Text('Log out?', style: Theme.of(context).textTheme.titleMedium),
        content: Text(
          'You will need to verify your mobile number to log back in.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Log out',
              style: TextStyle(color: context.tokens.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(profileProvider);
    ref.invalidate(bankAccountsProvider);
    if (context.mounted) {
      context.go(AppRoutes.auth);
    }
  }
}

// ── Edit Profile Dialog ──────────────────────────────────────────────────────

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _addressController = TextEditingController(
      text: widget.profile.address ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() => _errorText = 'Enter your full name.');
      return;
    }
    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(fullName: name, email: email, address: address);
      ref.invalidate(profileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorText = 'Could not save changes. Try again.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.metrics.radiusLarge),
      ),
      title: Text(
        'Edit Profile',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MGTextField(
              label: 'Full Name',
              hintText: 'Enter your full name',
              controller: _nameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 14),
            MGTextField(
              label: 'Email Address',
              hintText: 'Enter email address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            MGTextField(
              label: 'Residential Address',
              hintText: 'Enter complete address',
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              MGInlineMessage(
                message: _errorText!,
                tone: MGMessageTone.danger,
                icon: Icons.error_outline,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            _isSubmitting ? 'Saving...' : 'Save',
            style: TextStyle(color: context.tokens.brandGold),
          ),
        ),
      ],
    );
  }
}

// ── Profile Tile ─────────────────────────────────────────────────────────────

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

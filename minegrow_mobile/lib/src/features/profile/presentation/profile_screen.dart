import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_utilities/flutter_app_utilities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../app_config/data/app_config_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final bankAccountsState = ref.watch(bankAccountsProvider);
    final appConfig = ref.watch(appConfigProvider).maybeWhen(
          data: (config) => config,
          orElse: RemoteAppConfig.fallback,
        );

    return MGScaffold(
      appBar: const MGAppBar(title: 'My Profile'),
      mainNavigationIndex: 4,
      body: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: profileState.when(
          loading: () => const MGLoadingList(itemCount: 3),
          error: (error, stackTrace) => mgErrorView(
            error: error,
            onRetry: () => ref.invalidate(profileProvider),
            fallbackIcon: Icons.person_off_outlined,
            fallbackTitle: 'Profile could not load',
            fallbackMessage:
                'Login again or check your connection to refresh account details.',
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
                      AccessibleIconButton(
                        semanticLabel: 'Edit profile',
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
                  onTap: () => _showKycSheet(context),
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
                _ProfileTile(
                  icon: Icons.support_agent_outlined,
                  title: 'Help & Support',
                  value: appConfig.supportPhone,
                  onTap: () => _showSupportSheet(context, appConfig),
                ),
                _ProfileTile(
                  icon: Icons.gavel_outlined,
                  title: 'Legal & Compliance',
                  onTap: () => _showLegalSheet(context, appConfig),
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

  static void _showKycSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.metrics.radiusLarge),
        ),
      ),
      builder: (ctx) => const _KycUploadSheet(),
    );
  }

  static void _showSupportSheet(
    BuildContext context,
    RemoteAppConfig config,
  ) {
    _showInfoSheet(
      context,
      child: _SupportSheet(config: config),
    );
  }

  static void _showLegalSheet(
    BuildContext context,
    RemoteAppConfig config,
  ) {
    _showInfoSheet(
      context,
      child: _LegalSheet(config: config),
    );
  }

  static void _showInfoSheet(
    BuildContext context, {
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.metrics.radiusLarge),
        ),
      ),
      builder: (ctx) => child,
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

class _SupportSheet extends StatelessWidget {
  const _SupportSheet({required this.config});

  final RemoteAppConfig config;

  @override
  Widget build(BuildContext context) {
    return _ProfileInfoSheet(
      title: 'Help & Support',
      icon: Icons.support_agent_outlined,
      children: [
        _InfoRow(label: 'Phone', value: config.supportPhone),
        _InfoRow(label: 'Email', value: config.supportEmail),
        MGInlineMessage(
          message:
              'Use these contacts for KYC, payments, withdrawals, and account access queries.',
          tone: MGMessageTone.info,
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.config});

  final RemoteAppConfig config;

  @override
  Widget build(BuildContext context) {
    return _ProfileInfoSheet(
      title: 'Legal & Compliance',
      icon: Icons.gavel_outlined,
      children: [
        _InfoRow(label: 'Terms', value: config.termsUrl),
        _InfoRow(label: 'Privacy', value: config.privacyUrl),
        MGInlineMessage(
          message: config.riskDisclosure,
          tone: MGMessageTone.warning,
          icon: Icons.warning_amber_outlined,
        ),
      ],
    );
  }
}

class _ProfileInfoSheet extends StatelessWidget {
  const _ProfileInfoSheet({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.metrics.screenPadding,
          20,
          context.metrics.screenPadding,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.tokens.brandGold),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MGCard(
        padding: EdgeInsets.all(context.metrics.compactPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KycUploadSheet extends ConsumerStatefulWidget {
  const _KycUploadSheet();

  @override
  ConsumerState<_KycUploadSheet> createState() => _KycUploadSheetState();
}

class _KycUploadSheetState extends ConsumerState<_KycUploadSheet> {
  static const _docTypes = [
    ('aadhaar', 'Aadhaar'),
    ('pan', 'PAN Card'),
    ('passport', 'Passport'),
    ('driving_license', 'Driving License'),
  ];

  String _docType = _docTypes.first.$1;
  PlatformFile? _file;
  String? _errorText;
  bool _isSubmitting = false;

  Future<void> _selectFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _file = result.files.single;
      _errorText = null;
    });
  }

  Future<MultipartFile> _multipartFileFromSelection() async {
    final selected = _file;
    if (selected == null) {
      throw const ApiException(message: 'Select a KYC document to upload.');
    }

    if (kIsWeb) {
      final bytes = selected.bytes;
      if (bytes == null) {
        throw const ApiException(message: 'Could not read KYC file bytes.');
      }
      return MultipartFile.fromBytes(bytes, filename: selected.name);
    }

    final path = selected.path;
    if (path == null || path.isEmpty) {
      throw const ApiException(message: 'Could not locate KYC file path.');
    }
    return MultipartFile.fromFile(path, filename: selected.name);
  }

  Future<void> _submit() async {
    if (_file == null) {
      setState(() => _errorText = 'Select a JPG, PNG, or PDF document.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      final file = await _multipartFileFromSelection();
      await ref
          .read(profileRepositoryProvider)
          .uploadKycDocument(docType: _docType, file: file);

      ref.invalidate(profileProvider);
      ref.invalidate(kycDocumentsProvider);

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'Could not upload KYC. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycDocumentsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: context.metrics.screenPadding,
          right: context.metrics.screenPadding,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload KYC', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Choose a document type and upload a clear JPG, PNG, or PDF.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _docType,
                decoration: const InputDecoration(labelText: 'Document Type'),
                items: [
                  for (final type in _docTypes)
                    DropdownMenuItem(value: type.$1, child: Text(type.$2)),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value != null) setState(() => _docType = value);
                      },
              ),
              const SizedBox(height: 16),
              MGUploadBox(
                fileName: _file?.name,
                errorText: _errorText?.contains('Select') == true
                    ? _errorText
                    : null,
                onTap: _isSubmitting ? null : _selectFile,
              ),
              if (_errorText != null &&
                  _errorText?.contains('Select') != true) ...[
                const SizedBox(height: 12),
                MGInlineMessage(
                  message: _errorText!,
                  tone: MGMessageTone.warning,
                  icon: Icons.warning_amber_outlined,
                ),
              ],
              const SizedBox(height: 16),
              kycState.maybeWhen(
                data: (documents) => documents.isEmpty
                    ? const SizedBox.shrink()
                    : _KycDocumentSummary(documents: documents),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              MGGradientButton(
                label: _isSubmitting ? 'Uploading...' : 'Upload Document',
                onPressed: _isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycDocumentSummary extends StatelessWidget {
  const _KycDocumentSummary({required this.documents});

  final List<KycDocument> documents;

  @override
  Widget build(BuildContext context) {
    final latest = documents.first;
    return MGInlineMessage(
      message:
          'Latest ${_labelForDocType(latest.docType)} document is ${latest.status}.',
      tone: MGMessageTone.info,
      icon: Icons.description_outlined,
    );
  }

  static String _labelForDocType(String docType) {
    return switch (docType) {
      'aadhaar' => 'Aadhaar',
      'pan' => 'PAN',
      'passport' => 'passport',
      'driving_license' => 'driving license',
      _ => 'KYC',
    };
  }
}

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

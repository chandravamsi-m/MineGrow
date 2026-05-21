import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/mg_widgets.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _pushKey = 'settings.notifications.push';
  static const _investmentKey = 'settings.notifications.investments';
  static const _walletKey = 'settings.notifications.wallet';
  static const _promoKey = 'settings.notifications.promos';

  bool _isLoading = true;
  bool _pushEnabled = true;
  bool _investmentEnabled = true;
  bool _walletEnabled = true;
  bool _promoEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final storage = ref.read(localStorageProvider);
    final values = await Future.wait<bool?>([
      storage.readBool(_pushKey),
      storage.readBool(_investmentKey),
      storage.readBool(_walletKey),
      storage.readBool(_promoKey),
    ]);

    if (!mounted) return;
    setState(() {
      _pushEnabled = values[0] ?? true;
      _investmentEnabled = values[1] ?? true;
      _walletEnabled = values[2] ?? true;
      _promoEnabled = values[3] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _updateSetting(String key, bool value) async {
    await ref.read(localStorageProvider).writeBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      appBar: const MGAppBar(
        title: 'Notification Settings',
        showBack: true,
        backRoute: AppRoutes.profile,
      ),
      mainNavigationIndex: 4,
      backFallbackRoute: AppRoutes.profile,
      body: _isLoading
          ? const MGLoadingList(itemCount: 3)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Allow important account alerts on this device.',
                  value: _pushEnabled,
                  onChanged: (value) {
                    setState(() => _pushEnabled = value);
                    _updateSetting(_pushKey, value);
                  },
                ),
                const SizedBox(height: 10),
                _NotificationSwitchTile(
                  icon: Icons.trending_up_outlined,
                  title: 'Investment Updates',
                  subtitle: 'ROI credits, plan approvals, and maturity alerts.',
                  value: _investmentEnabled,
                  enabled: _pushEnabled,
                  onChanged: (value) {
                    setState(() => _investmentEnabled = value);
                    _updateSetting(_investmentKey, value);
                  },
                ),
                const SizedBox(height: 10),
                _NotificationSwitchTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet and Withdrawals',
                  subtitle:
                      'Wallet credits, withdrawal approvals, and payout status.',
                  value: _walletEnabled,
                  enabled: _pushEnabled,
                  onChanged: (value) {
                    setState(() => _walletEnabled = value);
                    _updateSetting(_walletKey, value);
                  },
                ),
                const SizedBox(height: 10),
                _NotificationSwitchTile(
                  icon: Icons.campaign_outlined,
                  title: 'Offers and Announcements',
                  subtitle: 'Product updates and optional promotional alerts.',
                  value: _promoEnabled,
                  enabled: _pushEnabled,
                  onChanged: (value) {
                    setState(() => _promoEnabled = value);
                    _updateSetting(_promoKey, value);
                  },
                ),
                const SizedBox(height: 16),
                const MGInlineMessage(
                  message:
                      'These preferences control notification categories inside the app. System-level permissions are managed by your device settings.',
                  tone: MGMessageTone.info,
                  icon: Icons.info_outline,
                ),
              ],
            ),
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

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
            child: Icon(icon, color: context.tokens.brandGold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled
                        ? context.tokens.textPrimary
                        : context.tokens.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: enabled && value,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

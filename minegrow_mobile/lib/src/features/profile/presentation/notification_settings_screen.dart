import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/profile_repository.dart';

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
    NotificationPreferences? prefs;

    try {
      prefs = (await ref.read(profileProvider.future)).notificationPreferences;
    } catch (_) {
      final values = await Future.wait<bool?>([
        storage.readBool(_pushKey),
        storage.readBool(_investmentKey),
        storage.readBool(_walletKey),
        storage.readBool(_promoKey),
      ]);
      prefs = NotificationPreferences(
        push: values[0] ?? true,
        investments: values[1] ?? true,
        wallet: values[2] ?? true,
        promotions: values[3] ?? false,
      );
    }

    if (!mounted) return;
    setState(() {
      _pushEnabled = prefs?.push ?? true;
      _investmentEnabled = prefs?.investments ?? true;
      _walletEnabled = prefs?.wallet ?? true;
      _promoEnabled = prefs?.promotions ?? false;
      _isLoading = false;
    });
  }

  Future<void> _persistPreferences(NotificationPreferences previous) async {
    final next = NotificationPreferences(
      push: _pushEnabled,
      investments: _investmentEnabled,
      wallet: _walletEnabled,
      promotions: _promoEnabled,
    );

    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .updateNotificationPreferences(next);
      await _cachePreferences(saved);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      setState(() {
        _pushEnabled = saved.push;
        _investmentEnabled = saved.investments;
        _walletEnabled = saved.wallet;
        _promoEnabled = saved.promotions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pushEnabled = previous.push;
        _investmentEnabled = previous.investments;
        _walletEnabled = previous.wallet;
        _promoEnabled = previous.promotions;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save notification preferences.'),
        ),
      );
    }
  }

  Future<void> _cachePreferences(NotificationPreferences preferences) async {
    final storage = ref.read(localStorageProvider);
    await Future.wait([
      storage.writeBool(_pushKey, preferences.push),
      storage.writeBool(_investmentKey, preferences.investments),
      storage.writeBool(_walletKey, preferences.wallet),
      storage.writeBool(_promoKey, preferences.promotions),
    ]);
  }

  NotificationPreferences _currentPreferences() {
    return NotificationPreferences(
      push: _pushEnabled,
      investments: _investmentEnabled,
      wallet: _walletEnabled,
      promotions: _promoEnabled,
    );
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
                    final previous = _currentPreferences();
                    setState(() => _pushEnabled = value);
                    _persistPreferences(previous);
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
                    final previous = _currentPreferences();
                    setState(() => _investmentEnabled = value);
                    _persistPreferences(previous);
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
                    final previous = _currentPreferences();
                    setState(() => _walletEnabled = value);
                    _persistPreferences(previous);
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
                    final previous = _currentPreferences();
                    setState(() => _promoEnabled = value);
                    _persistPreferences(previous);
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

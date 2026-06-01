import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../app_config/data/app_config_repository.dart';

/// Static "About" screen showing the app identity, version/build, and links.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _info = info);
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final config = ref.watch(appConfigProvider).maybeWhen(
          data: (value) => value,
          orElse: RemoteAppConfig.fallback,
        );
    final versionLabel = _info == null
        ? 'Loading…'
        : 'Version ${_info!.version} (build ${_info!.buildNumber})';

    return MGScaffold(
      appBar: const MGAppBar(title: 'About', showBack: true),
      mainNavigationIndex: 4,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Center(child: MGMiningMark(size: 84)),
          const SizedBox(height: 18),
          Center(
            child: Text(
              AppConstants.appName.toUpperCase(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: tokens.brandGold,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              versionLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          MGCard(
            child: Column(
              children: [
                _AboutLink(
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _open(config.termsUrl),
                ),
                const SizedBox(height: 4),
                _AboutLink(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _open(config.privacyUrl),
                ),
                const SizedBox(height: 4),
                _AboutLink(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact Support',
                  onTap: () => _open('mailto:${config.supportEmail}'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '© ${AppConstants.appName}. All rights reserved.',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.metrics.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tokens.brandGold),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: tokens.textMuted),
          ],
        ),
      ),
    );
  }
}

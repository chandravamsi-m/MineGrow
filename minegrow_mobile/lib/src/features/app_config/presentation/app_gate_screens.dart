import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_app_utilities/flutter_app_utilities.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../data/app_config_repository.dart';

/// Blocking screen shown when the running app is older than the backend's
/// minimum supported version. The user cannot proceed until they update.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider).maybeWhen(
          data: (value) => value,
          orElse: RemoteAppConfig.fallback,
        );

    return AppIssueScreen(
      icon: Icons.system_update_rounded,
      title: 'Update required',
      message:
          'A newer version of MineGrow is available and required to continue. '
          'Please update to keep your account secure.',
      primaryActionLabel: 'Update now',
      onPrimaryAction: () => _openStore(config),
    );
  }

  Future<void> _openStore(RemoteAppConfig config) async {
    final url = (config.updateUrl != null && config.updateUrl!.isNotEmpty)
        ? config.updateUrl!
        : defaultTargetPlatform == TargetPlatform.iOS
            ? 'https://minegrow.app'
            : 'https://play.google.com/store/apps/details?id=com.minegrow.app';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Blocking screen shown while the backend reports maintenance mode.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(appConfigProvider).maybeWhen(
          data: (value) => value.maintenanceMessage,
          orElse: () => null,
        );

    return AppIssueScreen(
      icon: Icons.build_circle_outlined,
      title: 'Under maintenance',
      message: message ??
          'MineGrow is briefly down for maintenance. Please check back in a '
              'little while.',
      primaryActionLabel: 'Try again',
      // Invalidate the cached config so the splash gate re-fetches it, then
      // re-run the gate check.
      onPrimaryAction: () {
        ref.invalidate(appConfigProvider);
        context.go(AppRoutes.splash);
      },
    );
  }
}

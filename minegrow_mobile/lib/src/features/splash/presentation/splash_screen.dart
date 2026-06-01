import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../app_config/data/app_config_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _warmUpBackend() async {
    try {
      await Dio().get<void>(
        '${AppConfig.apiBaseUrl}/health',
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
    } catch (_) {}
  }

  Future<void> _checkAuthAndNavigate() async {
    final storage = ref.read(localStorageProvider);
    final results = await Future.wait([
      storage.readStringAsync(AuthStorageKeys.accessToken),
      Future<void>.delayed(const Duration(milliseconds: 2000)),
      _warmUpBackend(),
      // Always resolves (fetchConfig falls back on error) so the gate fails
      // open — a config outage never locks users out.
      ref.read(appConfigProvider.future),
      PackageInfo.fromPlatform(),
    ]);

    if (!mounted) return;

    final accessToken = results[0] as String?;
    final config = results[3] as RemoteAppConfig;
    final packageInfo = results[4] as PackageInfo;

    // Maintenance and force-update gates take priority over normal routing.
    if (config.maintenanceMode) {
      context.go(AppRoutes.maintenance);
      return;
    }
    final minVersion = config.minSupportedVersion;
    if (minVersion != null &&
        minVersion.isNotEmpty &&
        _isOutdated(packageInfo.version, minVersion)) {
      context.go(AppRoutes.updateRequired);
      return;
    }

    final isLoggedIn = accessToken != null && accessToken.isNotEmpty;
    context.go(isLoggedIn ? AppRoutes.dashboard : AppRoutes.auth);
  }

  /// Returns true when [current] is a lower semver than [minimum].
  /// Build metadata (`+n`) and pre-release suffixes (`-beta`) are ignored.
  static bool _isOutdated(String current, String minimum) {
    final c = _parseVersion(current);
    final m = _parseVersion(minimum);
    for (var i = 0; i < 3; i++) {
      if (c[i] != m[i]) return c[i] < m[i];
    }
    return false;
  }

  static List<int> _parseVersion(String version) {
    final core = version.split('+').first.split('-').first;
    final parts = core.split('.');
    return List<int>.generate(
      3,
      (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      padding: EdgeInsets.all(0),
      backFallbackRoute: null,
      scrollable: false,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            color: Colors.black,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              AppAssets.splashExcavator,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              const Spacer(),
              const MGMiningMark(size: 92),
              const SizedBox(height: 22),
              Text(
                AppConstants.appName.toUpperCase(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: context.tokens.brandGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Grow Today, Earn Tomorrow',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: context.tokens.textSecondary,
                ),
              ),
              const Spacer(),

              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  backgroundColor: context.tokens.surfaceSoft,
                  valueColor: AlwaysStoppedAnimation(
                    context.tokens.brandOrange,
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ],
      ),
    );
  }
}

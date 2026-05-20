import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/mg_widgets.dart';

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

  Future<void> _checkAuthAndNavigate() async {
    // Minimum branding display time + read token concurrently
    final storage = ref.read(localStorageProvider);
    final results = await Future.wait([
      storage.readStringAsync(AuthStorageKeys.accessToken),
      Future<void>.delayed(const Duration(milliseconds: 2000)),
    ]);

    if (!mounted) return;

    final accessToken = results[0] as String?;
    final isLoggedIn = accessToken != null && accessToken.isNotEmpty;

    context.go(isLoggedIn ? AppRoutes.dashboard : AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      backFallbackRoute: null,
      scrollable: false,
      body: Column(
        children: [
          const Spacer(),
          const MGMiningMark(size: 92),
          const SizedBox(height: 22),
          Text(
            AppConstants.appName.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(color: context.tokens.brandGold),
          ),
          const SizedBox(height: 8),
          Text(
            'Grow Today, Earn Tomorrow',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(context.metrics.radiusLarge),
            child: Image.asset(
              AppAssets.splashExcavator,
              height: 260,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 28),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              backgroundColor: context.tokens.surfaceSoft,
              valueColor: AlwaysStoppedAnimation(context.tokens.brandOrange),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

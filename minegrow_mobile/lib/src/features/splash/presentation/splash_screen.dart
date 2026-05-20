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

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          MGProgressBar(value: 0.58),
          const SizedBox(height: 28),
          MGGradientButton(
            label: 'Continue',
            onPressed: () async {
              // Warm the secure storage cache before the router redirect guard checks it
              final storage = ref.read(localStorageProvider);
              await storage.readStringAsync(AuthStorageKeys.accessToken);

              if (context.mounted) {
                context.go(AppRoutes.auth);
              }
            },
          ),
        ],
      ),
    );
  }
}

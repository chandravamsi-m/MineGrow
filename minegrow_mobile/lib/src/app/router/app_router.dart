import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_register_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/roi_history_screen.dart';
import '../../features/history/presentation/withdrawal_history_screen.dart';
import '../../features/investments/presentation/investment_details_screen.dart';
import '../../features/investments/presentation/investment_plans_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/withdrawal/presentation/withdrawal_screen.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/data/app_models.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const auth = '/auth';
  static const otp = '/otp';
  static const onboarding = '/onboard';
  static const dashboard = '/dashboard';
  static const investments = '/investments';
  static const investmentDetails = '/investments/create';
  static const wallet = '/wallet';
  static const roiHistory = '/history/roi';
  static const withdrawal = '/withdraw';
  static const withdrawalHistory = '/history/withdrawals';
  static const profile = '/profile';
  static const notifications = '/notifications';
}

/// Routes that do not require authentication
const _publicRoutes = {
  AppRoutes.splash,
  AppRoutes.auth,
  AppRoutes.otp,
};

/// Routes that require authentication
const _protectedRoutes = {
  AppRoutes.dashboard,
  AppRoutes.investments,
  AppRoutes.investmentDetails,
  AppRoutes.wallet,
  AppRoutes.roiHistory,
  AppRoutes.withdrawal,
  AppRoutes.withdrawalHistory,
  AppRoutes.profile,
  AppRoutes.notifications,
  AppRoutes.onboarding,
};

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.watch(localStorageProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    errorBuilder: (context, state) => const _RouteErrorScreen(),

    // MED-1: Auth redirect guard — prevents unauthenticated access to protected routes.
    // Every navigation attempt checks for a valid access token in secure storage.
    redirect: (context, state) async {
      final location = state.matchedLocation;

      // Read token from secure storage (async)
      final accessToken = await storage.readStringAsync(AuthStorageKeys.accessToken);
      final isLoggedIn = accessToken != null && accessToken.isNotEmpty;
      final isPublicRoute = _publicRoutes.contains(location);

      // Unauthenticated user trying to access a protected route → send to auth
      if (!isLoggedIn && !isPublicRoute) {
        return AppRoutes.auth;
      }

      // Authenticated user trying to access public auth routes → send to dashboard
      // (splash screen is excluded — it handles its own routing logic)
      if (isLoggedIn && isPublicRoute && location != AppRoutes.splash) {
        return AppRoutes.dashboard;
      }

      // No redirect needed
      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: 'auth',
        builder: (context, state) => const LoginRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        name: 'otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.investments,
        name: 'investments',
        builder: (context, state) => const InvestmentPlansScreen(),
      ),
      GoRoute(
        path: AppRoutes.investmentDetails,
        name: 'investment-details',
        builder: (context, state) => InvestmentDetailsScreen(
          initialPlan: state.extra is InvestmentPlan
              ? state.extra! as InvestmentPlan
              : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.roiHistory,
        name: 'roi-history',
        builder: (context, state) => const RoiHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.withdrawal,
        name: 'withdrawal',
        builder: (context, state) => const WithdrawalScreen(),
      ),
      GoRoute(
        path: AppRoutes.withdrawalHistory,
        name: 'withdrawal-history',
        builder: (context, state) => const WithdrawalHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050812),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.route_outlined,
                color: Color(0xFFFDBA2D),
                size: 56,
              ),
              const SizedBox(height: 18),
              const Text(
                'Page not found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The screen you opened is unavailable. Return to the dashboard and continue from there.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB7BECC), height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

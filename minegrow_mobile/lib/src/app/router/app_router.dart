import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/mg_widgets.dart';
import '../../features/auth/presentation/login_register_screen.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/app_config/presentation/app_gate_screens.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/history/presentation/investment_history_screen.dart';
import '../../features/history/presentation/roi_history_screen.dart';
import '../../features/history/presentation/withdrawal_history_screen.dart';
import '../../features/investments/presentation/investment_details_screen.dart';
import '../../features/investments/presentation/investment_plans_screen.dart';
import '../../features/investments/presentation/payment_pending_screen.dart';
import '../../features/investments/presentation/payment_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/bank_accounts_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/upi_details_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/withdrawal/presentation/withdrawal_screen.dart';
import '../../core/network/dio_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/data/app_models.dart';
import 'app_routes.dart';

export 'app_routes.dart';

/// Routes that do not require authentication
const _publicRoutes = {AppRoutes.splash, AppRoutes.auth, AppRoutes.otp};

/// Routes that require authentication
const _protectedRoutes = {
  AppRoutes.dashboard,
  AppRoutes.investments,
  AppRoutes.investmentDetails,
  AppRoutes.investmentPayment,
  AppRoutes.investmentPending,
  AppRoutes.wallet,
  AppRoutes.roiHistory,
  AppRoutes.withdrawal,
  AppRoutes.withdrawalHistory,
  AppRoutes.investmentHistory,
  AppRoutes.profile,
  AppRoutes.bankAccounts,
  AppRoutes.upiDetails,
  AppRoutes.notificationSettings,
  AppRoutes.notifications,
  AppRoutes.about,
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
      final accessToken = await storage.readStringAsync(
        AuthStorageKeys.accessToken,
      );
      final isLoggedIn = accessToken != null && accessToken.isNotEmpty;
      final isPublicRoute = _publicRoutes.contains(location);
      final isProtectedRoute = _protectedRoutes.contains(location);

      if (!isLoggedIn && isProtectedRoute) return AppRoutes.auth;

      // Splash handles its own routing; skip redirect there
      if (isLoggedIn && isPublicRoute && location != AppRoutes.splash) {
        return AppRoutes.dashboard;
      }

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
        path: AppRoutes.updateRequired,
        name: 'update-required',
        builder: (context, state) => const ForceUpdateScreen(),
      ),
      GoRoute(
        path: AppRoutes.maintenance,
        name: 'maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MGMainNavigationShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
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
            path: AppRoutes.investmentPayment,
            name: 'investment-payment',
            builder: (context, state) {
              final args = state.extra;
              if (args is! PaymentArgs) {
                return const InvestmentPlansScreen();
              }
              return PaymentScreen(args: args);
            },
          ),
          GoRoute(
            path: AppRoutes.investmentPending,
            name: 'investment-pending',
            builder: (context, state) => PaymentPendingScreen(
              args: state.extra is PaymentArgs
                  ? state.extra! as PaymentArgs
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
            path: AppRoutes.investmentHistory,
            name: 'investment-history',
            builder: (context, state) => const InvestmentHistoryScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.bankAccounts,
            name: 'bank-accounts',
            builder: (context, state) => const BankAccountsScreen(),
          ),
          GoRoute(
            path: AppRoutes.upiDetails,
            name: 'upi-details',
            builder: (context, state) => const UpiDetailsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificationSettings,
            name: 'notification-settings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.about,
            name: 'about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
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

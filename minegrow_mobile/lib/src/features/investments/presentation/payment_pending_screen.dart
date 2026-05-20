import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/widgets/mg_widgets.dart';

class PaymentPendingScreen extends StatelessWidget {
  const PaymentPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      backFallbackRoute: AppRoutes.investments,
      mainNavigationIndex: 1,
      scrollable: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: context.tokens.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.tokens.warning.withValues(alpha: 0.28),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 46,
                  color: context.tokens.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Under Review',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your payment details have been received. Our team will verify your transaction and activate your investment plan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.textSecondary,
                      height: 1.55,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              MGInlineMessage(
                message:
                    'Verification usually completes within 24 hours. You will see your plan active in the Investments tab once approved.',
                tone: MGMessageTone.info,
                icon: Icons.access_time_outlined,
              ),
              const SizedBox(height: 32),
              MGGradientButton(
                label: 'View My Investments',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: () => context.go(AppRoutes.investments),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

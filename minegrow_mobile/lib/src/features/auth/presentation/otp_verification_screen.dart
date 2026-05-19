import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/widgets/mg_widgets.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String? _errorText;

  void _verify() {
    setState(() {
      _errorText = null;
    });

    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    const otp = ['2', '4', '6', '8', '1', '9'];

    return MGScaffold(
      appBar: const MGAppBar(
        title: '',
        showBack: true,
        backRoute: AppRoutes.auth,
      ),
      backFallbackRoute: AppRoutes.auth,
      body: Column(
        children: [
          const SizedBox(height: 70),
          Text('Verify OTP', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            'Enter the 6 digit code sent to',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '+91 9876543210',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 34),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final digit in otp)
                Container(
                  width: context.metrics.otpWidth,
                  height: context.metrics.otpHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.tokens.surface,
                    borderRadius: BorderRadius.circular(
                      context.metrics.radiusSmall,
                    ),
                    border: Border.all(color: context.tokens.border),
                  ),
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Resend OTP in 00:28',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 18),
            MGInlineMessage(
              message: _errorText!,
              tone: MGMessageTone.danger,
              icon: Icons.lock_clock_outlined,
            ),
          ],
          const SizedBox(height: 42),
          MGGradientButton(label: 'Verify OTP', onPressed: _verify),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _errorText =
                    'A fresh OTP can be requested after the timer ends.';
              });
            },
            child: const Text('Need help receiving the code?'),
          ),
        ],
      ),
    );
  }
}

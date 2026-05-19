import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/auth_repository.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorText = 'Enter the 6 digit OTP sent to your mobile number.';
      });
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      final mobile = auth.readSavedMobile();
      if (mobile == null || mobile.isEmpty) {
        throw const ApiException(message: 'Mobile number was not found.');
      }

      await auth.verifyOtp(
        mobile: mobile,
        otp: otp,
        purpose: auth.readSavedOtpPurpose(),
      );

      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() {
        _errorText = 'Could not verify OTP. Check your connection and retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider);
    final mobile = auth.readSavedMobile() ?? '+91 9876543210';

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
          Text(mobile, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 34),
          MGTextField(
            hintText: '6 digit OTP',
            keyboardType: TextInputType.number,
            controller: _otpController,
            prefix: const Icon(Icons.lock_outline, size: 18),
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
          MGGradientButton(
            label: _isSubmitting ? 'Verifying...' : 'Verify OTP',
            onPressed: _isSubmitting ? null : _verify,
          ),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

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
  final _otpFocusNode = FocusNode();
  String? _errorText;
  bool _isSubmitting = false;
  bool _isResending = false;
  int _secondsRemaining = 30;
  Timer? _resendTimer;
  String? _savedMobile;

  @override
  void initState() {
    super.initState();
    _loadSavedMobile();
    _startResendTimer();
  }

  Future<void> _loadSavedMobile() async {
    final mobile = await ref
        .read(authRepositoryProvider)
        .readSavedMobileAsync();
    if (mounted) {
      setState(() => _savedMobile = mobile);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _secondsRemaining = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    final mobile = _savedMobile;
    if (mobile == null || mobile.isEmpty) {
      setState(
        () => _errorText = 'Mobile number not found. Go back and try again.',
      );
      return;
    }

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.sendOtp(mobile: mobile, purpose: auth.readSavedOtpPurpose());
      if (mounted) {
        setState(() => _otpController.clear());
        _startResendTimer();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorText = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorText =
              'Could not resend OTP. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
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
      // Use async read so cold-start restarts don't silently return null
      final mobile = await auth.readSavedMobileAsync();
      if (mobile == null || mobile.isEmpty) {
        throw const ApiException(message: 'Mobile number was not found.');
      }

      final session = await auth.verifyOtp(
        mobile: mobile,
        otp: otp,
        purpose: auth.readSavedOtpPurpose(),
      );

      if (mounted) {
        if (session.isNewUser) {
          context.go(AppRoutes.onboarding);
        } else {
          context.go(AppRoutes.dashboard);
        }
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
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayMobile = _savedMobile ?? '+91 ••••••••••';

    final defaultPinTheme = PinTheme(
      width: 44,
      height: 56,
      textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: context.tokens.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: context.tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
        border: Border.all(color: context.tokens.borderMuted),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: context.tokens.brandGold, width: 1.4),
      boxShadow: [
        BoxShadow(
          color: context.tokens.brandGold.withValues(alpha: 0.18),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    );
    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: context.tokens.surfaceSoft,
      border: Border.all(
        color: context.tokens.brandGold.withValues(alpha: 0.5),
      ),
    );
    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: context.tokens.danger, width: 1.3),
    );

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
          Text(displayMobile, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 34),
          Pinput(
            length: 6,
            controller: _otpController,
            focusNode: _otpFocusNode,
            enabled: !_isSubmitting,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            errorPinTheme: errorPinTheme,
            forceErrorState: _errorText != null,
            closeKeyboardWhenCompleted: true,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 24),
          if (_secondsRemaining > 0)
            Text(
              'Resend OTP in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            )
          else
            TextButton(
              onPressed: _isResending ? null : _resendOtp,
              child: Text(_isResending ? 'Resending...' : 'Resend OTP'),
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
        ],
      ),
    );
  }
}

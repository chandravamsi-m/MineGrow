import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    _loadDelayAndStartTimer();
  }

  Future<void> _loadSavedMobile() async {
    final mobile = await ref.read(authRepositoryProvider).readSavedMobileAsync();
    if (mounted) setState(() => _savedMobile = mobile);
  }

  /// Reads the resend cooldown that was stored when the OTP was dispatched,
  /// then starts the countdown. This avoids a hardcoded 30-second value.
  Future<void> _loadDelayAndStartTimer() async {
    final delay =
        await ref.read(authRepositoryProvider).readSavedOtpResendDelayAsync();
    if (!mounted) return;
    _secondsRemaining = delay;
    _startResendTimer();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    // _secondsRemaining is set by caller — do NOT reset to a hardcoded value.
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
      final delay =
          await auth.sendOtp(mobile: mobile, purpose: auth.readSavedOtpPurpose());
      if (mounted) {
        _otpController.clear();
        _secondsRemaining = delay;
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
      setState(
        () => _errorText = 'Enter the 6 digit OTP sent to your mobile number.',
      );
      return;
    }
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });
    try {
      final auth = ref.read(authRepositoryProvider);
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
      if (mounted) setState(() => _errorText = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorText =
              'Could not verify OTP. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
    final tokens = context.tokens;
    final metrics = context.metrics;

    // Format the saved mobile for display: +91XXXXXXXXXX → +91 XXXXX XXXXX
    final rawMobile = _savedMobile ?? '';
    final displayMobile = _formatMobile(rawMobile);

    // Compute a pin-box size that fits the available width on narrow phones.
    // 6 boxes + 5 separators (each ~half the box width) must fit inside the
    // content column. Falls back to the prior 48x58 size on roomy screens.
    final double availableWidth =
        MediaQuery.of(context).size.width - (metrics.screenPadding * 2);
    final double separatorRatio = 0.18; // separator = ratio × box width
    final double maxBoxWidth = availableWidth / (6 + (5 * separatorRatio));
    final double boxWidth = maxBoxWidth.clamp(36.0, 48.0);
    final double boxHeight = boxWidth * (58.0 / 48.0);
    final double separator = boxWidth * separatorRatio;

    final defaultPinTheme = PinTheme(
      width: boxWidth,
      height: boxHeight,
      textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: tokens.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: boxWidth * 0.46,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(metrics.radiusMedium),
        border: Border.all(color: tokens.borderMuted),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: tokens.brandGold, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: tokens.brandGold.withValues(alpha: 0.22),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: tokens.surfaceSoft,
      border: Border.all(color: tokens.brandGold.withValues(alpha: 0.55)),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: tokens.danger, width: 1.4),
    );

    return Scaffold(
      backgroundColor: tokens.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Atmospheric background glows ─────────────────────────────────
          Positioned(
            top: -60,
            left: -80,
            child: GlowOrb(color: tokens.brandPurple, size: 280),
          ),
          Positioned(
            bottom: 40,
            right: -80,
            child: GlowOrb(color: tokens.brandGold, size: 220),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                metrics.screenPadding,
                0,
                metrics.screenPadding,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back button ─────────────────────────────────────────
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.auth),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Change number',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Header ──────────────────────────────────────────────
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: tokens.brandGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tokens.brandGold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      color: tokens.brandGold,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify your number',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6 digit code to '),
                        TextSpan(
                          text: displayMobile,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── PIN input ────────────────────────────────────────────
                  Center(
                    child: Pinput(
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
                      closeKeyboardWhenCompleted: false,
                      separatorBuilder: (index) => SizedBox(width: separator),
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      // Auto-submit when all 6 digits are filled
                      onCompleted: (_) => _verify(),
                      onSubmitted: (_) => _verify(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Resend row ───────────────────────────────────────────
                  Center(
                    child: _secondsRemaining > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 15,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Resend code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          )
                        : TextButton.icon(
                            onPressed: _isResending ? null : _resendOtp,
                            icon: _isResending
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: tokens.brandGold,
                                    ),
                                  )
                                : Icon(
                                    Icons.refresh_rounded,
                                    size: 16,
                                    color: tokens.brandGold,
                                  ),
                            label: Text(
                              _isResending ? 'Sending...' : 'Resend code',
                              style: TextStyle(color: tokens.brandGold),
                            ),
                          ),
                  ),

                  // ── Animated error ───────────────────────────────────────
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: _errorText != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: MGInlineMessage(
                              message: _errorText!,
                              tone: MGMessageTone.danger,
                              icon: Icons.error_outline,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 36),

                  // ── Verify button ────────────────────────────────────────
                  MGGradientButton(
                    label: _isSubmitting ? 'Verifying...' : 'Verify Code',
                    onPressed: _isSubmitting ? null : _verify,
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Didn\'t receive the code? Check your SMS inbox\nor tap Resend after the timer ends.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatMobile(String mobile) {
    // +91XXXXXXXXXX → +91 XXXXX XXXXX
    if (mobile.startsWith('+91') && mobile.length == 13) {
      final digits = mobile.substring(3);
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return mobile.isEmpty ? '+91 ••••• •••••' : mobile;
  }
}

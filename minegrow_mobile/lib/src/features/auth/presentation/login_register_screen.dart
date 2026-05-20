import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/auth_repository.dart';

class LoginRegisterScreen extends ConsumerStatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  ConsumerState<LoginRegisterScreen> createState() =>
      _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends ConsumerState<LoginRegisterScreen> {
  final _phoneController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();

    setState(() {
      if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
        _errorText = 'Enter a valid 10 digit mobile number.';
        return;
      }
      _errorText = null;
      _isSubmitting = true;
    });

    if (_errorText != null) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await ref
          .read(authRepositoryProvider)
          .sendOtp(mobile: phone, purpose: 'login');
      if (mounted) context.go(AppRoutes.otp);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(() => _errorText = 'Could not connect. Try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final metrics = context.metrics;

    return Scaffold(
      backgroundColor: tokens.background,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: GlowOrb(color: tokens.brandGold, size: 280),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: .center,
                  children: [
                    // Spacer(),

                    // ── Brand ─────────────────────────────────────────────────
                    // Row(
                    //   children: [
                    //     const MGMiningMark(size: 32),
                    //     const SizedBox(width: 10),
                    //     Text(
                    //       'MineGrow',
                    //       style: Theme.of(
                    //         context,
                    //       ).textTheme.titleMedium?.copyWith(
                    //         color: tokens.brandGold,
                    //         fontWeight: FontWeight.w700,
                    //       ),
                    //     ),
                    //   ],
                    // ),

                    // ── Heading ───────────────────────────────────────────────
                    Text(
                      'Enter your\nmobile number',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "We'll send a verification code to sign you in.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Phone field ───────────────────────────────────────────
                    MGTextField(
                      hintText: '00000 00000',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      controller: _phoneController,
                      prefix: const _CountryCodeBadge(),
                      onSubmitted: (_) => _submit(),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: _errorText != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: MGInlineMessage(
                                message: _errorText!,
                                tone: MGMessageTone.danger,
                                icon: Icons.error_outline,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 20),

                    // ── CTA ───────────────────────────────────────────────────
                    MGGradientButton(
                      label: _isSubmitting
                          ? 'Sending Code...'
                          : 'Send Verification Code',
                      onPressed: _isSubmitting ? null : _submit,
                    ),

                    const SizedBox(height: 24),

                    Center(
                      child: Text(
                        'By continuing you agree to our Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryCodeBadge extends StatelessWidget {
  const _CountryCodeBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🇮🇳', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          '+91',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.tokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 18, color: context.tokens.borderMuted),
        const SizedBox(width: 2),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    debugPrint('[LOGIN] _submit() called — raw input: "$phone"');

    setState(() {
      final digitsOnly = RegExp(r'^\d{10}$');
      if (phone.isEmpty || !digitsOnly.hasMatch(phone)) {
        _errorText = 'Enter a valid 10 digit mobile number to continue.';
        debugPrint('[LOGIN] Validation failed: "$phone" is not a valid 10-digit number');
        return;
      }
      _errorText = null;
      _isSubmitting = true;
    });

    if (_errorText != null) {
      debugPrint('[LOGIN] Aborting — validation error is set, not calling sendOtp');
      setState(() => _isSubmitting = false);
      return;
    }

    debugPrint('[LOGIN] Validation passed — calling sendOtp for $phone');

    try {
      final auth = ref.read(authRepositoryProvider);
      await auth.sendOtp(mobile: phone, purpose: 'login');

      debugPrint('[LOGIN] sendOtp succeeded — mounted=$mounted, navigating to ${AppRoutes.otp}');
      if (mounted) {
        context.go(AppRoutes.otp);
        debugPrint('[LOGIN] context.go(${AppRoutes.otp}) called');
      } else {
        debugPrint('[LOGIN] Widget unmounted after sendOtp — navigation skipped');
      }
    } on ApiException catch (error) {
      debugPrint('[LOGIN] ApiException caught — status=${error.statusCode} message="${error.message}"');
      setState(() => _errorText = error.message);
    } catch (e, st) {
      debugPrint('[LOGIN] Unexpected error caught: $e');
      debugPrint('[LOGIN] Stack trace: $st');
      setState(() {
        _errorText = 'Could not reach the MineGrow server. Try again.';
      });
    } finally {
      debugPrint('[LOGIN] finally block — mounted=$mounted');
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MGScaffold(
      appBar: const MGAppBar(
        title: '',
        showBack: true,
        backRoute: AppRoutes.splash,
      ),
      backFallbackRoute: AppRoutes.splash,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Welcome to MineGrow',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your mobile number to sign in or create an account',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          MGTextField(
            label: 'Enter Mobile Number',
            hintText: 'Enter mobile number',
            keyboardType: TextInputType.phone,
            controller: _phoneController,
            prefix: const Text('+91 '),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            MGInlineMessage(
              message: _errorText!,
              tone: MGMessageTone.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 28),
          MGGradientButton(
            label: _isSubmitting ? 'Sending Code...' : 'Send Verification Code',
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 34),
          Center(
            child: Text(
              'By continuing, you agree to our Terms of Service & Privacy Policy',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.tokens.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

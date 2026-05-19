import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/auth_repository.dart';

enum AuthMode { login, register }

class LoginRegisterScreen extends ConsumerStatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  ConsumerState<LoginRegisterScreen> createState() =>
      _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends ConsumerState<LoginRegisterScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthMode _mode = AuthMode.login;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() {
      if (phone.isEmpty || phone.length < 10) {
        _errorText = 'Enter a valid 10 digit mobile number to continue.';
        return;
      }

      if (password.length < 6) {
        _errorText = 'Password must be at least 6 characters.';
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
      final auth = ref.read(authRepositoryProvider);
      if (_mode == AuthMode.login) {
        await auth.login(mobile: phone, password: password);
      } else {
        await auth.register(
          fullName: 'MineGrow User',
          mobile: phone,
          password: password,
        );
      }

      if (mounted) {
        context.go(AppRoutes.otp);
      }
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() {
        _errorText = 'Could not reach the MineGrow server. Try again.';
      });
    } finally {
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
          Text(
            _mode == AuthMode.login ? 'Welcome Back!' : 'Create Account',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            _mode == AuthMode.login
                ? 'Login to continue'
                : 'Register to start investing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          MGSegmentedControl<AuthMode>(
            value: _mode,
            onChanged: (value) => setState(() => _mode = value),
            items: const [
              MGSegment(label: 'Login', value: AuthMode.login),
              MGSegment(label: 'Register', value: AuthMode.register),
            ],
          ),
          const SizedBox(height: 22),
          MGTextField(
            label: 'Enter Mobile Number',
            hintText: 'Enter mobile number',
            keyboardType: TextInputType.phone,
            controller: _phoneController,
            prefix: const Text('+91'),
          ),
          const SizedBox(height: 18),
          MGTextField(
            label: 'Password',
            hintText: 'Enter password',
            obscureText: true,
            controller: _passwordController,
            suffixIcon: const Icon(Icons.visibility_outlined, size: 18),
          ),
          if (_mode == AuthMode.register) ...[
            const SizedBox(height: 18),
            const MGTextField(
              label: 'Confirm Password',
              hintText: 'Confirm password',
              obscureText: true,
            ),
          ],
          if (_errorText != null) ...[
            const SizedBox(height: 14),
            MGInlineMessage(
              message: _errorText!,
              tone: MGMessageTone.danger,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: 24),
          MGGradientButton(
            label: _isSubmitting
                ? 'Please wait...'
                : (_mode == AuthMode.login ? 'Login' : 'Register'),
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: context.tokens.borderMuted)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or continue with',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ),
              Expanded(child: Divider(color: context.tokens.borderMuted)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _SocialButton(label: 'G'),
              SizedBox(width: 16),
              _SocialButton(icon: Icons.apple),
            ],
          ),
          const SizedBox(height: 34),
          Center(
            child: Text.rich(
              TextSpan(
                text: _mode == AuthMode.login
                    ? "Don't have an account? "
                    : 'Already have an account? ',
                children: [
                  TextSpan(
                    text: _mode == AuthMode.login ? 'Register' : 'Login',
                    style: TextStyle(color: context.tokens.brandGold),
                  ),
                ],
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({this.label, this.icon});

  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.tokens.textPrimary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: icon == null
            ? Text(
                label!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.tokens.background,
                ),
              )
            : Icon(icon, color: context.tokens.background),
      ),
    );
  }
}

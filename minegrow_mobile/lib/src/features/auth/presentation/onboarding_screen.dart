import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/auth_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final address = _addressController.text.trim();

    setState(() {
      if (name.isEmpty || name.length < 2) {
        _errorText = 'Enter your full name to proceed.';
        return;
      }

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (email.isEmpty || !emailRegex.hasMatch(email)) {
        _errorText = 'Enter a valid email address.';
        return;
      }

      if (address.isEmpty || address.length < 4) {
        _errorText = 'Enter a valid residential address.';
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
      await auth.onboardStep1(
        fullName: name,
        email: email,
        address: address,
      );

      if (mounted) {
        context.go(AppRoutes.dashboard);
      }
    } on ApiException catch (error) {
      setState(() => _errorText = error.message);
    } catch (_) {
      setState(() {
        _errorText = 'Could not save profile. Check your connection.';
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
        showBack: false,
      ),
      backFallbackRoute: null,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Activate Account',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Complete your profile details to unlock gold mining investments.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            MGTextField(
              label: 'Full Name',
              hintText: 'Enter your full name',
              controller: _nameController,
              keyboardType: TextInputType.name,
              prefix: const Icon(Icons.person_outline, size: 18),
            ),
            const SizedBox(height: 18),
            MGTextField(
              label: 'Email Address',
              hintText: 'Enter email address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefix: const Icon(Icons.email_outlined, size: 18),
            ),
            const SizedBox(height: 18),
            MGTextField(
              label: 'Residential Address',
              hintText: 'Enter complete street address',
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              prefix: const Icon(Icons.location_on_outlined, size: 18),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 18),
              MGInlineMessage(
                message: _errorText!,
                tone: MGMessageTone.danger,
                icon: Icons.error_outline,
              ),
            ],
            const SizedBox(height: 34),
            MGGradientButton(
              label: _isSubmitting ? 'Saving Profile...' : 'Activate Account',
              onPressed: _isSubmitting ? null : _submit,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

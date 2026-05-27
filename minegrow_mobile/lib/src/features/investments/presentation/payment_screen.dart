import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../app_config/data/app_config_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/investments_repository.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _utrController = TextEditingController();
  PlatformFile? _proofFile;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  Future<void> _selectProof() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _proofFile = result.files.single;
      _errorText = null;
    });
  }

  Future<void> _openUpiApp(String upiDeepLink) async {
    final opened = await launchUrl(
      Uri.parse(upiDeepLink),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a UPI app.')),
      );
    }
  }

  Future<void> _submit() async {
    final utr = _utrController.text.trim();

    if (utr.isEmpty) {
      setState(
        () => _errorText =
            'Enter the UTR / transaction ID from your payment app.',
      );
      return;
    }

    if (_proofFile == null) {
      setState(
        () => _errorText = 'Upload a screenshot of your payment to continue.',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      final MultipartFile proof;
      if (kIsWeb) {
        final bytes = _proofFile!.bytes;
        if (bytes == null) {
          throw const ApiException(message: 'Could not read proof file bytes.');
        }
        proof = MultipartFile.fromBytes(bytes, filename: _proofFile!.name);
      } else {
        final path = _proofFile!.path;
        if (path == null || path.isEmpty) {
          throw const ApiException(
            message: 'Could not locate proof file path.',
          );
        }
        proof = await MultipartFile.fromFile(path, filename: _proofFile!.name);
      }

      await ref
          .read(investmentsRepositoryProvider)
          .createInvestment(
            planId: widget.args.plan.id,
            amount: widget.args.amount,
            utrNumber: utr,
            paymentProof: proof,
          );

      ref.invalidate(ownInvestmentsProvider);
      ref.invalidate(walletSummaryProvider);

      if (mounted) {
        context.go(AppRoutes.investmentPending);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorText = 'Could not submit payment. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.args.plan;
    final amount = widget.args.amount;

    // UPI ID is fetched from the backend; falls back to env-var if unavailable.
    final configState = ref.watch(appConfigProvider);
    final upiId = configState.maybeWhen(
      data: (c) => c.paymentUpiId,
      orElse: () => AppConfig.paymentUpiId,
    );
    final upiDeepLink =
        'upi://pay?pa=$upiId&pn=MineGrow&am=${amount.toStringAsFixed(2)}'
        '&cu=INR&tn=MineGrow+Investment';

    return MGScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.investmentDetails, extra: plan),
        ),
        title: const Text('Complete Payment'),
      ),
      mainNavigationIndex: 1,
      backFallbackRoute: AppRoutes.investmentDetails,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderSummaryCard(plan: plan, amount: amount),
          const SizedBox(height: 24),
          Text('Scan & Pay', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _QRPaymentCard(
            upiDeepLink: upiDeepLink,
            upiId: upiId,
            amount: amount,
            onOpenUpiApp: () => _openUpiApp(upiDeepLink),
          ),
          const SizedBox(height: 24),
          MGTextField(
            label: 'UTR / Transaction Reference Number',
            hintText: 'e.g. 423456789012',
            keyboardType: TextInputType.text,
            controller: _utrController,
          ),
          const SizedBox(height: 20),
          Text(
            'Upload Payment Screenshot',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          MGUploadBox(
            fileName: _proofFile?.name,
            errorText: _errorText?.contains('screenshot') == true
                ? _errorText
                : null,
            onTap: _isSubmitting ? null : _selectProof,
          ),
          if (_errorText != null &&
              _errorText?.contains('screenshot') != true) ...[
            const SizedBox(height: 12),
            MGInlineMessage(
              message: _errorText!,
              tone: MGMessageTone.warning,
              icon: Icons.warning_amber_outlined,
            ),
          ],
          const SizedBox(height: 28),
          MGGradientButton(
            label: _isSubmitting ? 'Submitting...' : "I've Paid – Confirm",
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Payment is verified by our team within 24 hours',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Order Summary ────────────────────────────────────────────────────────────

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.plan, required this.amount});

  final InvestmentPlan plan;
  final num amount;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      gradient: context.tokens.principalGradient,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.tokens.brandGold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.payments_outlined,
              color: context.tokens.brandGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  '${plan.dailyRoi} daily  ·  ${plan.lockPeriod}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(amount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.tokens.brandGold,
                ),
              ),
              Text(
                'to pay',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── QR Payment Card ──────────────────────────────────────────────────────────

class _QRPaymentCard extends StatelessWidget {
  const _QRPaymentCard({
    required this.upiDeepLink,
    required this.upiId,
    required this.amount,
    required this.onOpenUpiApp,
  });

  final String upiDeepLink;
  final String upiId;
  final num amount;
  final VoidCallback onOpenUpiApp;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
            ),
            child: QrImageView(
              data: upiDeepLink,
              version: QrVersions.auto,
              size: 190,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Scan with PhonePe, GPay, Paytm or any UPI app',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          MGGradientButton(
            label: 'Open UPI App',
            icon: Icons.open_in_new,
            onPressed: onOpenUpiApp,
          ),
          const SizedBox(height: 12),
          _UpiIdRow(upiId: upiId),
          const SizedBox(height: 12),
          MGInlineMessage(
            message:
                'After paying, copy the UTR / transaction ID from your UPI app and enter it below.',
            tone: MGMessageTone.info,
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}

class _UpiIdRow extends StatelessWidget {
  const _UpiIdRow({required this.upiId});

  final String upiId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(context.metrics.radiusSmall),
        border: Border.all(color: context.tokens.borderMuted),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 16,
            color: context.tokens.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              upiId,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: upiId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UPI ID copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_outlined,
                  size: 15,
                  color: context.tokens.brandGold,
                ),
                const SizedBox(width: 4),
                Text(
                  'Copy',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.brandGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

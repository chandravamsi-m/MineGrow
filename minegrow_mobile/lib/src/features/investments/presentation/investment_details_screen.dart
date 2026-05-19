import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/investments_repository.dart';

class InvestmentDetailsScreen extends ConsumerStatefulWidget {
  const InvestmentDetailsScreen({super.key, this.initialPlan});

  final InvestmentPlan? initialPlan;

  @override
  ConsumerState<InvestmentDetailsScreen> createState() =>
      _InvestmentDetailsScreenState();
}

class _InvestmentDetailsScreenState
    extends ConsumerState<InvestmentDetailsScreen> {
  final _amountController = TextEditingController();
  PlatformFile? _proofFile;
  String? _messageText;
  bool _isSubmitting = false;
  bool _amountInitialized = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectProof() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _proofFile = result.files.single;
      _messageText = null;
    });
  }

  Future<void> _submit(InvestmentPlan plan) async {
    final amount = num.tryParse(_amountController.text.trim());
    final proofPath = _proofFile?.path;

    setState(() {
      if (amount == null || amount <= 0) {
        _messageText = 'Enter a valid investment amount before submitting.';
        return;
      }

      if (amount < plan.minAmount || amount > plan.maxAmount) {
        _messageText =
            '${plan.name} accepts investments from ${formatCurrency(plan.minAmount)} to ${formatCurrency(plan.maxAmount)}.';
        return;
      }

      if (proofPath == null || proofPath.isEmpty) {
        _messageText = 'Upload a payment proof screenshot to continue.';
        return;
      }

      _messageText = null;
      _isSubmitting = true;
    });

    if (_messageText != null || amount == null || proofPath == null) {
      return;
    }

    try {
      final proof = await MultipartFile.fromFile(
        proofPath,
        filename: _proofFile?.name,
      );
      await ref
          .read(investmentsRepositoryProvider)
          .createInvestment(
            planId: plan.id,
            amount: amount,
            paymentProof: proof,
          );
      ref.invalidate(ownInvestmentsProvider);
      ref.invalidate(walletSummaryProvider);
      if (mounted) {
        setState(() {
          _messageText =
              'Investment submitted. Admin approval will update your wallet.';
          _proofFile = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _messageText = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messageText = 'Could not submit investment. Try again later.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansState = ref.watch(investmentPlansProvider);
    final selectedPlan =
        widget.initialPlan ??
        plansState.maybeWhen(
          data: (plans) => plans.isEmpty ? null : plans.first,
          orElse: () => null,
        );

    if (selectedPlan != null && !_amountInitialized) {
      _amountController.text = selectedPlan.minAmount.toStringAsFixed(0);
      _amountInitialized = true;
    }

    return MGScaffold(
      appBar: const MGAppBar(title: 'Create Investment', showBack: true),
      mainNavigationIndex: 1,
      body: selectedPlan == null
          ? plansState.when(
              loading: () => const MGLoadingList(itemCount: 2),
              error: (error, stackTrace) => MGFriendlyState(
                icon: Icons.cloud_off_outlined,
                title: 'Plan details could not load',
                message:
                    'Refresh plans and select one again before creating an investment.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(investmentPlansProvider),
              ),
              data: (_) => MGFriendlyState(
                icon: Icons.landscape_outlined,
                title: 'No plan selected',
                message:
                    'Choose an active investment plan before uploading payment proof.',
                actionLabel: 'Refresh Plans',
                onAction: () => ref.invalidate(investmentPlansProvider),
              ),
            )
          : _InvestmentForm(
              plan: selectedPlan,
              amountController: _amountController,
              proofFileName: _proofFile?.name,
              messageText: _messageText,
              isSubmitting: _isSubmitting,
              onSelectProof: _selectProof,
              onSubmit: () => _submit(selectedPlan),
            ),
    );
  }
}

class _InvestmentForm extends StatelessWidget {
  const _InvestmentForm({
    required this.plan,
    required this.amountController,
    required this.proofFileName,
    required this.messageText,
    required this.isSubmitting,
    required this.onSelectProof,
    required this.onSubmit,
  });

  final InvestmentPlan plan;
  final TextEditingController amountController;
  final String? proofFileName;
  final String? messageText;
  final bool isSubmitting;
  final VoidCallback onSelectProof;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final success = messageText?.startsWith('Investment submitted') == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selected Plan', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        MGCard(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  context.metrics.radiusSmall,
                ),
                child: Image.asset(
                  plan.assetPath,
                  width: 66,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.range,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    plan.dailyRoi,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.tokens.brandGold,
                    ),
                  ),
                  Text(
                    plan.lockPeriod,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.brandGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        MGTextField(
          label: 'Enter Amount',
          hintText: plan.minAmount.toStringAsFixed(0),
          keyboardType: TextInputType.number,
          controller: amountController,
          prefix: const Text('Rs'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            AmountChip(formatCurrency(plan.minAmount)),
            AmountChip(formatCurrency((plan.minAmount + plan.maxAmount) / 2)),
            AmountChip(formatCurrency(plan.maxAmount)),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'Upload Payment Proof',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        MGUploadBox(
          fileName: proofFileName,
          errorText: messageText?.contains('proof') == true
              ? messageText
              : null,
          onTap: isSubmitting ? null : onSelectProof,
        ),
        if (messageText != null && messageText?.contains('proof') != true) ...[
          const SizedBox(height: 12),
          MGInlineMessage(
            message: messageText!,
            tone: success ? MGMessageTone.success : MGMessageTone.warning,
            icon: success
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
          ),
        ],
        const SizedBox(height: 28),
        MGGradientButton(
          label: isSubmitting ? 'Submitting...' : 'Submit Investment',
          onPressed: isSubmitting ? null : onSubmit,
        ),
      ],
    );
  }
}

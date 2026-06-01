import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_error_view.dart';
import '../../../shared/widgets/mg_widgets.dart';
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
  String? _errorText;
  bool _amountInitialized = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _proceedToPayment(InvestmentPlan plan) {
    final amount = num.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Enter a valid investment amount.');
      return;
    }

    if (amount < plan.minAmount || amount > plan.maxAmount) {
      setState(() => _errorText =
          '${plan.name} accepts ${formatCurrency(plan.minAmount)} – ${formatCurrency(plan.maxAmount)}.');
      return;
    }

    setState(() => _errorText = null);
    context.go(
      AppRoutes.investmentPayment,
      extra: PaymentArgs(plan: plan, amount: amount),
    );
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
              error: (e, st) => mgErrorView(
                error: e,
                onRetry: () => ref.invalidate(investmentPlansProvider),
                fallbackIcon: Icons.cloud_off_outlined,
                fallbackTitle: 'Plan details could not load',
                fallbackMessage:
                    'Refresh plans and select one again before proceeding.',
              ),
              data: (_) => MGFriendlyState(
                icon: Icons.landscape_outlined,
                title: 'No plan selected',
                message: 'Choose an active investment plan to continue.',
                actionLabel: 'Refresh Plans',
                onAction: () => ref.invalidate(investmentPlansProvider),
              ),
            )
          : _AmountForm(
              plan: selectedPlan,
              amountController: _amountController,
              errorText: _errorText,
              onProceed: () => _proceedToPayment(selectedPlan),
            ),
    );
  }
}

class _AmountForm extends StatelessWidget {
  const _AmountForm({
    required this.plan,
    required this.amountController,
    required this.errorText,
    required this.onProceed,
  });

  final InvestmentPlan plan;
  final TextEditingController amountController;
  final String? errorText;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
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
          label: 'Investment Amount',
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
            _AmountChipButton(
              label: formatCurrency(plan.minAmount),
              onTap: () =>
                  amountController.text = plan.minAmount.toStringAsFixed(0),
            ),
            _AmountChipButton(
              label: formatCurrency((plan.minAmount + plan.maxAmount) / 2),
              onTap: () => amountController.text =
                  ((plan.minAmount + plan.maxAmount) / 2).toStringAsFixed(0),
            ),
            _AmountChipButton(
              label: formatCurrency(plan.maxAmount),
              onTap: () =>
                  amountController.text = plan.maxAmount.toStringAsFixed(0),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          MGInlineMessage(
            message: errorText!,
            tone: MGMessageTone.warning,
            icon: Icons.warning_amber_outlined,
          ),
        ],
        const SizedBox(height: 28),
        MGGradientButton(
          label: 'Pay Now',
          icon: Icons.arrow_forward,
          onPressed: onProceed,
        ),
      ],
    );
  }
}

class _AmountChipButton extends StatelessWidget {
  const _AmountChipButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AmountChip(label),
    );
  }
}

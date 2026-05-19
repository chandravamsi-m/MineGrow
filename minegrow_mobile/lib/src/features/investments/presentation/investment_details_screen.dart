import 'package:flutter/material.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/widgets/mg_widgets.dart';

class InvestmentDetailsScreen extends StatefulWidget {
  const InvestmentDetailsScreen({super.key});

  @override
  State<InvestmentDetailsScreen> createState() =>
      _InvestmentDetailsScreenState();
}

class _InvestmentDetailsScreenState extends State<InvestmentDetailsScreen> {
  final _amountController = TextEditingController(text: '20000');
  String? _proofFileName;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectProof() {
    setState(() {
      _proofFileName = 'payment-proof.png';
      _errorText = null;
    });
  }

  void _submit() {
    final amount = num.tryParse(_amountController.text.trim());

    setState(() {
      if (amount == null || amount <= 0) {
        _errorText = 'Enter a valid investment amount before submitting.';
        return;
      }

      if (amount < 10001 || amount > 50000) {
        _errorText = 'Silver Plan accepts investments from ₹10,001 to ₹50,000.';
        return;
      }

      if (_proofFileName == null) {
        _errorText = 'Upload a payment proof screenshot to continue.';
        return;
      }

      _errorText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = investmentPlans[1];

    return MGScaffold(
      appBar: const MGAppBar(title: 'Create Investment', showBack: true),
      mainNavigationIndex: 1,
      body: Column(
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
            hintText: '20000',
            keyboardType: TextInputType.number,
            controller: _amountController,
            prefix: const Text('₹'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              AmountChip('₹10,000'),
              AmountChip('₹20,000'),
              AmountChip('₹30,000'),
              AmountChip('₹50,000'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Upload Payment Proof',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          MGUploadBox(
            fileName: _proofFileName,
            errorText: _errorText?.contains('proof') == true
                ? _errorText
                : null,
            onTap: _selectProof,
          ),
          if (_errorText != null && _errorText?.contains('proof') != true) ...[
            const SizedBox(height: 12),
            MGInlineMessage(
              message: _errorText!,
              tone: MGMessageTone.warning,
              icon: Icons.warning_amber_outlined,
            ),
          ],
          const SizedBox(height: 28),
          MGGradientButton(label: 'Submit Investment', onPressed: _submit),
        ],
      ),
    );
  }
}

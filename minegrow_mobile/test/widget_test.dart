import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow/src/app/app.dart';
import 'package:minegrow/src/app/theme/app_theme.dart';
import 'package:minegrow/src/features/history/presentation/withdrawal_history_screen.dart';
import 'package:minegrow/src/features/investments/data/investments_repository.dart';
import 'package:minegrow/src/features/investments/presentation/investment_plans_screen.dart';
import 'package:minegrow/src/features/withdrawal/data/withdrawals_repository.dart';
import 'package:minegrow/src/shared/data/app_models.dart';
import 'package:minegrow/src/shared/data/mock_data.dart';

void main() {
  testWidgets('renders the MineGrow splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MineGrowApp()));

    expect(find.text('MINEGROW'), findsOneWidget);
    expect(find.text('Grow Today, Earn Tomorrow'), findsOneWidget);
  });

  testWidgets('renders bottom navigation on investment plans', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        overrides: [
          investmentPlansProvider.overrideWith((ref) => investmentPlans),
        ],
        child: const InvestmentPlansScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Investment Plans'), findsOneWidget);
    expect(find.text('Starter Plan'), findsOneWidget);
    expect(find.text('Silver Plan'), findsOneWidget);
    expect(find.text('Gold Plan'), findsOneWidget);
    expect(find.text('Investments'), findsOneWidget);
  });

  testWidgets('renders withdrawal status chips', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        overrides: [withdrawalsProvider.overrideWith((ref) => _withdrawals)],
        child: const WithdrawalHistoryScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Withdrawal History'), findsOneWidget);
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.overrides = const []});

  final Widget child;
  final List<Object?> overrides;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(theme: AppTheme.dark, home: child),
    );
  }
}

const _withdrawals = [
  WithdrawalItem(
    id: 1,
    type: 'roi',
    amount: 5000,
    status: 'pending',
    requestedAt: '20 May 2024',
  ),
  WithdrawalItem(
    id: 2,
    type: 'roi',
    amount: 10000,
    status: 'approved',
    requestedAt: '15 May 2024',
  ),
  WithdrawalItem(
    id: 3,
    type: 'principal',
    amount: 20000,
    status: 'pending',
    requestedAt: '10 May 2024',
  ),
  WithdrawalItem(
    id: 4,
    type: 'roi',
    amount: 15000,
    status: 'rejected',
    requestedAt: '05 May 2024',
  ),
];

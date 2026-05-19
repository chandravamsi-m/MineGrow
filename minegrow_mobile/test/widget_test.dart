import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minegrow_mobile/src/app/app.dart';
import 'package:minegrow_mobile/src/app/theme/app_theme.dart';
import 'package:minegrow_mobile/src/features/history/presentation/withdrawal_history_screen.dart';
import 'package:minegrow_mobile/src/features/investments/presentation/investment_plans_screen.dart';

void main() {
  testWidgets('renders the MineGrow splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MineGrowApp()));

    expect(find.text('MINEGROW'), findsOneWidget);
    expect(find.text('Grow Today, Earn Tomorrow'), findsOneWidget);
  });

  testWidgets('renders bottom navigation on investment plans', (tester) async {
    await tester.pumpWidget(_TestApp(child: const InvestmentPlansScreen()));

    expect(find.text('Investment Plans'), findsOneWidget);
    expect(find.text('Starter Plan'), findsOneWidget);
    expect(find.text('Silver Plan'), findsOneWidget);
    expect(find.text('Gold Plan'), findsOneWidget);
    expect(find.text('Investments'), findsOneWidget);
  });

  testWidgets('renders withdrawal status chips', (tester) async {
    await tester.pumpWidget(_TestApp(child: const WithdrawalHistoryScreen()));

    expect(find.text('Withdrawal History'), findsOneWidget);
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: AppTheme.dark, home: child);
  }
}

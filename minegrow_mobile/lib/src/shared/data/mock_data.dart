import 'package:flutter/material.dart';

import 'app_models.dart';
import '../widgets/mg_widgets.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    this.status,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String date;
  final MGStatus? status;
}

class NotificationItem {
  const NotificationItem({
    required this.title,
    required this.message,
    required this.date,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final String date;
  final IconData icon;
  final Color color;
}

const investmentPlans = [
  InvestmentPlan(
    id: 1,
    name: 'Starter Plan',
    minAmount: 1000,
    maxAmount: 10000,
    dailyRoiPct: 1,
    lockDays: 90,
    roiWithdrawDays: 30,
    isActive: true,
    icon: Icons.landscape_outlined,
    assetPath: 'assets/images/minegrow/plan_starter_ore.png',
  ),
  InvestmentPlan(
    id: 2,
    name: 'Silver Plan',
    minAmount: 10001,
    maxAmount: 50000,
    dailyRoiPct: 1.2,
    lockDays: 90,
    roiWithdrawDays: 30,
    isActive: true,
    icon: Icons.account_balance_outlined,
    assetPath: 'assets/images/minegrow/plan_silver_ore.png',
  ),
  InvestmentPlan(
    id: 3,
    name: 'Gold Plan',
    minAmount: 50001,
    maxAmount: 500000,
    dailyRoiPct: 1.5,
    lockDays: 90,
    roiWithdrawDays: 30,
    isActive: true,
    icon: Icons.diamond_outlined,
    assetPath: 'assets/images/minegrow/plan_gold_ore.png',
  ),
];

const roiHistory = [
  HistoryEntry(
    title: '20 May 2024',
    subtitle: 'Investment ID : #INV1002',
    amount: '+₹1,000.00',
    date: '20 May 2024',
  ),
  HistoryEntry(
    title: '19 May 2024',
    subtitle: 'Investment ID : #INV1002',
    amount: '+₹1,000.00',
    date: '19 May 2024',
  ),
  HistoryEntry(
    title: '18 May 2024',
    subtitle: 'Investment ID : #INV1002',
    amount: '+₹1,000.00',
    date: '18 May 2024',
  ),
  HistoryEntry(
    title: '17 May 2024',
    subtitle: 'Investment ID : #INV1002',
    amount: '+₹1,000.00',
    date: '17 May 2024',
  ),
];

const withdrawalHistory = [
  HistoryEntry(
    title: '₹ 5,000.00',
    subtitle: 'ROI Withdrawal',
    amount: '',
    date: '20 May 2024',
    status: MGStatus.pending,
  ),
  HistoryEntry(
    title: '₹ 10,000.00',
    subtitle: 'ROI Withdrawal',
    amount: '',
    date: '15 May 2024',
    status: MGStatus.approved,
  ),
  HistoryEntry(
    title: '₹ 20,000.00',
    subtitle: 'Principal Withdrawal',
    amount: '',
    date: '10 May 2024',
    status: MGStatus.pending,
  ),
  HistoryEntry(
    title: '₹ 15,000.00',
    subtitle: 'ROI Withdrawal',
    amount: '',
    date: '05 May 2024',
    status: MGStatus.rejected,
  ),
];

const notifications = [
  NotificationItem(
    title: 'ROI Credited',
    message: '₹1,000 has been credited to your ROI wallet.',
    date: '20 May 2024',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFFF59E0B),
  ),
  NotificationItem(
    title: 'Deposit Approved',
    message: 'Your investment of ₹20,000 is approved.',
    date: '18 May 2024',
    icon: Icons.check_circle_outline,
    color: Color(0xFF22C55E),
  ),
  NotificationItem(
    title: 'Withdrawal Approved',
    message: 'Your withdrawal of ₹5,000 is approved.',
    date: '15 May 2024',
    icon: Icons.savings_outlined,
    color: Color(0xFF22C55E),
  ),
  NotificationItem(
    title: 'Maintenance Notice',
    message: 'The platform will be under maintenance on 10 May 2024.',
    date: '10 May 2024',
    icon: Icons.notifications_active_outlined,
    color: Color(0xFF7C4DFF),
  ),
];

bool mockIsLoading(String screen) => false;

bool mockHasLoadError(String screen) => false;

bool mockHasData(String screen) => true;

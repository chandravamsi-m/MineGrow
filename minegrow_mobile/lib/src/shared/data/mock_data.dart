import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../widgets/mg_widgets.dart';

class InvestmentPlan {
  const InvestmentPlan({
    required this.name,
    required this.range,
    required this.dailyRoi,
    required this.lockPeriod,
    required this.icon,
    required this.assetPath,
  });

  final String name;
  final String range;
  final String dailyRoi;
  final String lockPeriod;
  final IconData icon;
  final String assetPath;
}

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
    name: 'Starter Plan',
    range: '₹1,000 - ₹10,000',
    dailyRoi: '1%',
    lockPeriod: '90 Days Lock',
    icon: Icons.landscape_outlined,
    assetPath: AppAssets.planStarterOre,
  ),
  InvestmentPlan(
    name: 'Silver Plan',
    range: '₹10,001 - ₹50,000',
    dailyRoi: '1.2%',
    lockPeriod: '90 Days Lock',
    icon: Icons.account_balance_outlined,
    assetPath: AppAssets.planSilverOre,
  ),
  InvestmentPlan(
    name: 'Gold Plan',
    range: '₹50,001 - ₹5,00,000',
    dailyRoi: '1.5%',
    lockPeriod: '90 Days Lock',
    icon: Icons.diamond_outlined,
    assetPath: AppAssets.planGoldOre,
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

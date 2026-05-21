import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_assets.dart';
import '../widgets/mg_widgets.dart';

num _numValue(Object? value) {
  if (value is num) {
    return value;
  }
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

int _intValue(Object? value) => _numValue(value).toInt();

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

String formatCurrency(num amount) {
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs ',
    decimalDigits: 2,
  ).format(amount);
}

class InvestmentPlan {
  const InvestmentPlan({
    required this.id,
    required this.name,
    required this.minAmount,
    required this.maxAmount,
    required this.dailyRoiPct,
    required this.lockDays,
    required this.roiWithdrawDays,
    required this.isActive,
    required this.icon,
    required this.assetPath,
  });

  final int id;
  final String name;
  final num minAmount;
  final num maxAmount;
  final num dailyRoiPct;
  final int lockDays;
  final int roiWithdrawDays;
  final bool isActive;
  final IconData icon;
  final String assetPath;

  String get range =>
      '${formatCurrency(minAmount)} - ${formatCurrency(maxAmount)}';

  String get dailyRoi =>
      '${dailyRoiPct.toStringAsFixed(dailyRoiPct % 1 == 0 ? 0 : 1)}%';

  String get lockPeriod => '$lockDays Days Lock';

  Color get planColor => _planColor(id);

  static Color _planColor(int id) {
    return switch (id) {
      1 => const Color(0xFFF59E0B), // brandOrange — Starter
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFFDBA2D), // brandGold — Gold
      _ => const Color(0xFFFDBA2D),
    };
  }

  factory InvestmentPlan.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final id = _intValue(map['id']);

    return InvestmentPlan(
      id: id,
      name: _stringValue(map['plan_name'], fallback: 'Investment Plan'),
      minAmount: _numValue(map['min_amount']),
      maxAmount: _numValue(map['max_amount']),
      dailyRoiPct: _numValue(map['daily_roi_pct']),
      lockDays: _intValue(map['lock_days']),
      roiWithdrawDays: _intValue(map['roi_withdraw_days']),
      isActive: map['is_active'] != false,
      icon: _planIcon(id),
      assetPath: _planAsset(id),
    );
  }

  static IconData _planIcon(int id) {
    return switch (id) {
      1 => Icons.landscape_outlined,
      2 => Icons.account_balance_outlined,
      3 => Icons.diamond_outlined,
      _ => Icons.savings_outlined,
    };
  }

  static String _planAsset(int id) {
    return switch (id) {
      1 => AppAssets.planStarterOre,
      2 => AppAssets.planSilverOre,
      3 => AppAssets.planGoldOre,
      _ => AppAssets.planStarterOre,
    };
  }
}

class WalletSummary {
  const WalletSummary({
    required this.roiBalance,
    required this.principalBalance,
    required this.totalRoiEarned,
    this.lastRoiWithdrawalAt,
  });

  final num roiBalance;
  final num principalBalance;
  final num totalRoiEarned;
  final String? lastRoiWithdrawalAt;

  num get totalBalance => roiBalance + principalBalance;

  factory WalletSummary.empty() {
    return const WalletSummary(
      roiBalance: 0,
      principalBalance: 0,
      totalRoiEarned: 0,
    );
  }

  factory WalletSummary.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return WalletSummary(
      roiBalance: _numValue(map['roi_balance']),
      principalBalance: _numValue(map['principal_balance']),
      totalRoiEarned: _numValue(map['total_roi_earned']),
      lastRoiWithdrawalAt: map['last_roi_withdrawal_at']?.toString(),
    );
  }
}

class InvestmentRecord {
  const InvestmentRecord({
    required this.id,
    required this.planId,
    this.planName,
    required this.amount,
    required this.dailyRoiPct,
    required this.lockDays,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int planId;
  /// Plan name as returned by the API (e.g. "Gold Plan"). May be null if the
  /// investments endpoint does not include plan details — fall back to the
  /// plans list cross-reference in that case.
  final String? planName;
  final num amount;
  final num dailyRoiPct;
  final int lockDays;
  final String status;
  final String createdAt;

  bool get isActive => status == 'approved' || status == 'active';

  factory InvestmentRecord.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return InvestmentRecord(
      id: _intValue(map['id']),
      planId: _intValue(map['plan_id']),
      planName: (map['plan_name'] ?? map['planName'])?.toString(),
      amount: _numValue(map['amount']),
      dailyRoiPct: _numValue(map['daily_roi_pct']),
      lockDays: _intValue(map['lock_days']),
      status: _stringValue(map['status'], fallback: 'pending'),
      createdAt: _stringValue(map['created_at']),
    );
  }
}

class RoiHistoryItem {
  const RoiHistoryItem({
    required this.id,
    required this.investmentId,
    required this.amount,
    required this.creditedDate,
  });

  final int id;
  final int investmentId;
  final num amount;
  final String creditedDate;

  factory RoiHistoryItem.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return RoiHistoryItem(
      id: _intValue(map['id']),
      investmentId: _intValue(map['investment_id']),
      amount: _numValue(map['roi_amount']),
      creditedDate: _stringValue(map['credited_date']),
    );
  }
}

class WithdrawalItem {
  const WithdrawalItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.requestedAt,
  });

  final int id;
  final String type;
  final num amount;
  final String status;
  final String requestedAt;

  MGStatus get chipStatus {
    return switch (status) {
      'approved' || 'completed' => MGStatus.approved,
      'rejected' => MGStatus.rejected,
      _ => MGStatus.pending,
    };
  }

  factory WithdrawalItem.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return WithdrawalItem(
      id: _intValue(map['id']),
      type: _stringValue(map['withdrawal_type'], fallback: 'roi'),
      amount: _numValue(map['amount']),
      status: _stringValue(map['status'], fallback: 'requested'),
      requestedAt: _stringValue(map['requested_at']),
    );
  }
}

class WithdrawalEligibility {
  const WithdrawalEligibility({
    required this.roiEligible,
    required this.roiMessage,
    required this.roiBalance,
    required this.principalEligible,
    required this.principalMessage,
    required this.principalBalance,
  });

  final bool roiEligible;
  final String roiMessage;
  final num roiBalance;
  final bool principalEligible;
  final String principalMessage;
  final num principalBalance;

  factory WithdrawalEligibility.fallback() {
    return const WithdrawalEligibility(
      roiEligible: false,
      roiMessage: 'Login to check ROI withdrawal eligibility.',
      roiBalance: 0,
      principalEligible: false,
      principalMessage: 'Login to check principal withdrawal eligibility.',
      principalBalance: 0,
    );
  }

  factory WithdrawalEligibility.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    final roi = (map['roi'] as Map?)?.cast<String, dynamic>() ?? {};
    final principal = (map['principal'] as Map?)?.cast<String, dynamic>() ?? {};

    return WithdrawalEligibility(
      roiEligible: roi['eligible'] == true,
      roiMessage: _stringValue(roi['message']),
      roiBalance: _numValue(roi['balance']),
      principalEligible: principal['eligible'] == true,
      principalMessage: _stringValue(principal['message']),
      principalBalance: _numValue(principal['balance']),
    );
  }
}

/// Per-category notification preferences fetched from the user profile.
/// Used as default values when the device has no locally stored preference.
class NotificationPreferences {
  const NotificationPreferences({
    this.push = true,
    this.investments = true,
    this.wallet = true,
    this.promotions = false,
  });

  final bool push;
  final bool investments;
  final bool wallet;
  final bool promotions;

  static const defaults = NotificationPreferences();

  factory NotificationPreferences.fromJson(Object? json) {
    if (json == null) return defaults;
    final map = (json as Map?)?.cast<String, dynamic>() ?? {};
    return NotificationPreferences(
      push: map['push'] != false,
      investments: map['investments'] != false,
      wallet: map['wallet'] != false,
      promotions: map['promotions'] == true,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.mobile,
    this.email,
    this.address,
    required this.status,
    required this.kycVerified,
    this.notificationPreferences = NotificationPreferences.defaults,
  });

  final int id;
  final String fullName;
  final String mobile;
  final String? email;
  final String? address;
  final String status;
  final bool kycVerified;
  final NotificationPreferences notificationPreferences;

  factory UserProfile.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return UserProfile(
      id: _intValue(map['id']),
      fullName: _stringValue(map['full_name'] ?? map['fullName']),
      mobile: _stringValue(map['mobile']),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      status: _stringValue(map['status'], fallback: 'active'),
      kycVerified: map['kyc_verified'] == true,
      notificationPreferences: NotificationPreferences.fromJson(
        map['notification_preferences'] ?? map['notificationPreferences'],
      ),
    );
  }
}

class PaymentArgs {
  const PaymentArgs({required this.plan, required this.amount});

  final InvestmentPlan plan;
  final num amount;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.user,
    this.isNewUser = false,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile? user;
  final bool isNewUser;

  factory AuthSession.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return AuthSession(
      accessToken: _stringValue(map['accessToken']),
      refreshToken: _stringValue(map['refreshToken']),
      user: map['user'] == null ? null : UserProfile.fromJson(map['user']),
      isNewUser: map['isNewUser'] == true,
    );
  }
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.accountType,
    required this.bankName,
    required this.accountNumber,
    required this.ifscCode,
    this.accountHolder,
    this.upiId,
    this.isPrimary = false,
  });

  final int id;
  final String accountType;
  final String bankName;
  final String accountNumber;
  final String ifscCode;
  final String? accountHolder;
  final String? upiId;
  final bool isPrimary;

  bool get isUpi => accountType == 'upi' || (upiId?.isNotEmpty ?? false);
  bool get isBank => !isUpi;

  String get maskedNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  factory BankAccount.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return BankAccount(
      id: _intValue(map['id']),
      accountType: _stringValue(
        map['account_type'] ?? map['accountType'],
        fallback: 'bank',
      ),
      bankName: _stringValue(
        map['bank_name'] ?? map['bankName'],
        fallback: 'Bank',
      ),
      accountNumber: _stringValue(
        map['account_number'] ?? map['accountNumber'],
      ),
      ifscCode: _stringValue(map['ifsc_code'] ?? map['ifscCode']),
      accountHolder: (map['account_holder'] ?? map['accountHolder'])
          ?.toString(),
      upiId: (map['upi_id'] ?? map['upiId'])?.toString(),
      isPrimary:
          map['is_primary'] == true ||
          map['isPrimary'] == true ||
          map['is_default'] == true ||
          map['isDefault'] == true,
    );
  }
}

class ApiNotification {
  const ApiNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  final int id;
  final String title;
  final String message;
  final String type;
  final String createdAt;
  final bool isRead;

  factory ApiNotification.fromJson(Object? json) {
    final map = json as Map<String, dynamic>;
    return ApiNotification(
      id: _intValue(map['id']),
      title: _stringValue(map['title']),
      message: _stringValue(map['message'] ?? map['body']),
      type: _stringValue(
        map['type'] ?? map['notification_type'],
        fallback: 'general',
      ),
      createdAt: _stringValue(map['created_at'] ?? map['createdAt']),
      isRead: map['is_read'] == true || map['isRead'] == true,
    );
  }
}

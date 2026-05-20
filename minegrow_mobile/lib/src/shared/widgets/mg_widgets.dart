import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/minegrow_tokens.dart';
import '../data/app_models.dart';

class MGScaffold extends StatelessWidget {
  const MGScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.mainNavigationIndex,
    this.backFallbackRoute = AppRoutes.dashboard,
    this.padding,
    this.scrollable = true,
    this.safeArea = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final int? mainNavigationIndex;
  final String? backFallbackRoute;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;
    final isInsideMainNavigation =
        _MainNavigationShellScope.maybeOf(context) != null;
    final content = Padding(
      padding: padding ?? EdgeInsets.all(metrics.screenPadding),
      child: body,
    );

    final page = safeArea ? SafeArea(child: content) : content;

    final scaffold = Scaffold(
      extendBody: true,
      appBar: appBar,
      backgroundColor: context.tokens.background,
      bottomNavigationBar: isInsideMainNavigation
          ? null
          : bottomNavigationBar ??
                (mainNavigationIndex == null
                    ? null
                    : MGBottomNav(currentIndex: mainNavigationIndex!)),
      body: scrollable ? SingleChildScrollView(child: page) : page,
    );

    if (backFallbackRoute == null) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || backFallbackRoute == null) {
          return;
        }

        final currentPath = GoRouterState.of(context).uri.path;
        if (currentPath != backFallbackRoute) {
          context.go(backFallbackRoute!);
        }
      },
      child: scaffold,
    );
  }
}

class MGMainNavigationShell extends StatelessWidget {
  const MGMainNavigationShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _MainNavigationShellScope(
      child: Scaffold(
        extendBody: true,
        backgroundColor: context.tokens.background,
        bottomNavigationBar: MGBottomNav(
          currentIndex: _indexForLocation(location),
        ),
        body: child,
      ),
    );
  }

  static int _indexForLocation(String location) {
    if (location == AppRoutes.investments ||
        location == AppRoutes.investmentDetails ||
        location == AppRoutes.investmentPayment ||
        location == AppRoutes.investmentPending) {
      return 1;
    }
    if (location == AppRoutes.wallet || location == AppRoutes.withdrawal) {
      return 2;
    }
    if (location == AppRoutes.roiHistory ||
        location == AppRoutes.withdrawalHistory) {
      return 3;
    }
    if (location == AppRoutes.profile || location == AppRoutes.notifications) {
      return 4;
    }
    return 0;
  }
}

class _MainNavigationShellScope extends InheritedWidget {
  const _MainNavigationShellScope({required super.child});

  static _MainNavigationShellScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_MainNavigationShellScope>();
  }

  @override
  bool updateShouldNotify(_MainNavigationShellScope oldWidget) => false;
}

class MGAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MGAppBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.backRoute = AppRoutes.dashboard,
    this.action,
  });

  final String title;
  final bool showBack;
  final String? backRoute;
  final Widget? action;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showBack
          ? IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                if (backRoute != null) {
                  context.go(backRoute!);
                } else if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.dashboard);
                }
              },
            )
          : null,
      title: Text(title),
      actions: action == null ? null : [action!, const SizedBox(width: 12)],
    );
  }
}

class MGGradientButton extends StatelessWidget {
  const MGGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: metrics.fieldHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? context.tokens.primaryGradient : null,
          color: enabled ? null : context.tokens.surfaceSoft,
          borderRadius: BorderRadius.circular(metrics.radiusMedium),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(metrics.radiusMedium),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: context.tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum MGMessageTone { info, success, warning, danger }

class MGInlineMessage extends StatelessWidget {
  const MGInlineMessage({
    super.key,
    required this.message,
    this.tone = MGMessageTone.info,
    this.icon,
  });

  final String message;
  final MGMessageTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MGMessageTone.info => context.tokens.brandPurple,
      MGMessageTone.success => context.tokens.success,
      MGMessageTone.warning => context.tokens.warning,
      MGMessageTone.danger => context.tokens.danger,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.tokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MGFriendlyState extends StatelessWidget {
  const MGFriendlyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      padding: EdgeInsets.all(
        compact ? context.metrics.compactPadding : context.metrics.cardPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 42 : 58,
            height: compact ? 42 : 58,
            decoration: BoxDecoration(
              color: context.tokens.brandGold.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: context.tokens.brandGold,
              size: compact ? 22 : 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.tokens.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            MGGradientButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class MGLoadingList extends StatelessWidget {
  const MGLoadingList({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          const _SkeletonCard(),
          if (i != itemCount - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return MGCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 130),
          const SizedBox(height: 12),
          _SkeletonLine(width: double.infinity),
          const SizedBox(height: 8),
          _SkeletonLine(width: 210),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: context.tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class MGSegmentedControl<T> extends StatelessWidget {
  const MGSegmentedControl({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<MGSegment<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.tokens.surfaceElevated,
        borderRadius: BorderRadius.circular(metrics.radiusMedium),
        border: Border.all(color: context.tokens.borderMuted),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _SegmentButton<T>(
                item: item,
                selected: item.value == value,
                onTap: () => onChanged(item.value),
              ),
            ),
        ],
      ),
    );
  }
}

class MGSegment<T> {
  const MGSegment({required this.label, required this.value});

  final String label;
  final T value;
}

class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MGSegment<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected ? context.tokens.primaryGradient : null,
        borderRadius: BorderRadius.circular(metrics.radiusSmall),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.radiusSmall),
        onTap: onTap,
        child: Center(
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? context.tokens.textPrimary
                  : context.tokens.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class MGTextField extends StatefulWidget {
  const MGTextField({
    super.key,
    required this.hintText,
    this.label,
    this.prefix,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.controller,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
  });

  final String? label;
  final String hintText;
  final Widget? prefix;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<MGTextField> createState() => _MGTextFieldState();
}

class _MGTextFieldState extends State<MGTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final Widget? effectiveSuffixIcon = widget.obscureText
        ? GestureDetector(
            onTap: () {
              setState(() {
                _obscured = !_obscured;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14, left: 8),
              child: Icon(
                _obscured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: context.tokens.textSecondary,
              ),
            ),
          )
        : widget.suffixIcon;

    final field = SizedBox(
      height: context.metrics.fieldHeight,
      child: TextField(
        controller: widget.controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: widget.prefix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: widget.prefix,
                ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: effectiveSuffixIcon,
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );

    if (widget.label == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label!,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.tokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class MGCard extends StatelessWidget {
  const MGCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient ?? context.tokens.surfaceGradient,
        borderRadius: BorderRadius.circular(metrics.radiusLarge),
        border: Border.all(color: context.tokens.borderMuted),
        boxShadow: context.tokens.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(metrics.radiusLarge),
          onTap: onTap,
          child: Padding(
            padding: padding ?? EdgeInsets.all(metrics.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MGStatCard extends StatelessWidget {
  const MGStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MGCard(
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        children: [
          _IconTile(icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum MGStatus { pending, approved, rejected, locked, verified }

class MGStatusChip extends StatelessWidget {
  const MGStatusChip({super.key, required this.status});

  final MGStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MGStatus.pending => ('Pending', context.tokens.warning),
      MGStatus.approved => ('Approved', context.tokens.success),
      MGStatus.rejected => ('Rejected', context.tokens.danger),
      MGStatus.locked => ('Locked', context.tokens.warning),
      MGStatus.verified => ('Verified', context.tokens.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MGBottomNav extends StatelessWidget {
  const MGBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _NavItem('Home', Icons.home_outlined, Icons.home, AppRoutes.dashboard),
    _NavItem(
      'Investments',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      AppRoutes.investments,
    ),
    _NavItem('Wallet', Icons.wallet_outlined, Icons.wallet, AppRoutes.wallet),
    _NavItem(
      'History',
      Icons.history_outlined,
      Icons.history,
      AppRoutes.roiHistory,
    ),
    _NavItem('Profile', Icons.person_outline, Icons.person, AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: context.metrics.bottomNavHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: context.tokens.surface.withValues(alpha: 0.96),
          border: Border(top: BorderSide(color: context.tokens.borderMuted)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _BottomNavButton(
                  item: _items[i],
                  selected: i == currentIndex,
                  onTap: () => context.go(_items[i].route),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MGUploadBox extends StatelessWidget {
  const MGUploadBox({super.key, this.fileName, this.errorText, this.onTap});

  final String? fileName;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = errorText == null
        ? context.tokens.brandOrange
        : context.tokens.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: _DashedBorderPainter(
            color: borderColor.withValues(alpha: 0.55),
            radius: context.metrics.radiusMedium,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(context.metrics.radiusMedium),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              decoration: BoxDecoration(
                color: context.tokens.background.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(
                  context.metrics.radiusMedium,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    fileName == null
                        ? Icons.upload_file_outlined
                        : Icons.check_circle_outline,
                    color: fileName == null
                        ? context.tokens.textPrimary
                        : context.tokens.success,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fileName ?? 'Upload Screenshot',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName == null
                        ? 'JPG, PNG, PDF up to 5MB'
                        : 'Tap to replace the selected proof',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.tokens.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class MGProgressBar extends StatelessWidget {
  const MGProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: value,
        backgroundColor: context.tokens.surfaceSoft,
        valueColor: AlwaysStoppedAnimation(context.tokens.brandOrange),
      ),
    );
  }
}

class MGCircularProgress extends StatelessWidget {
  const MGCircularProgress({
    super.key,
    required this.value,
    required this.label,
  });

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 70,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 7,
            backgroundColor: context.tokens.surfaceSoft,
            valueColor: AlwaysStoppedAnimation(context.tokens.brandPurple),
          ),
          Center(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

class MGMiniLineChart extends StatelessWidget {
  const MGMiniLineChart({super.key, required this.color, this.height = 58});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _LineChartPainter(color)),
    );
  }
}

class MGMiningMark extends StatelessWidget {
  const MGMiningMark({super.key, this.size = 82});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.tokens.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: context.tokens.brandGold.withValues(alpha: 0.38),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: size * 0.48,
        color: context.tokens.background,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    );
  }
}

class AmountChip extends StatelessWidget {
  const AmountChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: context.tokens.surfaceElevated,
      side: BorderSide(color: context.tokens.borderMuted),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: context.tokens.textSecondary),
    );
  }
}

// ── Active Plan Card ────────────────────────────────────────────────────────

class MGActivePlanCard extends StatelessWidget {
  const MGActivePlanCard({super.key, required this.record});

  final InvestmentRecord record;

  @override
  Widget build(BuildContext context) {
    final roiStr = record.dailyRoiPct.toStringAsFixed(
      record.dailyRoiPct % 1 == 0 ? 0 : 1,
    );

    return MGCard(
      gradient: context.tokens.principalGradient,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.tokens.brandOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: context.tokens.brandOrange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(record.amount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '$roiStr% daily  ·  ${record.lockDays}d lock',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MGStatusChip(status: _toMGStatus(record.status)),
              const SizedBox(height: 5),
              Text(
                _formatDate(record.createdAt),
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

  static MGStatus _toMGStatus(String status) => switch (status) {
    'approved' || 'active' => MGStatus.approved,
    'rejected' => MGStatus.rejected,
    _ => MGStatus.pending,
  };

  static String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: context.tokens.brandGold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: context.tokens.brandGold, size: 19),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? context.tokens.brandGold
        : context.tokens.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(context.metrics.radiusSmall),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.activeIcon : item.icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon, this.route);

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [0.1, 0.16, 0.14, 0.24, 0.36, 0.32, 0.48, 0.42, 0.62, 0.78];
    final path = Path();

    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - values[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.26),
              blurRadius: size * 0.45,
              spreadRadius: size * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}

double clampProgress(double value) => math.max(0, math.min(1, value));

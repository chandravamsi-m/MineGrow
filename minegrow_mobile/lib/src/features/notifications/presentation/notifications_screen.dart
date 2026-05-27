import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/app_models.dart';
import '../../../shared/widgets/mg_widgets.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider);

    return MGScaffold(
      appBar: const MGAppBar(title: 'Notifications', showBack: true),
      mainNavigationIndex: 4,
      body: Column(
        children: [
          notificationsState.when(
            loading: () => const MGLoadingList(),
            error: (error, stackTrace) => MGFriendlyState(
              icon: Icons.notifications_off_outlined,
              title: 'Notifications unavailable',
              message:
                  'We could not refresh your notifications. Try again later.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(notificationsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const MGFriendlyState(
                  icon: Icons.notifications_none,
                  title: 'You are all caught up',
                  message:
                      'Important ROI, deposit, withdrawal, and maintenance updates will appear here.',
                );
              }
              return Column(
                children: [
                  for (final item in items) ...[
                    _NotificationCard(
                      item: item,
                      onTap: item.isRead
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(notificationsRepositoryProvider)
                                    .markAsRead(item.id);
                                ref.invalidate(notificationsProvider);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not mark notification as read.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, this.onTap});

  final ApiNotification item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor(item.type);

    return MGCard(
      onTap: onTap,
      padding: EdgeInsets.all(context.metrics.compactPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.createdAt,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: BoxDecoration(
                color: context.tokens.brandGold,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  static (IconData, Color) _iconAndColor(String type) {
    return switch (type) {
      'roi_credit' => (
        Icons.workspace_premium_outlined,
        const Color(0xFFF59E0B),
      ),
      'deposit' || 'investment_approved' => (
        Icons.check_circle_outline,
        const Color(0xFF22C55E),
      ),
      'withdrawal' || 'withdrawal_approved' => (
        Icons.savings_outlined,
        const Color(0xFF22C55E),
      ),
      'withdrawal_rejected' => (Icons.cancel_outlined, const Color(0xFFEF4444)),
      'maintenance' => (
        Icons.notifications_active_outlined,
        const Color(0xFF7C4DFF),
      ),
      _ => (Icons.info_outline, const Color(0xFF7C4DFF)),
    };
  }
}

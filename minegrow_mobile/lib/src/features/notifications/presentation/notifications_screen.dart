import 'package:flutter/material.dart';

import '../../../app/theme/minegrow_tokens.dart';
import '../../../shared/data/mock_data.dart';
import '../../../shared/widgets/mg_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoading = mockIsLoading('notifications');
    final hasLoadError = mockHasLoadError('notifications');
    final items = notifications;

    return MGScaffold(
      appBar: const MGAppBar(title: 'Notifications', showBack: true),
      mainNavigationIndex: 4,
      body: Column(
        children: [
          if (isLoading)
            const MGLoadingList()
          else if (hasLoadError)
            MGFriendlyState(
              icon: Icons.notifications_off_outlined,
              title: 'Notifications unavailable',
              message:
                  'We could not refresh your notifications. Try again later.',
              actionLabel: 'Retry',
              onAction: () {},
            )
          else if (items.isEmpty)
            MGFriendlyState(
              icon: Icons.notifications_none,
              title: 'You are all caught up',
              message:
                  'Important ROI, deposit, withdrawal, and maintenance updates will appear here.',
            )
          else
            for (final item in items) ...[
              MGCard(
                padding: EdgeInsets.all(context.metrics.compactPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.tokens.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.date,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: context.tokens.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

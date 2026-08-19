import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notification_provider.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final items = notifications.valueOrNull ?? const <NotificationItem>[];
    final hasUnread = items.any((item) => !item.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: () async {
                await ref.read(notificationProvider.notifier).markAllAsRead();
                ref.invalidate(unreadNotificationCountProvider);
              },
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: notifications.when(
        loading: () => const _NotificationSkeletonList(),
        error: (error, _) => _NotificationError(
          message: 'Check your connection and try again.',
          onRetry: () =>
              ref.read(notificationProvider.notifier).loadNotifications(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationProvider.notifier).loadNotifications(),
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.notifications_none, size: 64),
                  SizedBox(height: 12),
                  Center(child: Text('No notifications yet')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationProvider.notifier).loadNotifications(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return _NotificationTile(
                  item: item,
                  onRead: () async {
                    await ref
                        .read(notificationProvider.notifier)
                        .markAsRead(item.id);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  onDelete: () async {
                    await ref
                        .read(notificationProvider.notifier)
                        .deleteNotification(item.id);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.item,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _notificationColor(item.type);
    return Card(
      margin: EdgeInsets.zero,
      color: item.isRead
          ? Theme.of(context).cardColor
          : AppTheme.primaryColor.withValues(alpha: 0.08),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(_notificationIcon(item.type), color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                ),
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${item.message}\n${_formatTime(item.createdAt)}'),
        ),
        isThreeLine: true,
        onTap: item.isRead ? null : onRead,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'read') onRead();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            if (!item.isRead)
              const PopupMenuItem(
                value: 'read',
                child: Text('Mark as read'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'bet_result':
        return Icons.receipt_long;
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdrawal':
        return Icons.account_balance_wallet_outlined;
      case 'odds_alert':
        return Icons.trending_up;
      case 'promotion':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _notificationColor(String type) {
    switch (type) {
      case 'bet_result':
        return AppTheme.successColor;
      case 'deposit':
        return AppTheme.primaryColor;
      case 'withdrawal':
        return AppTheme.warningColor;
      case 'odds_alert':
        return AppTheme.accentColor;
      case 'promotion':
        return Colors.purpleAccent;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTime(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.day}/${value.month}/${value.year}';
  }
}

class _NotificationSkeletonList extends StatelessWidget {
  const _NotificationSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 180,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load notifications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

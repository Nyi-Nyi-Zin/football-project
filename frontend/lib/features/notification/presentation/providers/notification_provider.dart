import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../domain/entities/notification_entity.dart';

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>(
  (ref) => NotificationRemoteDataSource(ref.read(dioClientProvider)),
);

final notificationProvider = StateNotifierProvider<NotificationNotifier,
    AsyncValue<List<NotificationItem>>>((ref) {
  return NotificationNotifier(ref.read(notificationDataSourceProvider));
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationDataSourceProvider).getUnreadCount();
});

class NotificationNotifier
    extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  final NotificationRemoteDataSource _dataSource;

  NotificationNotifier(this._dataSource) : super(const AsyncLoading()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = const AsyncLoading();
    try {
      final models = await _dataSource.getNotifications();
      state = AsyncData(models.map((model) => model.toEntity()).toList());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dataSource.markAsRead(id);
      final current = state.valueOrNull ?? const [];
      state = AsyncData([
        for (final item in current)
          item.id == id ? item.copyWith(isRead: true) : item,
      ]);
    } catch (_) {
      // Keep the current list when a non-critical read update fails.
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dataSource.markAllAsRead();
      final current = state.valueOrNull ?? const [];
      state = AsyncData([
        for (final item in current) item.copyWith(isRead: true),
      ]);
    } catch (_) {
      // Keep the current list when a non-critical read update fails.
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _dataSource.deleteNotification(id);
      final current = state.valueOrNull ?? const [];
      state = AsyncData(current.where((item) => item.id != id).toList());
    } catch (_) {
      // Keep the notification visible when the delete request fails.
    }
  }
}

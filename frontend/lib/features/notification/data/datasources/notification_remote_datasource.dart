import '../../../../core/network/dio_client.dart';
import '../models/notification_model.dart';

class NotificationRemoteDataSource {
  final DioClient _client;

  NotificationRemoteDataSource(this._client);

  Future<List<NotificationModel>> getNotifications({
    bool unreadOnly = false,
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.dio.get(
      '/notifications',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (unreadOnly) 'unread': true,
      },
    );
    final data = response.data['data'] as List? ?? const [];
    return data
        .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _client.dio.get('/notifications/unread-count');
    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _client.dio.patch('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _client.dio.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _client.dio.delete('/notifications/$id');
  }
}

import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? 'Notification',
      message: json['message'] as String? ?? '',
      data: json['data'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  NotificationItem toEntity() {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead,
      createdAt: createdAt,
    );
  }
}

import 'package:equatable/equatable.dart';

class NotificationItem extends Equatable {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      data: data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, title, message, data, isRead, createdAt];
}

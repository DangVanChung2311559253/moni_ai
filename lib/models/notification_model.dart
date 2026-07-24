import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String priority;
  final String? referenceId;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.priority,
    this.referenceId,
  });

  factory NotificationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['created_at'];
    final createdAt = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();
    return NotificationModel(
      id: id,
      userId: (data['user_id'] ?? '').toString(),
      type: (data['type'] ?? 'reminder').toString(),
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      createdAt: createdAt,
      isRead: data['is_read'] == true,
      priority: (data['priority'] ?? 'medium').toString(),
      referenceId: data['reference_id']?.toString(),
    );
  }
}

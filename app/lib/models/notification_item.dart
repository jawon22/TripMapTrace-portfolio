import 'package:flutter/material.dart';

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final int? targetTripId;
  final int? targetMediaId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.targetTripId,
    this.targetMediaId,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool,
      targetTripId: json['targetTripId'] as int?,
      targetMediaId: json['targetMediaId'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  IconData get icon => switch (type) {
        'UPLOAD' => Icons.photo_camera_outlined,
        'JOIN' => Icons.person_add_outlined,
        'LEAVE' => Icons.person_remove_outlined,
        'ROLE_CHANGE' => Icons.manage_accounts_outlined,
        'KICK' => Icons.remove_circle_outline,
        'TRIP_DELETED' => Icons.delete_outline,
        'LIKE' => Icons.favorite_outline,
        'COMMENT' => Icons.chat_bubble_outline,
        _ => Icons.notifications_outlined,
      };

  Color iconColor(BuildContext context) => switch (type) {
        'LIKE' => Colors.redAccent,
        'COMMENT' => Colors.blueAccent,
        'UPLOAD' => Colors.green,
        'JOIN' => Colors.teal,
        'LEAVE' || 'KICK' => Colors.orange,
        'TRIP_DELETED' => Colors.red,
        _ => Colors.grey,
      };
}

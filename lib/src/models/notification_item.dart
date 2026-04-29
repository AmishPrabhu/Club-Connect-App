import 'package:flutter/material.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isRead,
    required this.icon,
    required this.color,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final IconData icon;
  final Color color;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'system';
    return NotificationItem(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      timeAgo: _relativeTime(json['createdAt']?.toString()),
      isRead: json['read'] == true,
      icon: _iconForType(type),
      color: _colorForType(type),
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      timeAgo: timeAgo,
      isRead: isRead ?? this.isRead,
      icon: icon,
      color: color,
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'event':
        return Icons.calendar_month_rounded;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'club':
        return Icons.groups_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'event':
        return const Color(0xFF2563EB);
      case 'announcement':
        return const Color(0xFF7C3AED);
      case 'club':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF0F172A);
    }
  }

  static String _relativeTime(String? raw) {
    final createdAt = raw == null ? null : DateTime.tryParse(raw);
    if (createdAt == null) return 'Just now';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

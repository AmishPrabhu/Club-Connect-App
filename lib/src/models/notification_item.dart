import 'package:flutter/material.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.icon,
    required this.color,
    this.relatedId,
    this.clubId,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final IconData icon;
  final Color color;
  final String? relatedId;
  final String? clubId;

  /// Computed lazily so relative time stays accurate as the app stays open.
  String get timeAgo => _relativeTime(createdAt);

  /// Strips markdown characters and newlines for clean plaintext previews.
  String get plainMessage {
    return message
        .replaceAll(RegExp(r'\*\*|__|\*|_|#\s*|-\s*'), '')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trim();
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'system';
    final rawCreatedAt = json['createdAt']?.toString();
    final createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt) ?? DateTime.now())
        : DateTime.now();
    return NotificationItem(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      createdAt: createdAt,
      isRead: json['read'] == true,
      icon: _iconForType(type),
      color: _colorForType(type),
      relatedId: json['relatedId']?.toString(),
      clubId: json['clubId']?.toString(),
    );
  }

  NotificationItem copyWith({bool? isRead, String? clubId}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      icon: icon,
      color: color,
      relatedId: relatedId,
      clubId: clubId ?? this.clubId,
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
        return const Color(0xFF6366F1);
      case 'announcement':
        return const Color(0xFF7C3AED);
      case 'club':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF0F172A);
    }
  }

  static String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/notification_item.dart';
import '../widgets/glass_card.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({
    super.key,
    required this.notification,
    this.onNavigateToPost,
  });

  final NotificationItem notification;
  final void Function(String postId)? onNavigateToPost;

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt;
    final hasRelatedPost =
        notification.relatedId != null && notification.relatedId!.isNotEmpty;
    final hasLink = notification.link != null && notification.link!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: notification.color.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                notification.icon,
                                color: notification.color,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _Badge(
                                        label: notification.type.toUpperCase(),
                                        background: notification.color
                                            .withValues(alpha: 0.12),
                                        foreground: notification.color,
                                      ),
                                      _Badge(
                                        label: notification.isRead
                                            ? 'READ'
                                            : 'UNREAD',
                                        background: notification.isRead
                                            ? const Color(0xFFE8F3FF)
                                            : const Color(0xFFFFF7ED),
                                        foreground: notification.isRead
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFFB45309),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    notification.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    notification.timeAgo,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (createdAt != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _formatDate(createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          notification.message,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasRelatedPost || hasLink)
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (hasRelatedPost)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: onNavigateToPost == null
                                    ? null
                                    : () => onNavigateToPost!(
                                        notification.relatedId!,
                                      ),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: Text(
                                  notification.type == 'event'
                                      ? 'View Related Event'
                                      : 'View Related Post',
                                ),
                              ),
                            ),
                          if (hasRelatedPost && hasLink)
                            const SizedBox(height: 10),
                          if (hasLink)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(notification.link!);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.link_rounded),
                                label: const Text('Open Link'),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

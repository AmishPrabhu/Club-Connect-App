import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/glass_card.dart';
import 'announcements_screen.dart';
import 'notification_detail_screen.dart';
import 'post_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final notifications = appState.notifications;
    final unreadCount = notifications.where((item) => !item.isRead).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unreadCount unread',
                          style: const TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Announcements, reminders, and club activity updates in one inbox.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AnnouncementsScreen(appState: appState),
                          ),
                        );
                      },
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Announcements'),
                    ),
                    OutlinedButton.icon(
                      onPressed: appState.refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  if (!item.isRead) {
                    await appState.markNotificationAsRead(item.id);
                  }
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NotificationDetailScreen(
                        notification: item,
                        onNavigateToPost: (postId) {
                          final matches = appState.posts
                              .where((post) => post.id == postId)
                              .toList();
                          if (matches.isEmpty) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                appState: appState,
                                initialPost: matches.first,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                child: GlassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: item.color.withValues(alpha: 0.12),
                        child: Icon(item.icon, color: item.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (!item.isRead)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item.timeAgo,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/glass_card.dart';
import 'notification_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isMarkingAll = false;
  // 'all' | 'unread' | 'read'
  String _filter = 'all';

  Future<void> _markAllAsRead() async {
    setState(() => _isMarkingAll = true);
    try {
      await widget.appState.markAllNotificationsAsRead();
      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allNotifications = widget.appState.notifications;

    final unreadCount = allNotifications.where((n) => !n.isRead).length;

    final notifications = allNotifications.where((n) {
      if (_filter == 'unread') return !n.isRead;
      if (_filter == 'read') return n.isRead;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.appState.refreshAll,
      child: CustomScrollView(
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
                        _isMarkingAll
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : TextButton.icon(
                                onPressed: _markAllAsRead,
                                icon: const Icon(Icons.done_all_rounded, size: 16),
                                label: const Text('Mark all read'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
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
                  // ── Filter chips ───────────────────────────────────
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('all', 'All (${allNotifications.length})'),
                        _filterChip('unread', 'Unread ($unreadCount)'),
                        _filterChip('read',
                            'Read (${allNotifications.length - unreadCount})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (notifications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: AppTheme.mutedColor(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _filter == 'unread'
                          ? 'No unread notifications!'
                          : _filter == 'read'
                              ? 'No read notifications yet.'
                              : "You're all caught up!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _filter == 'all'
                          ? 'No notifications yet. Check back later.'
                          : 'Switch filters to see other notifications.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.mutedColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return GestureDetector(
                    onTap: () async {
                      if (!item.isRead) {
                        await widget.appState.markNotificationAsRead(item.id);
                      }
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationDetailScreen(
                              appState: widget.appState,
                              notification: item,
                            ),
                          ),
                        );
                      }
                    },
                    child: GlassCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.darkElevated
                                    : item.color.withValues(alpha: 0.12),
                            child: Icon(
                              item.icon,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : item.color,
                            ),
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                    if (!item.isRead)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          // Fixed: use accent color instead of
                                          // hardcoded white in dark mode
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppTheme.accent(context)
                                              : item.color,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.plainMessage,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        selected: _filter == value,
        showCheckmark: false,
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

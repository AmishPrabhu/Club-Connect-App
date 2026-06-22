import 'package:flutter/material.dart';

import '../../models/post_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../post_detail_screen.dart';

/// Student dashboard: shows the student's liked clubs, upcoming events,
/// recent announcements, and pending tasks assigned to them.
class StudentDashboardWidget extends StatefulWidget {
  const StudentDashboardWidget({super.key, required this.appState});

  final AppState appState;

  @override
  State<StudentDashboardWidget> createState() => _StudentDashboardWidgetState();
}

class _StudentDashboardWidgetState extends State<StudentDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  AppState get _appState => widget.appState;

  List<PostItem> get _upcomingEvents {
    final now = DateTime.now();
    return _appState.posts
        .where(
          (p) =>
              p.isEvent &&
              p.date != null &&
              p.date!.isAfter(now) &&
              p.status == 'published',
        )
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
  }

  List<PostItem> get _recentAnnouncements {
    return _appState.posts
        .where((p) => !p.isEvent && p.status == 'published')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<String> get _likedClubIds =>
      _appState.session?.likedClubs ?? const [];

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _eventsTab() {
    final events = _upcomingEvents;
    if (events.isEmpty) {
      return const _EmptyPane(
        icon: Icons.event_outlined,
        message: 'No upcoming events.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final daysDiff = event.date!.difference(DateTime.now()).inDays;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.blue.withValues(alpha: 0.12),
              child: const Icon(Icons.event_rounded, color: AppTheme.blue),
            ),
            title: Text(
              event.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.clubName),
                if (event.location != null && event.location!.isNotEmpty)
                  Text(
                    '📍 ${event.location}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${event.date!.day}/${event.date!.month}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  daysDiff == 0
                      ? 'Today'
                      : daysDiff == 1
                          ? 'Tomorrow'
                          : 'In $daysDiff days',
                  style: TextStyle(
                    fontSize: 11,
                    color: daysDiff <= 2 ? Colors.orange : Colors.grey,
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  appState: _appState,
                  initialPost: event,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _announcementsTab() {
    final items = _recentAnnouncements;
    if (items.isEmpty) {
      return const _EmptyPane(
        icon: Icons.campaign_outlined,
        message: 'No announcements yet.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length > 30 ? 30 : items.length,
      itemBuilder: (context, index) {
        final post = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.navy.withValues(alpha: 0.08),
              child: const Icon(Icons.campaign_outlined, color: AppTheme.navy),
            ),
            title: Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              post.clubName,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              _formatDate(post.createdAt),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  appState: _appState,
                  initialPost: post,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _myClubsTab() {
    final liked = _likedClubIds;
    final myClubs = _appState.clubs
        .where((c) =>
            liked.contains(c.id) ||
            (_appState.session?.memberships
                    .any((m) => m.clubId == c.id) ??
                false))
        .toList();

    if (myClubs.isEmpty) {
      return const _EmptyPane(
        icon: Icons.groups_outlined,
        message: 'You haven\'t joined or liked any clubs yet.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: myClubs.length,
      itemBuilder: (context, index) {
        final club = myClubs[index];
        final isLiked = liked.contains(club.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: club.resolvedImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      club.resolvedImageUrl!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const CircleAvatar(
                        child: Icon(Icons.groups_rounded),
                      ),
                    ),
                  )
                : const CircleAvatar(child: Icon(Icons.groups_rounded)),
            title: Text(
              club.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${club.category} • ${club.members} members',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isLiked
                ? const Icon(Icons.favorite_rounded, color: Colors.red, size: 20)
                : null,
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final session = _appState.session;
    final membershipCount = session?.memberships.length ?? 0;
    final likedCount = session?.likedClubs.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatChip(
                      label: 'Clubs',
                      value: '$membershipCount',
                      icon: Icons.groups_outlined,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'Liked',
                      value: '$likedCount',
                      icon: Icons.favorite_border_rounded,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'Upcoming',
                      value: '${_upcomingEvents.length}',
                      icon: Icons.event_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Announcements'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'My Clubs'),
          ],
        ),
        SizedBox(
          height: 540,
          child: TabBarView(
            controller: _tabController,
            children: [
              _eventsTab(),
              _announcementsTab(),
              _myClubsTab(),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppTheme.blue),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

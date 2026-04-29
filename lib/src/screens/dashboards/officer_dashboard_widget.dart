import 'package:flutter/material.dart';

import '../../models/club.dart';
import '../../models/post_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';

class OfficerDashboardWidget extends StatefulWidget {
  const OfficerDashboardWidget({
    super.key,
    required this.appState,
    required this.club,
  });

  final AppState appState;
  final Club club;

  @override
  State<OfficerDashboardWidget> createState() => _OfficerDashboardWidgetState();
}

class _OfficerDashboardWidgetState extends State<OfficerDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<List<Map<String, dynamic>>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _membersFuture = widget.appState.fetchClubMembers(widget.club.id);
      _tasksFuture = widget.appState.fetchClubTasks(widget.club.id);
    });
  }

  Widget _overviewTab() {
    final posts = widget.appState.posts
        .where((p) => p.clubId == widget.club.id)
        .toList();
    final events = posts.where((p) => p.isEvent).toList();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        final membersCount = snapshot.data?.length ?? 0;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _statChip('Members', '$membersCount', Icons.people_outline),
                const SizedBox(width: 8),
                _statChip('Events', '${events.length}', Icons.event),
                const SizedBox(width: 8),
                _statChip('Posts', '${posts.length}', Icons.article_outlined),
              ],
            ),
            const SizedBox(height: 24),
            Text('Quick Actions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    // Logic to show create post dialog can be passed down or handled here
                    // Since it's complex, we might just leave a placeholder or implement a basic route
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Use the FAB to create posts/events.')),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Event/Post'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _eventsTab() {
    final events = widget.appState.posts
        .where((p) => p.clubId == widget.club.id && p.isEvent)
        .toList();

    if (events.isEmpty) {
      return const Center(child: Text('No events found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final ev = events[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.event)),
            title: Text(ev.title),
            subtitle: Text(ev.date != null
                ? '${ev.date!.day}/${ev.date!.month}/${ev.date!.year}'
                : 'No date'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  appState: widget.appState,
                  initialPost: ev,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _membersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('No members found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, i) {
            final m = members[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(m['name']?.toString() ?? 'Unknown'),
                subtitle: Text('${m['role']} • ${m['email']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final id = m['_id']?.toString() ?? m['id']?.toString() ?? '';
                    await widget.appState.removeClubMember(widget.club.id, id);
                    _refresh();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _tasksTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return const Center(child: Text('No active tasks.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, i) {
            final t = tasks[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(t['title']?.toString() ?? 'Task'),
                subtitle: Text('Status: ${t['status']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    final id = t['_id']?.toString() ?? t['id']?.toString() ?? '';
                    await widget.appState.updateTask(id, {'status': 'completed'});
                    _refresh();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppTheme.blue),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text('Officer Dashboard',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Managing: ${widget.club.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Members'),
            Tab(icon: Icon(Icons.task_alt_outlined), text: 'Tasks'),
          ],
        ),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _overviewTab(),
              _eventsTab(),
              _membersTab(),
              _tasksTab(),
            ],
          ),
        ),
      ],
    );
  }
}

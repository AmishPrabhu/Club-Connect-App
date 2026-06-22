// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../../models/club.dart';
import '../../models/post_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../post_detail_screen.dart';

/// Officer dashboard shown to club-secretary, president, and treasurer roles.
/// Tabs: Announcements | Events | Tasks | Messages
class OfficerDashboardWidget extends StatefulWidget {
  const OfficerDashboardWidget({
    super.key,
    required this.appState,
    required this.club,
    required this.clubRoles,
    required this.onCreatePost,
  });

  final AppState appState;
  final Club club;
  final Set<String> clubRoles;
  final void Function(bool isEvent) onCreatePost;

  @override
  State<OfficerDashboardWidget> createState() => _OfficerDashboardWidgetState();
}

class _OfficerDashboardWidgetState extends State<OfficerDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _tasksFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _refreshTasks();
  }

  @override
  void didUpdateWidget(covariant OfficerDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.club.id != widget.club.id) {
      _refreshTasks();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshTasks() {
    setState(() {
      _tasksFuture = widget.appState.fetchClubTasks(widget.club.id);
    });
  }

  List<PostItem> get _announcements => widget.appState.posts
      .where((p) => p.clubId == widget.club.id && !p.isEvent)
      .toList();

  List<PostItem> get _events => widget.appState.posts
      .where((p) => p.clubId == widget.club.id && p.isEvent)
      .toList();

  // ── Announcements tab ──────────────────────────────────────────────────────

  Widget _announcementsTab() {
    final items = _announcements;
    return _PostList(
      items: items,
      emptyMessage: 'No announcements yet.',
      emptyIcon: Icons.campaign_outlined,
      onTap: (post) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(appState: widget.appState, initialPost: post),
        ),
      ),
      onDelete: (post) async {
        final ok = await _confirmDelete(post.title);
        if (ok) {
          await widget.appState.deletePost(post.id);
          setState(() {});
        }
      },
      fab: _CreateFab(
        label: 'New Announcement',
        icon: Icons.add_comment_outlined,
        onPressed: () => widget.onCreatePost(false),
      ),
    );
  }

  // ── Events tab ─────────────────────────────────────────────────────────────

  Widget _eventsTab() {
    final items = _events;
    final now = DateTime.now();
    return _PostList(
      items: items,
      emptyMessage: 'No events yet.',
      emptyIcon: Icons.event_outlined,
      onTap: (post) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(appState: widget.appState, initialPost: post),
        ),
      ),
      onDelete: (post) async {
        final ok = await _confirmDelete(post.title);
        if (ok) {
          await widget.appState.deletePost(post.id);
          setState(() {});
        }
      },
      leadingBuilder: (post) {
        final isUpcoming = post.date != null && post.date!.isAfter(now);
        return CircleAvatar(
          backgroundColor: (isUpcoming ? AppTheme.blue : Colors.grey)
              .withValues(alpha: 0.12),
          child: Icon(
            isUpcoming ? Icons.upcoming_rounded : Icons.history_rounded,
            color: isUpcoming ? AppTheme.blue : Colors.grey,
            size: 20,
          ),
        );
      },
      trailingBuilder: (post) => post.rsvps != null
          ? Chip(
              label: Text('${post.rsvps} RSVPs'),
              visualDensity: VisualDensity.compact,
            )
          : null,
      fab: _CreateFab(
        label: 'New Event',
        icon: Icons.add_circle_outline,
        onPressed: () => widget.onCreatePost(true),
      ),
    );
  }

  // ── Tasks tab ──────────────────────────────────────────────────────────────

  Widget _tasksTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data ?? [];
        return Stack(
          children: [
            if (tasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_outlined, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No tasks yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final taskId =
                      task['_id']?.toString() ?? task['id']?.toString() ?? '';
                  final isDone =
                      (task['status']?.toString() ?? '') == 'completed';
                  final assignees = (task['assignedTo'] as List<dynamic>? ?? [])
                      .map((e) => e.toString())
                      .join(', ');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Checkbox(
                        value: isDone,
                        onChanged: _saving
                            ? null
                            : (v) async {
                                setState(() => _saving = true);
                                await widget.appState.updateTask(taskId, {
                                  'status': v == true ? 'completed' : 'pending',
                                });
                                _refreshTasks();
                                setState(() => _saving = false);
                              },
                      ),
                      title: Text(
                        task['title']?.toString() ?? 'Task',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((task['description']?.toString() ?? '').isNotEmpty)
                            Text(task['description'].toString()),
                          if (assignees.isNotEmpty)
                            Text(
                              'Assigned to: $assignees',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          if ((task['deadline']?.toString() ?? '').isNotEmpty)
                            Text(
                              'Due: ${task['deadline']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final ok = await _confirmDelete(
                              task['title']?.toString() ?? 'Task');
                          if (ok) {
                            await widget.appState.deleteTask(taskId);
                            _refreshTasks();
                          }
                        },
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  // ── Messages tab ───────────────────────────────────────────────────────────

  Widget _messagesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.appState.fetchClubMessages(widget.club.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data ?? [];
        return Stack(
          children: [
            if (messages.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_outlined, size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No messages yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.message_outlined),
                      ),
                      title: Text(
                        msg['title']?.toString() ?? 'Message',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(msg['body']?.toString() ?? ''),
                    ),
                  );
                },
              ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'msg_fab',
                onPressed: _showSendMessageDialog,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send Message'),
                backgroundColor: AppTheme.navy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSendMessageDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Club Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message body'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.appState.sendClubMessage(
                clubId: widget.club.id,
                title: titleCtrl.text.trim(),
                body: bodyCtrl.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                setState(() {});
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Remove "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clubStats = widget.appState.posts
        .where((p) => p.clubId == widget.club.id)
        .length;

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
                  widget.club.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.clubRoles.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: widget.clubRoles
                        .map((role) => _RoleChip(role: role))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                      label: 'Members',
                      value: '${widget.club.members}',
                      icon: Icons.group_outlined,
                    ),
                    const SizedBox(width: 12),
                    _MiniStat(
                      label: 'Posts',
                      value: '$clubStats',
                      icon: Icons.article_outlined,
                    ),
                    const SizedBox(width: 12),
                    _MiniStat(
                      label: 'Events',
                      value: '${widget.club.upcomingEvents}',
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
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
            Tab(icon: Icon(Icons.task_outlined), text: 'Tasks'),
            Tab(icon: Icon(Icons.chat_outlined), text: 'Messages'),
          ],
        ),
        SizedBox(
          height: 560,
          child: TabBarView(
            controller: _tabController,
            children: [
              _announcementsTab(),
              _eventsTab(),
              _tasksTab(),
              _messagesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.blue,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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

class _CreateFab extends StatelessWidget {
  const _CreateFab({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.extended(
        heroTag: label,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.items,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onTap,
    required this.onDelete,
    required this.fab,
    this.leadingBuilder,
    this.trailingBuilder,
  });

  final List<PostItem> items;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(PostItem) onTap;
  final Future<void> Function(PostItem) onDelete;
  final Widget fab;
  final Widget Function(PostItem)? leadingBuilder;
  final Widget? Function(PostItem)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (items.isEmpty)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(emptyIcon, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  emptyMessage,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final post = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: leadingBuilder?.call(post) ??
                      const CircleAvatar(
                        child: Icon(Icons.article_outlined),
                      ),
                  title: Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    post.content.length > 80
                        ? '${post.content.substring(0, 80)}…'
                        : post.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: trailingBuilder?.call(post) ??
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => onDelete(post),
                      ),
                  onTap: () => onTap(post),
                ),
              );
            },
          ),
        fab,
      ],
    );
  }
}

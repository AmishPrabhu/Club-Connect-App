import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/club.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/cloudinary_service.dart';
import '../post_detail_screen.dart';

class OfficerDashboardWidget extends StatefulWidget {
  const OfficerDashboardWidget({
    super.key,
    required this.appState,
    required this.club,
    required this.clubRoles,
    this.onCreatePost,
  });

  final AppState appState;
  final Club club;
  final Set<String> clubRoles;
  final ValueChanged<bool>? onCreatePost;

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

  bool get _canManageMembers =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.clubRoles.contains('club-secretary') ||
      widget.clubRoles.contains('president');

  bool get _canPublish =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.clubRoles.contains('club-secretary') ||
      widget.clubRoles.contains('president');

  bool get _canUploadBudget =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.clubRoles.contains('treasurer');

  bool get _canAccessPresidentChannel =>
      widget.appState.session?.hasAdminAccess == true ||
      widget.clubRoles.contains('president');

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
            Text(
              'Club Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (_canPublish)
                  FilledButton.icon(
                    onPressed: widget.onCreatePost == null
                        ? null
                        : () => widget.onCreatePost!(false),
                    icon: const Icon(Icons.post_add_rounded),
                    label: const Text('Create Announcement'),
                  ),
                if (_canPublish)
                  FilledButton.tonalIcon(
                    onPressed: widget.onCreatePost == null
                        ? null
                        : () => widget.onCreatePost!(true),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Create Event'),
                  ),
                if (_canUploadBudget)
                  FilledButton.tonalIcon(
                    onPressed: _showBudgetUploadDialog,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Treasurer Budget Upload'),
                  ),
                if (_canAccessPresidentChannel)
                  OutlinedButton.icon(
                    onPressed: _showPresidentChannelDialog,
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Presidents Channel'),
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
            subtitle: Text(
              ev.date != null
                  ? '${ev.date!.day}/${ev.date!.month}/${ev.date!.year}'
                  : 'No date',
            ),
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
                trailing: _canManageMembers
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () async {
                          final id =
                              m['_id']?.toString() ?? m['id']?.toString() ?? '';
                          await widget.appState.removeClubMember(
                            widget.club.id,
                            id,
                          );
                          _refresh();
                        },
                      )
                    : null,
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
                    final id =
                        t['_id']?.toString() ?? t['id']?.toString() ?? '';
                    await widget.appState.updateTask(id, {
                      'status': 'completed',
                    });
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

  Future<void> _showBudgetUploadDialog() async {
    final events = widget.appState.posts
        .where((p) => p.clubId == widget.club.id && p.isEvent)
        .toList();
    if (events.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No events found for this club.')),
        );
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Budget'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(event.title),
                subtitle: Text(event.date != null
                    ? '${event.date!.day}/${event.date!.month}/${event.date!.year}'
                    : 'No date set'),
                trailing: const Icon(Icons.upload_file),
                onTap: () async {
                  final picked = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked == null) return;
                  final url = await CloudinaryService.uploadImage(
                    File(picked.path),
                  );
                  if (url != null) {
                    await widget.appState.updatePost(event.id, {
                      'budgetImageUrl': url,
                    });
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    _refresh();
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPresidentChannelDialog() async {
    const channelId = 'GLOBAL_PRESIDENTS';
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Global Presidents Channel'),
          content: SizedBox(
            width: double.maxFinite,
            height: 520,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.appState.fetchClubMessages(channelId),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <Map<String, dynamic>>[];
                return Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: messages.isEmpty
                          ? const Center(child: Text('No messages yet.'))
                          : ListView.separated(
                              itemCount: messages.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    msg['title']?.toString() ?? 'Message',
                                  ),
                                  subtitle: Text(
                                    msg['body']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    bodyController.text.trim().isEmpty) {
                  return;
                }
                await widget.appState.createClubMessage(
                  channelId,
                  title: titleController.text.trim(),
                  body: bodyController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent.')),
                  );
                }
              },
              child: const Text('Send'),
            ),
          ],
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
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
          child: Text(
            'Club Roles Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.clubRoles.map((role) {
              return Chip(
                visualDensity: VisualDensity.compact,
                label: Text(_displayRole(role)),
              );
            }).toList(),
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

  String _displayRole(String role) {
    switch (role) {
      case 'club-secretary':
        return 'Secretary';
      case 'president':
        return 'President';
      case 'treasurer':
        return 'Treasurer';
      case 'advisor':
        return 'Advisor';
      default:
        return role;
    }
  }
}

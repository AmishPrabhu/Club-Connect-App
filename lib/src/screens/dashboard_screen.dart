import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

import '../models/club.dart';
import '../models/post_item.dart';
import '../models/user_session.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'bulk_import_screen.dart';
import 'club_detail_screen.dart';
 import 'dashboards/officer_dashboard_widget.dart';
import 'dashboards/student_dashboard_widget.dart';

import 'post_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<Map<String, dynamic>>>? _tasksFuture;
  Future<List<Map<String, dynamic>>>? _teachersFuture;

  @override
  void initState() {
    super.initState();
    _reloadRoleData();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session!;
    final managedClub = _resolveManagedClub(session);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${session.name}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This dashboard is backed by your live Club Connect API.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  if (widget.appState.error != null)
                    Text(
                      widget.appState.error!,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                ],
              ),
            ),
          ),
          if (session.role == 'admin')
            ..._adminSlivers()
          else if (session.role == 'advisor')
            ..._advisorSlivers(managedClub)
          else if (session.role == 'club-secretary' ||
              session.role == 'president' ||
              session.role == 'treasurer')
            ..._officerSlivers(managedClub)
          else if (session.role == 'teacher')
            ..._teacherSlivers()
          else
            ..._studentSlivers(),
        ],
      ),
    );
  }

  List<Widget> _adminSlivers() {
    final appState = widget.appState;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.15,
          ),
          delegate: SliverChildListDelegate([
            _StatBox(
              title: 'Clubs',
              value: '${appState.clubs.length}',
              icon: Icons.groups_rounded,
            ),
            _StatBox(
              title: 'Posts',
              value: '${appState.posts.length}',
              icon: Icons.article_outlined,
            ),
            _StatBox(
              title: 'Alerts',
              value: '${appState.notifications.length}',
              icon: Icons.notifications_active_outlined,
            ),
            _ActionBox(
              title: 'Broadcast',
              subtitle: 'Send a campus-wide notification',
              icon: Icons.campaign_outlined,
              onTap: _showNotificationDialog,
            ),
            _ActionBox(
              title: 'Create Club',
              subtitle: 'Add a new club to the platform',
              icon: Icons.add_business_outlined,
              onTap: _showCreateClubDialog,
            ),
            _ActionBox(
              title: 'Assign Teacher',
              subtitle: 'Invite or promote a teacher account',
              icon: Icons.person_add_alt_1_rounded,
              onTap: _showAssignTeacherDialog,
            ),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            children: [
              _SectionCard(
                title: 'Teachers',
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _teachersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final teachers =
                        snapshot.data ?? const <Map<String, dynamic>>[];
                    if (teachers.isEmpty) {
                      return const _EmptyState(
                        message: 'No teacher accounts found.',
                      );
                    }
                    return Column(
                      children: teachers.take(6).map((teacher) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.school_outlined),
                          ),
                          title: Text(teacher['name']?.toString() ?? 'Teacher'),
                          subtitle: Text(teacher['email']?.toString() ?? ''),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'All Clubs',
                child: Column(
                  children: appState.clubs.take(8).map((club) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_rounded),
                      ),
                      title: Text(club.name),
                      subtitle: Text('${club.members} members'),
                      trailing: IconButton(
                        onPressed: () => _showAssignOfficerDialog(club),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        tooltip: 'Assign officer',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ClubDetailScreen(appState: appState, club: club),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _advisorSlivers(Club? club) {
    if (club == null) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('No Club Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('You are not assigned as advisor to any club.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: _AdvisorDashboardWidget(appState: widget.appState, club: club),
      ),
    ];
  }

  List<Widget> _officerSlivers(Club? managedClub) {
    if (managedClub == null) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('You are not assigned to manage any club.'),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: OfficerDashboardWidget(
          appState: widget.appState,
          club: managedClub,
        ),
      ),
    ];
  }

  List<Widget> _studentSlivers() {
    return [
      SliverToBoxAdapter(
        child: StudentDashboardWidget(appState: widget.appState),
      ),
    ];
  }

  Club? _resolveManagedClub(UserSession session) {
    final clubs = widget.appState.clubs;
    final byId = clubs.where((club) => club.id == session.clubId).toList();
    if (byId.isNotEmpty) return byId.first;
    final byName = clubs
        .where((club) => club.name == session.clubName)
        .toList();
    if (byName.isNotEmpty) return byName.first;
    return null;
  }

  void _reloadRoleData() {
    final session = widget.appState.session;
    if (session == null) return;
    if (session.role == 'admin') {
      _teachersFuture = widget.appState.fetchTeachers();
    }
    if (session.clubId != null) {
      _tasksFuture = widget.appState.fetchClubTasks(session.clubId!);
    }
    setState(() {});
  }

  Future<void> _showNotificationDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String type = widget.appState.session?.role == 'admin' ? 'system' : 'club';
    final managedClub = _resolveManagedClub(widget.appState.session!);

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Notification'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text('System'),
                        ),
                        DropdownMenuItem(value: 'club', child: Text('Club')),
                        DropdownMenuItem(
                          value: 'announcement',
                          child: Text('Announcement'),
                        ),
                        DropdownMenuItem(value: 'event', child: Text('Event')),
                      ],
                      onChanged: (value) =>
                          setStateDialog(() => type = value ?? 'system'),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.appState.createNotification(
                  title: titleController.text.trim(),
                  message: messageController.text.trim(),
                  type: type,
                  clubId: type == 'club' ? managedClub?.id : null,
                );
                navigator.pop();
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreatePostDialog(Club club, {required bool isEvent}) async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    String? coverImageUrl;
    bool isUploading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: Text(isEvent ? 'Create Event' : 'Create Announcement'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    if (isEvent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: 'Date (YYYY-MM-DD)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeController,
                        decoration: const InputDecoration(labelText: 'Time'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(labelText: 'Location'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (coverImageUrl != null)
                      Container(
                        height: 100,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(coverImageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.image),
                        label: Text(isUploading ? 'Uploading...' : 'Upload Cover Image'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateDialog(() => isUploading = true);
                                  final url = await CloudinaryService.uploadImage(File(picked.path));
                                  setStateDialog(() {
                                    coverImageUrl = url;
                                    isUploading = false;
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
             FilledButton(
               onPressed: () async {
                 if (isEvent) {
                   final collisions = await widget.appState.checkEventCollision(
                     dateController.text.trim(),
                     timeController.text.trim(),
                   );
                   if (collisions.isNotEmpty) {
                     final proceed = await showDialog<bool>(
                       context: context,
                       builder: (ctx) => AlertDialog(
                         title: const Text('Schedule Conflict'),
                         content: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Text('The following events are already scheduled at this time:'),
                             const SizedBox(height: 12),
                             ...collisions.map((c) => ListTile(
                               title: Text(c['title'] ?? ''),
                               subtitle: Text(c['clubName'] ?? ''),
                               contentPadding: EdgeInsets.zero,
                             )),
                             const SizedBox(height: 12),
                             const Text('Do you want to proceed anyway?'),
                           ],
                         ),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                           FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
                         ],
                       ),
                     );
                     if (proceed != true) return;
                   }
                 }

                 await widget.appState.createPost(
                   clubId: club.id,
                   clubName: club.name,
                   title: titleController.text.trim(),
                   content: contentController.text.trim(),
                   type: isEvent ? 'event' : 'announcement',
                   status: 'published',
                   date: isEvent ? dateController.text.trim() : null,
                   time: isEvent ? timeController.text.trim() : null,
                   location: isEvent ? locationController.text.trim() : null,
                   coverImage: coverImageUrl,
                 );
                 _reloadRoleData();
                 navigator.pop();
               },
               child: const Text('Create'),
             ),
          ],
        );
      },
    );
  }

  List<Widget> _teacherSlivers() {
    final appState = widget.appState;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Teacher Dashboard',
                      style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    onPressed: _showAddTeacherClubDialog,
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppTheme.blue),
                    tooltip: 'Add Club',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: appState.fetchTeacherClubs(),
                builder: (context, snapshot) {
                  final clubs = snapshot.data ?? [];
                  if (clubs.isEmpty &&
                      snapshot.connectionState == ConnectionState.done) {
                    return const _EmptyState(
                        message: 'No clubs added to your monitor list.');
                  }
                  return Column(
                    children: clubs.map((club) {
                      final clubId =
                          club['_id']?.toString() ?? club['id']?.toString() ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const CircleAvatar(child: Icon(Icons.groups_rounded)),
                        title: Text(club['name']?.toString() ?? 'Club'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: Colors.red),
                          onPressed: () async {
                            await appState.removeTeacherClub(clubId);
                            setState(() {}); // Refresh
                          },
                        ),
                        onTap: () {
                          // Show reports for this club
                          _showTeacherReportsDialog(
                              clubId, club['name']?.toString() ?? 'Club');
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  void _showAddTeacherClubDialog() {
    final appState = widget.appState;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Club to Monitor'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: appState.clubs.length,
            itemBuilder: (context, index) {
              final club = appState.clubs[index];
              return ListTile(
                title: Text(club.name),
                trailing: const Icon(Icons.add),
                onTap: () async {
                  await appState.addTeacherClub(club.id);
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showTeacherReportsDialog(String clubId, String clubName) {
    final appState = widget.appState;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$clubName Reports'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: appState.fetchTeacherReports(),
          builder: (context, snapshot) {
            final allReports = snapshot.data ?? [];
            final clubReports =
                allReports.where((r) => r['clubId'] == clubId).toList();
            if (clubReports.isEmpty) {
              return const Text('No reports found for this club.');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: clubReports.length,
                itemBuilder: (context, index) {
                  final report = clubReports[index];
                  return ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    title:
                        Text(report['eventTitle']?.toString() ?? 'Untitled Report'),
                    subtitle: Text(
                        'Submitted on ${DateTime.parse(report['reportSubmittedAt']).toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.download),
                    onTap: () {
                      final url = report['reportUrl']?.toString() ?? '';
                      if (url.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening report: $url')),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showCreateTaskDialog(Club club, List<PostItem> posts) async {
    final members = await widget.appState.fetchClubMembers(club.id);
    if (!mounted) return;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final deadlineController = TextEditingController();
    final selectedNames = <String>{};
    String relatedEventId = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Task'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deadlineController,
                      decoration: const InputDecoration(
                        labelText: 'Deadline (YYYY-MM-DD)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('No Related Event'),
                        ),
                        ...posts
                            .where((post) => post.isEvent)
                            .map(
                              (post) => DropdownMenuItem(
                                value: post.id,
                                child: Text(post.title),
                              ),
                            ),
                      ],
                      onChanged: (value) =>
                          setStateDialog(() => relatedEventId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    ...members.map((member) {
                      final name = member['name']?.toString() ?? 'Member';
                      return CheckboxListTile(
                        value: selectedNames.contains(name),
                        title: Text(name),
                        subtitle: Text(member['role']?.toString() ?? ''),
                        onChanged: (checked) {
                          setStateDialog(() {
                            if (checked == true) {
                              selectedNames.add(name);
                            } else {
                              selectedNames.remove(name);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final chosenMembers = members.where(
                  (member) =>
                      selectedNames.contains(member['name']?.toString() ?? ''),
                );
                await widget.appState.createTask(
                  clubId: club.id,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  assignedTo: chosenMembers
                      .map((member) => member['name'].toString())
                      .toList(),
                  assignedToEmails: chosenMembers
                      .map((member) => member['email'].toString())
                      .toList(),
                  deadline: deadlineController.text.trim(),
                  relatedEventId: relatedEventId.isNotEmpty ? relatedEventId : null,
                  relatedEventTitle: posts
                      .where((p) => p.id == relatedEventId)
                      .firstOrNull
                      ?.title,
                );

                _reloadRoleData();
                navigator.pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateClubDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final fullFormController = TextEditingController();
    String category = 'technical';
    final selectedDepartments = <String>{};
    String? uploadedImageUrl;
    bool isUploading = false;
    const departments = [
      'Computer Science(CSE)',
      'Electronics',
      'Mechanical',
      'Civil',
      'Artificial Intelligence and Machine Learning(AIML)',
      'Information Technology(IT)',
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Create Club'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Club Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fullFormController,
                      decoration: const InputDecoration(labelText: 'Full Form'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (uploadedImageUrl != null)
                      Container(
                        height: 80,
                        width: 80,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: NetworkImage(uploadedImageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate),
                        label: Text(isUploading ? 'Uploading...' : 'Upload Club Logo'),
                        onPressed: isUploading
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(source: ImageSource.gallery);
                                if (picked != null) {
                                  setStateDialog(() => isUploading = true);
                                  final url = await CloudinaryService.uploadImage(File(picked.path));
                                  setStateDialog(() {
                                    uploadedImageUrl = url;
                                    isUploading = false;
                                  });
                                }
                              },
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(
                          value: 'technical',
                          child: Text('Technical'),
                        ),
                        DropdownMenuItem(
                          value: 'academic',
                          child: Text('Academic'),
                        ),
                        DropdownMenuItem(
                          value: 'cultural',
                          child: Text('Cultural'),
                        ),
                        DropdownMenuItem(
                          value: 'sports',
                          child: Text('Sports'),
                        ),
                      ],
                      onChanged: (value) =>
                          setStateDialog(() => category = value ?? 'technical'),
                    ),
                    const SizedBox(height: 12),
                    ...departments.map((department) {
                      return CheckboxListTile(
                        value: selectedDepartments.contains(department),
                        title: Text(department),
                        onChanged: (checked) {
                          setStateDialog(() {
                            if (checked == true) {
                              selectedDepartments.add(department);
                            } else {
                              selectedDepartments.remove(department);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.appState.createClub(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  fullForm: fullFormController.text.trim(),
                  category: category,
                  image: uploadedImageUrl ?? '',
                  departments: selectedDepartments.toList(),
                );
                navigator.pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAssignTeacherDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Assign Teacher'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Teacher Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Teacher Email'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.appState.assignTeacher(
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                );
                _reloadRoleData();
                navigator.pop();
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAssignOfficerDialog(Club club) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    String role = 'club-secretary';

    await showDialog<void>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: Text('Assign Officer for ${club.name}'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Officer Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Officer Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    items: const [
                      DropdownMenuItem(
                        value: 'club-secretary',
                        child: Text('Secretary'),
                      ),
                      DropdownMenuItem(
                        value: 'president',
                        child: Text('President'),
                      ),
                      DropdownMenuItem(
                        value: 'treasurer',
                        child: Text('Treasurer'),
                      ),
                      DropdownMenuItem(
                        value: 'advisor',
                        child: Text('Advisor'),
                      ),
                    ],
                    onChanged: (value) =>
                        setStateDialog(() => role = value ?? 'club-secretary'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await widget.appState.assignOfficer(
                  clubId: club.id,
                  name: nameController.text.trim(),
                  email: emailController.text.trim(),
                  role: role,
                );
                _reloadRoleData();
                navigator.pop();
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 16),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ActionBox extends StatelessWidget {
  const _ActionBox({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});


  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

// ─── Advisor Dashboard Widget ─────────────────────────────────────────────────
// Mirrors AdvisorDashboard.tsx: tabs = Events | Reports | Budgets | Team
class _AdvisorDashboardWidget extends StatefulWidget {
  const _AdvisorDashboardWidget({required this.appState, required this.club});
  final AppState appState;
  final Club club;

  @override
  State<_AdvisorDashboardWidget> createState() => _AdvisorDashboardWidgetState();
}

class _AdvisorDashboardWidgetState extends State<_AdvisorDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<List<Map<String, dynamic>>> _reportsFuture;
  bool _saving = false;

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
      _reportsFuture = widget.appState.fetchTeacherReports().then(
        (all) => all.where((r) => r['clubId'] == widget.club.id).toList(),
      );
    });
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: AppTheme.blue),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }

  Widget _eventsTab() {
    final posts = widget.appState.posts
        .where((p) => p.clubId == widget.club.id && p.isEvent)
        .toList();
    final now = DateTime.now();
    final upcoming = posts.where((p) => p.date != null && p.date!.isAfter(now)).length;
    final past = posts.where((p) => p.date != null && !p.date!.isAfter(now)).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        _statChip('Total', '${posts.length}', Icons.calendar_today),
        const SizedBox(width: 8),
        _statChip('Upcoming', '$upcoming', Icons.upcoming_rounded),
        const SizedBox(width: 8),
        _statChip('Past', '$past', Icons.history_rounded),
      ]),
      const SizedBox(height: 16),
      if (posts.isEmpty)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No events found.')))
      else
        ...posts.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.event_rounded)),
                title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(e.date != null
                    ? '${e.date!.day}/${e.date!.month}/${e.date!.year}'
                    : 'No date set'),
                trailing: e.rsvps != null ? Chip(label: Text('${e.rsvps} RSVPs')) : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PostDetailScreen(appState: widget.appState, initialPost: e),
                )),
              ),
            )),
    ]);
  }

  Widget _reportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final reports = snap.data ?? [];
        if (reports.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No reports available.')));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (ctx, i) {
            final r = reports[i];
            final ts = DateTime.tryParse(r['reportSubmittedAt']?.toString() ?? '');
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0x1A4CAF50), child: Icon(Icons.picture_as_pdf, color: Colors.green)),
                title: Text(r['eventTitle']?.toString() ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('By ${r['reportSubmittedByName'] ?? 'Unknown'}${ts != null ? " · ${ts.toLocal().toString().split(' ')[0]}" : ""}'),
                trailing: const Icon(Icons.download_rounded, color: Colors.green),
                onTap: () async {
                  final url = r['reportUrl']?.toString() ?? '';
                  if (url.isNotEmpty) {
                    try {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch URL: $url')));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No URL attached to this report.')));
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _budgetsTab() {
    final events = widget.appState.posts
        .where((p) => p.clubId == widget.club.id && p.isEvent && (p.budgetImageUrl?.isNotEmpty ?? false))
        .toList();
    if (events.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No budgets submitted yet.')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (ctx, i) {
        final ev = events[i];
        final verified = ev.budgetVerified ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: (verified ? Colors.green : Colors.blue).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(verified ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded, size: 14, color: verified ? Colors.green : Colors.blue),
                  const SizedBox(width: 4),
                  Text(verified ? 'Verified' : 'Awaiting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: verified ? Colors.green : Colors.blue)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final url = ev.budgetImageUrl ?? '';
                  if (url.isNotEmpty) {
                    try {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch URL: $url')));
                    }
                  }
                },
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const Text('View Budget'),
              ),
              if (!verified) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _saving ? null : () async {
                    setState(() => _saving = true);
                    final ok = await widget.appState.verifyEventBudget(ev.id);
                    setState(() => _saving = false);
                    if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget verified!')));
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: _saving ? const Text('Saving...') : const Text('Verify'),
                ),
              ],
            ]),
          ])),
        );
      },
    );
  }

  Widget _teamTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final members = snap.data ?? [];

        Widget section(String label, String roleKey) {
          final officers = members.where((m) => m['role']?.toString().toLowerCase().trim() == roleKey.toLowerCase()).toList();
          return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(
                onPressed: () => _showAssignRoleDialog(label: label, roleKey: roleKey),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Add New'),
              ),
            ]),
            if (officers.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('No $label assigned.', style: const TextStyle(color: Colors.grey, fontSize: 13)))
            else
              ...officers.map((o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text((o['name']?.toString() ?? 'U')[0])),
                    title: Text(o['name']?.toString() ?? 'Unknown'),
                    subtitle: Text(o['email']?.toString() ?? ''),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showAssignRoleDialog(label: label, roleKey: roleKey)),
                      IconButton(
                        icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
                        onPressed: () async {
                          final id = o['_id']?.toString() ?? o['id']?.toString() ?? '';
                          await widget.appState.removeClubMember(widget.club.id, id);
                          _refresh();
                        },
                      ),
                    ]),
                  )),
          ])));
        }

        return ListView(padding: const EdgeInsets.all(16), children: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BulkImportScreen(
                    club: widget.club,
                    appState: widget.appState,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Bulk Import Members (CSV/Excel)'),
          ),
          const SizedBox(height: 16),
          section('Secretaries', 'secretary'),
          section('Presidents', 'president'),
          section('Treasurers', 'treasurer'),
        ]);
      },
    );
  }

  void _showAssignRoleDialog({required String label, required String roleKey}) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $label'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              await widget.appState.assignOfficer(
                clubId: widget.club.id,
                email: emailCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                role: roleKey == 'secretary' ? 'club-secretary' : roleKey,
              );
              if (ctx.mounted) { Navigator.of(ctx).pop(); _refresh(); }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Text('Advisor Dashboard', style: Theme.of(context).textTheme.headlineSmall),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text('Managing: ${widget.club.name}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.blue, fontWeight: FontWeight.w600)),
      ),
      TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Events'),
          Tab(icon: Icon(Icons.file_copy_outlined), text: 'Reports'),
          Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Budgets'),
          Tab(icon: Icon(Icons.groups_outlined), text: 'Team'),
        ],
      ),
      SizedBox(
        height: 580,
        child: TabBarView(
          controller: _tabController,
          children: [_eventsTab(), _reportsTab(), _budgetsTab(), _teamTab()],
        ),
      ),
    ]);
  }
}

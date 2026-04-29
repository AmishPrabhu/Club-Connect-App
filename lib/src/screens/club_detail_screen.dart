import 'package:flutter/material.dart';

import '../models/club.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'member_board_detail_screen.dart';
import 'post_detail_screen.dart';

class ClubDetailScreen extends StatefulWidget {
  const ClubDetailScreen({
    super.key,
    required this.appState,
    required this.club,
  });

  final AppState appState;
  final Club club;

  @override
  State<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends State<ClubDetailScreen> {
  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _refreshMembers();
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = widget.appState.fetchClubMembers(widget.club.id);
    });
  }

  void _showMemberDialog({Map<String, dynamic>? member}) {
    final isEditing = member != null;
    final nameController = TextEditingController(text: member?['name']?.toString() ?? '');
    final emailController = TextEditingController(text: member?['email']?.toString() ?? '');
    final roleController = TextEditingController(text: member?['role']?.toString() ?? 'Member');
    String boardType = member?['boardType']?.toString() ?? 'member';
    String academicYear = member?['academicYear']?.toString() ?? 'FY';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Member' : 'Add New Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email (@walchandsangli.ac.in)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: boardType,
                  decoration: const InputDecoration(labelText: 'Board Type'),
                  items: const [
                    DropdownMenuItem(value: 'main', child: Text('Main Board (TY)')),
                    DropdownMenuItem(value: 'executive', child: Text('Executive Board (SY)')),
                    DropdownMenuItem(value: 'member', child: Text('Member Board (FY)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        boardType = val;
                        if (val == 'member') roleController.text = 'Member';
                      });
                    }
                  },
                ),
                if (boardType != 'member')
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(labelText: 'Custom Role'),
                  ),
                DropdownButtonFormField<String>(
                  value: academicYear,
                  decoration: const InputDecoration(labelText: 'Academic Year'),
                  items: const [
                    DropdownMenuItem(value: 'FY', child: Text('FY')),
                    DropdownMenuItem(value: 'SY', child: Text('SY')),
                    DropdownMenuItem(value: 'TY', child: Text('TY')),
                    DropdownMenuItem(value: 'Final Year', child: Text('Final Year')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => academicYear = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.isEmpty || emailController.text.isEmpty) return;
                
                try {
                  if (isEditing) {
                    final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                    await widget.appState.updateClubMember(widget.club.id, memberId, {
                      'name': nameController.text,
                      'email': emailController.text,
                      'role': roleController.text,
                      'boardType': boardType,
                      'academicYear': academicYear,
                    });
                  } else {
                    await widget.appState.addClubMember(
                      widget.club.id,
                      name: nameController.text,
                      email: emailController.text,
                      role: roleController.text,
                      boardType: boardType,
                      academicYear: academicYear,
                      joinedAt: DateTime.now(),
                    );
                  }
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    _refreshMembers();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.session;
    final isAdmin = session?.role == 'admin';
    final isOfficer = session?.clubId == widget.club.id &&
        (session?.role == 'president' ||
         session?.role == 'club-secretary' ||
         session?.role == 'advisor' ||
         session?.role == 'treasurer');
    final canManageMembers = isAdmin || isOfficer;

    final clubPosts = widget.appState.posts
        .where((post) => post.clubId == widget.club.id)
        .toList();

    return Scaffold(
      appBar: AppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <Map<String, dynamic>>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          gradient: LinearGradient(
                            colors: [
                              widget.club.startColor.withValues(alpha: 0.16),
                              widget.club.endColor.withValues(alpha: 0.18),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.club.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.displaySmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      widget.club.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: AppTheme.muted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: widget.club.imageAsset.startsWith('http')
                                    ? Image.network(
                                        widget.club.imageAsset,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.asset(
                                        widget.club.imageAsset,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              title: 'Members',
                              value: '${members.length}',
                              icon: Icons.groups_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Metric(
                              title: 'Category',
                              value: widget.club.category,
                              icon: Icons.hub_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Metric(
                              title: 'Posts',
                              value: '${clubPosts.length}',
                              icon: Icons.event_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Member Board',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (canManageMembers)
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Exporting members to CSV...')),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, color: AppTheme.blue),
                                  tooltip: 'Export Members',
                                ),
                                IconButton(
                                  onPressed: () => _showMemberDialog(),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.blue),
                                  tooltip: 'Add Member',
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (members.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No members found. Add some!'),
                          ),
                        )
                      else
                        GlassCard(
                          child: Column(
                            children: members.map((member) {
                              final memberId = member['_id']?.toString() ?? member['id']?.toString() ?? '';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  child: Text(
                                    (member['name']?.toString() ?? 'U')[0],
                                  ),
                                ),
                                title: Text(
                                  member['name']?.toString() ?? 'Member',
                                ),
                                subtitle: Text(
                                  member['role']?.toString() ?? 'Member',
                                ),
                                trailing: canManageMembers
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => _showMemberDialog(member: member),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.person_remove, color: Colors.red, size: 20),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Remove Member'),
                                                  content: Text('Are you sure you want to remove ${member['name']}?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                                    FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await widget.appState.removeClubMember(widget.club.id, memberId);
                                                _refreshMembers();
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 22),
                      // View Full Member Board button — mirrors MemberBoardDetail.tsx
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Events & Posts',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MemberBoardDetailScreen(
                                  appState: widget.appState,
                                  club: widget.club,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.groups_outlined, size: 16),
                            label: const Text('Full Member Board'),
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
                  itemCount: clubPosts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final post = clubPosts[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            appState: widget.appState,
                            initialPost: post,
                          ),
                        ),
                      ),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              post.content,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 16,
                                  color: AppTheme.purple,
                                ),
                                const SizedBox(width: 6),
                                Text(post.time ?? 'All Day'),
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: AppTheme.purple,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(post.location ?? 'Campus'),
                                ),
                                if (canManageMembers)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Post'),
                                          content: const Text('Are you sure you want to delete this post?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                            FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await widget.appState.deletePost(post.id);
                                        _refreshMembers(); 
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (isAdmin)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Club'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Club'),
                              content: Text('Are you sure you want to permanently delete ${widget.club.name}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await widget.appState.deleteClub(widget.club.id);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blue),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

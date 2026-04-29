import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/post_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../post_detail_screen.dart';

class StudentDashboardWidget extends StatefulWidget {
  const StudentDashboardWidget({super.key, required this.appState});

  final AppState appState;

  @override
  State<StudentDashboardWidget> createState() => _StudentDashboardWidgetState();
}

class _StudentDashboardWidgetState extends State<StudentDashboardWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _myRsvpsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _myRsvpsFuture = widget.appState.fetchMyRsvps();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'My Event Registrations',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upcoming_rounded), text: 'Upcoming'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Past'),
          ],
          labelColor: AppTheme.blue,
          indicatorColor: AppTheme.blue,
        ),
        SizedBox(
          height: 600,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _myRsvpsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final rsvps = snapshot.data ?? [];
              final allPosts = widget.appState.posts;

              final userEvents = rsvps.map((rsvp) {
                final eventId = rsvp['eventId']?.toString() ?? '';
                final post = allPosts.firstWhere(
                  (p) => p.id == eventId,
                  orElse: () => PostItem(
                    id: eventId,
                    title: 'Unknown Event',
                    content: '',
                    clubId: '',
                    clubName: 'Unknown Club',
                    type: 'event',
                    attachments: [],
                  ),
                );
                return {
                  'post': post,
                  'rsvp': rsvp,
                  'isPast': post.date != null && post.date!.isBefore(DateTime.now()),
                };
              }).toList();

              final upcoming = userEvents.where((e) => !(e['isPast'] as bool)).toList();
              final past = userEvents.where((e) => e['isPast'] as bool).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildEventList(upcoming, 'No upcoming registrations.'),
                  _buildEventList(past, 'No past events attended yet.'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventList(List<Map<String, dynamic>> items, String emptyMsg) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                emptyMsg,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final post = item['post'] as PostItem;
        final rsvp = item['rsvp'] as Map<String, dynamic>;
        final certificateUrl = rsvp['certificateUrl']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  appState: widget.appState,
                  initialPost: post,
                ),
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          post.clubName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.blue.withOpacity(0.7),
                          ),
                        ),
                      ),
                      if (certificateUrl != null && certificateUrl.isNotEmpty)
                        const Icon(Icons.workspace_premium, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        post.date != null
                            ? '${post.date!.day}/${post.date!.month}/${post.date!.year}'
                            : 'No date',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.location ?? 'Online',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (certificateUrl != null && certificateUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(certificateUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Certificate'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

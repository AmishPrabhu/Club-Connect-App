import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/event_card.dart';
import '../widgets/glass_card.dart';
import 'post_detail_screen.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String _clubFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final announcements =
        widget.appState.posts
            .where((post) => post.type == 'announcement')
            .toList()
          ..sort((a, b) {
            final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
    final clubs =
        widget.appState.clubs.map((club) => club.name).toSet().toList()..sort();
    final filtered = announcements.where((post) {
      if (_clubFilter == 'all') return true;
      return post.clubName == _clubFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest Announcements',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Catch club updates, reminders, deadlines, and general notices in one place.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: clubs.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return FilterChip(
                                  selected: _clubFilter == 'all',
                                  showCheckmark: false,
                                  label: const Text('All Clubs'),
                                  onSelected: (_) =>
                                      setState(() => _clubFilter = 'all'),
                                );
                              }
                              final club = clubs[index - 1];
                              return FilterChip(
                                selected: _clubFilter == club,
                                showCheckmark: false,
                                label: Text(club),
                                onSelected: (_) =>
                                    setState(() => _clubFilter = club),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: GlassCard(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Icon(
                        Icons.campaign_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No announcements found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try another club filter or check back later.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final post = filtered[index];
                  return EventCard(
                    post: post,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          appState: widget.appState,
                          initialPost: post,
                        ),
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
}

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/event_card.dart';
import 'post_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  String _status = 'all';
  String _club = 'all';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final allEvents = widget.appState.posts
            .where((post) => post.isEvent)
            .toList();
        final allClubs =
            widget.appState.clubs.map((club) => club.name).toSet().toList()..sort();
        final filtered = allEvents.where((event) {
          final statusMatch =
              _status == 'all' ||
              (_status == 'upcoming' && event.isUpcoming) ||
              (_status == 'completed' && !event.isUpcoming);
          final clubMatch = _club == 'all' || event.clubName == _club;
          return statusMatch && clubMatch;
        }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Events',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay updated with workshops, competitions, social gatherings, and club activities.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _chip('all', 'All'),
                          _chip('upcoming', 'Upcoming'),
                          _chip('completed', 'Completed'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _club,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.filter_alt_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Clubs'),
                        ),
                        ...allClubs.map(
                          (club) =>
                              DropdownMenuItem(value: club, child: Text(club)),
                        ),
                      ],
                      onChanged: (value) => setState(() => _club = value ?? 'all'),
                    ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 64, color: Theme.of(context).dividerColor),
                        const SizedBox(height: 16),
                        const Text(
                          'No events match your filters.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Try changing the status filter or clearing all selections.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _status = 'all';
                              _club = 'all';
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) => EventCard(
                    appState: widget.appState,
                    post: filtered[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          appState: widget.appState,
                          initialPost: filtered[index],
                        ),
                      ),
                    ),
                  ),
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemCount: filtered.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: FilterChip(
        selected: _status == value,
        showCheckmark: false,
        label: Text(label),
        onSelected: (_) => setState(() => _status = value),
      ),
    );
  }
}

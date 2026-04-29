import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/club_tile.dart';
import 'club_detail_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key, required this.appState});

  final AppState appState;

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Technical', 'Academic', 'Cultural', 'Sports'];
    final clubs = widget.appState.clubs.where((club) {
      final matchesCategory = _category == 'All' || club.category == _category;
      final searchable = '${club.name} ${club.description}'.toLowerCase();
      final matchesQuery = searchable.contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
    final liked = widget.appState.session?.likedClubs ?? const <String>[];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Clubs',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore student-led organizations, browse categories, and open club profiles.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search clubs by name or description...',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return FilterChip(
                        selected: category == _category,
                        showCheckmark: false,
                        label: Text(category),
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final club = clubs[index];
              return ClubTile(
                club: club,
                isLiked: liked.contains(club.id),
                onToggleLike: widget.appState.session == null
                    ? null
                    : () => widget.appState.toggleClubLike(club.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ClubDetailScreen(appState: widget.appState, club: club),
                  ),
                ),
              );
            }, childCount: clubs.length),
          ),
        ),
      ],
    );
  }
}

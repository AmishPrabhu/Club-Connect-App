import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/glass_card.dart';
import 'club_detail_screen.dart';
import 'post_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.appState,
    required this.onOpenClubs,
    required this.onOpenEvents,
  });

  final AppState appState;
  final VoidCallback onOpenClubs;
  final VoidCallback onOpenEvents;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final clubs = widget.appState.clubs;
    final upcomingEvents = widget.appState.posts
        .where((post) => post.isUpcoming)
        .toList();
    final matches = clubs.where((club) {
      final text = '${club.name} ${club.description}'.toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return CustomScrollView(
      slivers: [
        if (widget.appState.error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                widget.appState.error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(upcomingCount: upcomingEvents.length),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.groups_rounded,
                        accent: AppTheme.cyan,
                        value: '${clubs.length}',
                        label: 'Active Clubs',
                        onTap: widget.onOpenClubs,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.calendar_month_rounded,
                        accent: AppTheme.purple,
                        value: '${upcomingEvents.length}',
                        label: 'Upcoming Events',
                        onTap: widget.onOpenEvents,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search clubs, events, or announcements...',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                if (_query.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: matches
                          .map(
                            (club) => ListTile(
                              leading: CircleAvatar(child: Text(club.icon)),
                              title: Text(club.name),
                              subtitle: Text(
                                club.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ClubDetailScreen(
                                    appState: widget.appState,
                                    club: club,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _SectionHeading(
                  title: 'Featured Clubs',
                  actionLabel: 'See all',
                  onTap: widget.onOpenClubs,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 238,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final club = clubs[index];
                return SizedBox(
                  width: 270,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClubDetailScreen(
                          appState: widget.appState,
                          club: club,
                        ),
                      ),
                    ),
                    child: _FeaturedClubCard(
                      name: club.name,
                      imageUrl: club.imageAsset,
                      category: club.category,
                    ),
                  ),
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemCount: clubs.length > 6 ? 6 : clubs.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            child: _SectionHeading(
              title: 'Weekly Events',
              actionLabel: 'Browse all',
              onTap: widget.onOpenEvents,
            ),
          ),
        ),
        SliverList.separated(
          itemCount: upcomingEvents.length > 3 ? 3 : upcomingEvents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: EventCard(
              post: upcomingEvents[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                    appState: widget.appState,
                    initialPost: upcomingEvents[index],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.upcomingCount});

  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE8F3FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.blue.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Premier Institute',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Walchand College of Engineering',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Discover communities, track club activity, and join the next wave of campus events.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$upcomingCount events lined up this week',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppTheme.navy),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/wce-logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.14),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 16),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedClubCard extends StatelessWidget {
  const _FeaturedClubCard({
    required this.name,
    required this.imageUrl,
    required this.category,
  });

  final String name;
  final String imageUrl;
  final String category;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.startsWith('http')
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Image.asset(imageUrl, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

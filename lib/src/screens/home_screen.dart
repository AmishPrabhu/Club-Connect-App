import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/glass_card.dart';
import 'announcements_screen.dart';
import 'dashboard_screen.dart';
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
    final announcements =
        widget.appState.posts
            .where((post) => post.type == 'announcement')
            .toList()
          ..sort((a, b) {
            final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
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
                _QuickActions(
                  appState: widget.appState,
                  onOpenClubs: widget.onOpenClubs,
                  onOpenEvents: widget.onOpenEvents,
                ),
                const SizedBox(height: 20),
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
                              subtitle: Text(club.category),
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
            height: 190,
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
                      imageUrl: club.resolvedImageUrl,
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: _SectionHeading(
              title: 'Latest Announcements',
              actionLabel: 'View all',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AnnouncementsScreen(appState: widget.appState),
                  ),
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          sliver: SliverList.separated(
            itemCount: announcements.isEmpty
                ? 0
                : announcements.length > 2
                ? 2
                : announcements.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) => GlassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF3E8FF),
                  child: Icon(Icons.campaign_outlined, color: AppTheme.purple),
                ),
                title: Text(announcements[index].title),
                subtitle: Text(
                  announcements[index].content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(
                      appState: widget.appState,
                      initialPost: announcements[index],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
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
          colors: [AppTheme.navy, Color(0xFF0F3B73)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/wce-logo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
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
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Official College Portal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Walchand College of Engineering',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'A central portal for club notices, event schedules, and campus participation.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(label: '$upcomingCount upcoming events'),
                const _InfoChip(label: 'Club notices'),
                const _InfoChip(label: 'Campus updates'),
              ],
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.appState,
    required this.onOpenClubs,
    required this.onOpenEvents,
  });

  final AppState appState;
  final VoidCallback onOpenClubs;
  final VoidCallback onOpenEvents;

  @override
  Widget build(BuildContext context) {
    final session = appState.session;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ActionChip(
          icon: Icons.groups_rounded,
          label: 'Clubs',
          onTap: onOpenClubs,
        ),
        _ActionChip(
          icon: Icons.event_rounded,
          label: 'Events',
          onTap: onOpenEvents,
        ),
        _ActionChip(
          icon: Icons.campaign_outlined,
          label: 'Announcements',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AnnouncementsScreen(appState: appState),
              ),
            );
          },
        ),
        _ActionChip(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          onTap: session == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DashboardScreen(appState: appState),
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.navy),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.text,
              ),
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
  final String? imageUrl;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFEFF), Color(0xFFEAF3FF)],
        ),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ClubLogo(imageUrl: imageUrl),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppTheme.text),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to view club details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubLogo extends StatelessWidget {
  const _ClubLogo({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final src = imageUrl?.trim() ?? '';
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.1)),
      ),
      child: src.isEmpty
          ? const Icon(Icons.school_outlined, color: AppTheme.navy, size: 28)
          : Image.network(
              src,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.school_outlined, color: AppTheme.navy, size: 28),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import 'announcements_screen.dart';
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: announcements.isEmpty ? 128 : 168,
            child: announcements.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionEmptyCard(
                      icon: Icons.campaign_outlined,
                      title: 'No announcements yet',
                      message:
                          'Club notices will show up here once they are posted.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: announcements.length > 5
                        ? 5
                        : announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final announcement = announcements[index];
                      return SizedBox(
                        width: 280,
                        child: _FeedPreviewCard(
                          icon: Icons.campaign_outlined,
                          accent: AppTheme.purple,
                          title: announcement.title,
                          subtitle: announcement.clubName,
                          body: announcement.content,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                appState: widget.appState,
                                initialPost: announcement,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: upcomingEvents.isEmpty ? 128 : 176,
            child: upcomingEvents.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionEmptyCard(
                      icon: Icons.event_busy_outlined,
                      title: 'No upcoming events',
                      message:
                          'Future events will appear here when clubs publish them.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: upcomingEvents.length > 5
                        ? 5
                        : upcomingEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final event = upcomingEvents[index];
                      return SizedBox(
                        width: 280,
                        child: _FeedPreviewCard(
                          icon: Icons.event_rounded,
                          accent: AppTheme.blue,
                          title: event.title,
                          subtitle: event.clubName,
                          body:
                              '${event.date != null ? '${event.date!.day}/${event.date!.month}/${event.date!.year}' : 'No date'}'
                              '${event.time != null && event.time!.isNotEmpty ? ' • ${event.time}' : ''}'
                              '${event.location != null && event.location!.isNotEmpty ? ' • ${event.location}' : ''}',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(
                                appState: widget.appState,
                                initialPost: event,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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
          colors: [Color(0xFFFDFCF8), Color(0xFFF3F0E9)],
        ),
        border: Border.all(color: AppTheme.navy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
                    color: AppTheme.navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.navy.withValues(alpha: 0.08),
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
                          color: AppTheme.navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Official College Portal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Walchand College of Engineering',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'A central portal for club notices, event schedules, and campus participation.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.text,
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
                Flexible(
                  child: Container(
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
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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

class _FeedPreviewCard extends StatelessWidget {
  const _FeedPreviewCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.12),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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

class _SectionEmptyCard extends StatelessWidget {
  const _SectionEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.navy.withValues(alpha: 0.08),
            child: Icon(icon, color: AppTheme.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        color: AppTheme.navy.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.navy.withValues(alpha: 0.04)),
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

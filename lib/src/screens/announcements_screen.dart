import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
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

  List<PostItem> get _filtered {
    return widget.appState.posts
        .where(
          (p) =>
              !p.isEvent &&
              p.status == 'published' &&
              (_clubFilter == 'all' || p.clubName == _clubFilter),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final clubNames = widget.appState.posts
        .where((p) => !p.isEvent)
        .map((p) => p.clubName)
        .toSet()
        .toList()
      ..sort();

    final items = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Announcements',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Stay informed with the latest news from all clubs.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _clubFilter,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.filter_alt_outlined),
                      labelText: 'Filter by club',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Clubs'),
                      ),
                      ...clubNames.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _clubFilter = v ?? 'all'),
                  ),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: 72,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No announcements yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final post = items[index];
                  return _AnnouncementCard(
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

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.post, required this.onTap});

  final PostItem post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(post.createdAt);
    final timeAgo = diff.inDays > 0
        ? '${diff.inDays}d ago'
        : diff.inHours > 0
            ? '${diff.inHours}h ago'
            : diff.inMinutes > 0
                ? '${diff.inMinutes}m ago'
                : 'just now';

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: AppTheme.navy,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          post.clubName,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppTheme.blue),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.content.length > 120
                        ? '${post.content.substring(0, 120)}…'
                        : post.content,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

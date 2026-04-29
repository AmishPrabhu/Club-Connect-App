import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../widgets/glass_card.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.appState,
    required this.initialPost,
  });

  final AppState appState;
  final PostItem initialPost;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _submitting = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialPost.type == 'event' ? 'Event Detail' : 'Announcement',
        ),
      ),
      body: FutureBuilder<PostItem>(
        future: widget.appState.fetchPost(widget.initialPost.id),
        initialData: widget.initialPost,
        builder: (context, snapshot) {
          final post = snapshot.data ?? widget.initialPost;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (post.coverAsset != null &&
                          post.coverAsset!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: post.coverAsset!.startsWith('http')
                              ? Image.network(
                                  post.coverAsset!,
                                  width: double.infinity,
                                  height: 240,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  post.coverAsset!,
                                  width: double.infinity,
                                  height: 240,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      const SizedBox(height: 18),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'by ${post.clubName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              post.content,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (post.date != null) ...[
                              const SizedBox(height: 20),
                              _MetaRow(
                                icon: Icons.calendar_month_rounded,
                                label:
                                    '${post.date!.day}/${post.date!.month}/${post.date!.year}',
                              ),
                            ],
                            if (post.time != null) ...[
                              const SizedBox(height: 10),
                              _MetaRow(
                                icon: Icons.schedule_rounded,
                                label: post.time!,
                              ),
                            ],
                            if (post.location != null) ...[
                              const SizedBox(height: 10),
                              _MetaRow(
                                icon: Icons.place_outlined,
                                label: post.location!,
                              ),
                            ],
                            if (post.isEvent) ...[
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => _rsvp(post.id),
                                  child: Text(
                                    _submitting ? 'Submitting...' : 'RSVP',
                                  ),
                                ),
                              ),
                            ],
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(_message!),
                            ],
                          ],
                        ),
                      ),
                      if (post.attachments.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Attachments',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final src = post.attachments[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: src.startsWith('http')
                          ? Image.network(src, fit: BoxFit.cover)
                          : Image.asset(src, fit: BoxFit.cover),
                    );
                  }, childCount: post.attachments.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rsvp(String eventId) async {
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await widget.appState.rsvpToEvent(eventId);
      setState(() => _message = 'RSVP submitted successfully.');
    } catch (error) {
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

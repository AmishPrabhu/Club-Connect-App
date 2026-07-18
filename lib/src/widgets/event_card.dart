import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/post_item.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class EventCard extends StatefulWidget {
  const EventCard({super.key, required this.post, required this.appState, this.onTap});

  final PostItem post;
  final AppState appState;
  final VoidCallback? onTap;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _submitting = false;

  static const List<String> _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final date = widget.post.date ?? DateTime.now();
    final month = _months[date.month - 1];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _image(context, widget.post.coverAsset, height: 190),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          month,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.mutedColor(context),
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.clubName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.accent(context),
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.post.isUpcoming
                              ? (isDark
                                  ? AppTheme.darkElevated
                                  : const Color(0xFF15803D).withValues(alpha: 0.12))
                              : AppTheme.mutedColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.post.isUpcoming ? 'Upcoming' : 'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: widget.post.isUpcoming
                                ? (isDark ? Colors.white : const Color(0xFF15803D))
                                : AppTheme.mutedColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stripMarkdown(widget.post.content),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor(context)),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _Meta(
                        icon: Icons.schedule_rounded,
                        label: widget.post.time ?? 'All Day',
                      ),
                      _Meta(
                        icon: Icons.place_outlined,
                        label: widget.post.location ?? 'Campus',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.post.isEvent) _buildEventActionButton(widget.post),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventActionButton(PostItem post) {
    final isLoggedIn = widget.appState.session != null;

    if (!post.isUpcoming) return const SizedBox.shrink();

    if (post.hasRegistrationDates) {
      if (post.isBeforeRegistration) {
        if (!isLoggedIn) return const SizedBox.shrink();
        return _buildInterestedButton(post);
      }
      if (post.isRegistrationOpen) {
        final link = post.registrationLink;
        if (link == null || link.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openRegistrationLink(link),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Register Now →'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (isLoggedIn) {
      return _buildInterestedButton(post);
    }
    return const SizedBox.shrink();
  }

  Widget _buildInterestedButton(PostItem post) {
    // Listen to changes in AppState to immediately update UI on the feed when clicked anywhere
    return AnimatedBuilder(
      animation: widget.appState,
      builder: (context, _) {
        final isInterested = widget.appState.isInterested(post.id);
        return SizedBox(
          width: double.infinity,
          child: _submitting
              ? const Center(child: Padding(padding: EdgeInsets.all(4), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
              : FilledButton.icon(
                  onPressed: () => _toggleInterest(post.id, isInterested),
                  icon: Icon(
                    isInterested ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                  ),
                  label: Text(isInterested ? "You're Interested" : "I'm Interested"),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isInterested ? Theme.of(context).colorScheme.secondary : null,
                  ),
                ),
        );
      },
    );
  }

  Future<void> _toggleInterest(String eventId, bool currentlyInterested) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      if (currentlyInterested) {
        await widget.appState.removeInterest(eventId);
      } else {
        await widget.appState.markInterested(eventId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openRegistrationLink(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(ClipboardData(text: link));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link. Copied to clipboard instead.')),
        );
      }
    }
  }

  Widget _image(BuildContext context, String? src, {required double height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (src == null || src.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: isDark ? AppTheme.darkElevated : const Color(0xFFE2E8F0),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: isDark
              ? AppTheme.darkMuted.withValues(alpha: 0.6)
              : AppTheme.muted.withValues(alpha: 0.6),
        ),
      );
    }
    if (src.startsWith('http')) {
      return Image.network(
        src,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/club-default.jpg',
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    final path = src.startsWith('/') ? 'assets/images$src' : src;
    return Image.asset(
      path,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/club-default.jpg',
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.mutedColor(context)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _stripMarkdown(String markdown) {
  // 1. Link parsing: [text](url) -> text
  var text = markdown.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) => match[1] ?? '');
  // 2. Bold/Italic formatting: **text** or __text__ or *text* or _text_ -> text
  text = text.replaceAll(RegExp(r'\*\*|__|\*|_'), '');
  // 3. Headers: # Heading -> Heading
  text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
  // 4. Bullet lists: - item -> item
  text = text.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '');
  return text.trim();
}


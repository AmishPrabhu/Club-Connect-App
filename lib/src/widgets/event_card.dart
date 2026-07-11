import 'package:flutter/material.dart';

import '../models/post_item.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.post, this.onTap});

  final PostItem post;
  final VoidCallback? onTap;

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
    final date = post.date ?? DateTime.now();
    final month = _months[date.month - 1];

    return GestureDetector(
      onTap: onTap,
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
                  child: _image(post.coverAsset, height: 190),
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
                          post.clubName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.blue,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: post.isUpcoming
                              ? const Color(0xFF15803D).withValues(alpha: 0.12)
                              : AppTheme.mutedColor(context).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          post.isUpcoming ? 'Upcoming' : 'Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: post.isUpcoming
                                ? const Color(0xFF15803D)
                                : AppTheme.mutedColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _stripMarkdown(post.content),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _Meta(
                        icon: Icons.schedule_rounded,
                        label: post.time ?? 'All Day',
                      ),
                      _Meta(
                        icon: Icons.place_outlined,
                        label: post.location ?? 'Campus',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(String? src, {required double height}) {
    if (src == null || src.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFFE2E8F0),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: AppTheme.muted.withValues(alpha: 0.6),
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
        Icon(icon, size: 16, color: AppTheme.purple),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.text,
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


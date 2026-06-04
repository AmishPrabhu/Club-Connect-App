import 'package:flutter/material.dart';

import '../models/club.dart';

class ClubTile extends StatelessWidget {
  const ClubTile({
    super.key,
    required this.club,
    required this.onTap,
    this.isLiked = false,
    this.onToggleLike,
  });

  final Club club;
  final VoidCallback onTap;
  final bool isLiked;
  final VoidCallback? onToggleLike;

  List<String> _getTags(Club club) {
    final tags = [club.category.toUpperCase()];
    if (club.name.toLowerCase().contains('acses')) {
      tags.add('CSE');
    } else if (club.name.toLowerCase().contains('mlsc')) {
      tags.add('CSE');
    }
    return tags;
  }

  Color _getTagBgColor(String tag) {
    switch (tag.toUpperCase()) {
      case 'TECHNICAL':
        return const Color(0xFFE0F2FE);
      case 'CSE':
        return const Color(0xFFF3E8FF);
      case 'CULTURAL':
        return const Color(0xFFFCE7F3);
      case 'SPORTS':
        return const Color(0xFFDCFCE7);
      case 'ACADEMIC':
        return const Color(0xFFFEF9C3);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getTagTextColor(String tag) {
    switch (tag.toUpperCase()) {
      case 'TECHNICAL':
        return const Color(0xFF0369A1);
      case 'CSE':
        return const Color(0xFF6B21A8);
      case 'CULTURAL':
        return const Color(0xFFBE185D);
      case 'SPORTS':
        return const Color(0xFF15803D);
      case 'ACADEMIC':
        return const Color(0xFF854D0E);
      default:
        return const Color(0xFF475569);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = _getTags(club);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.06)),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _image(club.imageAsset),
                    ),
                  ),
                  const Spacer(),
                  if (onToggleLike != null)
                    GestureDetector(
                      onTap: onToggleLike,
                      child: Icon(
                        isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isLiked ? Colors.red : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                club.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTagBgColor(tag),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: _getTagTextColor(tag),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  club.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    color: Color(0xFF94A3B8),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${club.members}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF94A3B8),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${club.upcomingEvents}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(String src) {
    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/club-default.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }
    final path = src.startsWith('/') ? 'assets/images$src' : src;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/club-default.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}

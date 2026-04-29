import 'package:flutter/material.dart';

class Club {
  const Club({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.members,
    required this.icon,
    required this.imageAsset,
    required this.startColor,
    required this.endColor,
    required this.upcomingEvents,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final int members;
  final String icon;
  final String imageAsset;
  final Color startColor;
  final Color endColor;
  final int upcomingEvents;

  factory Club.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? 'technical';
    final colors = _colorsForCategory(category);
    return Club(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      name: json['name']?.toString() ?? 'Club',
      description: json['description']?.toString() ?? '',
      category: _labelForCategory(category),
      members: (json['members'] as num?)?.toInt() ?? 0,
      icon: _iconForCategory(category),
      imageAsset: json['image']?.toString() ?? '',
      startColor: colors.$1,
      endColor: colors.$2,
      upcomingEvents: (json['upcomingEvents'] as num?)?.toInt() ?? 0,
    );
  }

  static (Color, Color) _colorsForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return (const Color(0xFF10B981), const Color(0xFF14B8A6));
      case 'cultural':
        return (const Color(0xFFEC4899), const Color(0xFFE11D48));
      case 'sports':
        return (const Color(0xFF22C55E), const Color(0xFF059669));
      default:
        return (const Color(0xFF2563EB), const Color(0xFF06B6D4));
    }
  }

  static String _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return '🎓';
      case 'cultural':
        return '🎨';
      case 'sports':
        return '⚽';
      default:
        return '🚀';
    }
  }

  static String _labelForCategory(String category) {
    if (category.isEmpty) return 'Technical';
    return '${category[0].toUpperCase()}${category.substring(1).toLowerCase()}';
  }
}

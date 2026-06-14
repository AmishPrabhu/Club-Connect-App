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
    this.fullForm = '',
    this.whatsappUrl = '',
    this.instagramUrl = '',
    this.presidentEmail = '',
    this.secretaryEmail = '',
    this.treasurerEmail = '',
    this.advisorEmail = '',
    this.advisorName = '',
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
  final String fullForm;
  final String whatsappUrl;
  final String instagramUrl;
  final String presidentEmail;
  final String secretaryEmail;
  final String treasurerEmail;
  final String advisorEmail;
  final String advisorName;

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
      fullForm: json['fullForm']?.toString() ?? '',
      whatsappUrl: json['whatsappUrl']?.toString() ?? '',
      instagramUrl: json['instagramUrl']?.toString() ?? '',
      presidentEmail: json['presidentEmail']?.toString() ?? '',
      secretaryEmail: json['secretaryEmail']?.toString() ?? '',
      treasurerEmail: json['treasurerEmail']?.toString() ?? '',
      advisorEmail: json['advisorEmail']?.toString() ?? '',
      advisorName: json['advisorName']?.toString() ?? '',
    );
  }

  static (Color, Color) _colorsForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return (const Color(0xFF064E3B), const Color(0xFF0F766E));
      case 'cultural':
        return (const Color(0xFF581C87), const Color(0xFF701A75));
      case 'sports':
        return (const Color(0xFF14532D), const Color(0xFF065F46));
      default:
        return (const Color(0xFF1E3B8B), const Color(0xFF1D4ED8));
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

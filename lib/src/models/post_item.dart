class PostItem {
  const PostItem({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.content,
    required this.type,
    this.date,
    this.time,
    this.location,
    this.locationUrl,
    this.coverAsset,
    this.attachments = const [],
    this.rsvps,
    this.budgetImageUrl,
    this.budgetVerified,
  });

  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final String content;
  final String type;
  final DateTime? date;
  final String? time;
  final String? location;
  final String? locationUrl;
  final String? coverAsset;
  final List<String> attachments;

  /// RSVP count — mirrors DBPost.rsvps (number of RSVP names)
  final int? rsvps;

  /// Budget image URL uploaded by secretary
  final String? budgetImageUrl;

  /// Whether the advisor has verified the budget
  final bool? budgetVerified;

  bool get isEvent => type == 'event';
  bool get isUpcoming =>
      isEvent && date != null && date!.isAfter(DateTime.now());

  factory PostItem.fromJson(Map<String, dynamic> json) {
    final attachments = <String>[];
    for (final key in ['attachments', 'eventPhotos']) {
      final values = json[key] as List<dynamic>? ?? const [];
      for (final item in values) {
        if (item is Map<String, dynamic> && item['url'] != null) {
          attachments.add(item['url'].toString());
        }
      }
    }

    // rsvps can be a List (names) or an int
    final rsvpsRaw = json['rsvps'];
    int? rsvpsCount;
    if (rsvpsRaw is List) {
      rsvpsCount = rsvpsRaw.length;
    } else if (rsvpsRaw is int) {
      rsvpsCount = rsvpsRaw;
    }

    return PostItem(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      clubId: json['clubId']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? 'Club',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString() ?? 'announcement',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      time: json['time']?.toString(),
      location: json['location']?.toString(),
      locationUrl: json['locationUrl']?.toString(),
      coverAsset: json['coverImage']?.toString(),
      attachments: attachments,
      rsvps: rsvpsCount,
      budgetImageUrl: json['budgetImage']?.toString(),
      budgetVerified: json['budgetVerified'] as bool?,
    );
  }
}

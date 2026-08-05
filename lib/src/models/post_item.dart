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
    this.timeFrom,
    this.timeTo,
    this.location,
    this.locationType,
    this.locationUrl,
    this.coverAsset,
    this.attachments = const [],
    this.descriptionImages = const [],
    this.rsvps,
    this.budgetImageUrl,
    this.budgetVerified,
    this.reportUrl,
    this.reportSubmittedByName,
    this.reportSubmittedAt,
    this.totalSessions = 1,
    this.certificateTemplate,
    this.registrationStart,
    this.registrationStartTime,
    this.registrationEnd,
    this.registrationEndTime,
    this.registrationLink,
    this.responseSpreadsheetUrl,
    this.eventWhatsappLink,
    this.relatedEventId,
    this.relatedEventTitle,
    this.visibility,
  });

  final String id;
  final String clubId;
  final String clubName;
  final String title;
  final String content;
  final String type;
  final DateTime? date;
  /// Legacy single time string (e.g. "5:00 PM"). Use [timeFrom]/[timeTo] when available.
  final String? time;
  /// New structured time fields
  final String? timeFrom;
  final String? timeTo;
  final String? location;
  final String? locationType;
  final String? locationUrl;
  final String? coverAsset;
  final List<String> attachments;
  /// Inline description images uploaded alongside the post
  final List<String> descriptionImages;

  /// RSVP count — mirrors DBPost.rsvps (number of RSVP names)
  final int? rsvps;

  /// Budget image URL uploaded by secretary
  final String? budgetImageUrl;

  /// Whether the advisor has verified the budget
  final bool? budgetVerified;

  /// Event activity report URL
  final String? reportUrl;

  /// Name of officer who submitted the report
  final String? reportSubmittedByName;

  /// Timestamp of report submission
  final DateTime? reportSubmittedAt;

  /// Total number of attendance sessions (default is 1)
  final int totalSessions;

  /// Certificate template positioning variables
  final Map<String, dynamic>? certificateTemplate;
  
  /// Event specific registration fields
  final String? registrationStart;
  final String? registrationStartTime;
  final String? registrationEnd;
  final String? registrationEndTime;
  final String? registrationLink;
  final String? responseSpreadsheetUrl;
  final String? eventWhatsappLink;
  
  /// Related event fields (for announcements)
  final String? relatedEventId;
  final String? relatedEventTitle;

  final String? visibility;

  bool get isEvent => type.toLowerCase() == 'event';
  bool get isService => type.toLowerCase() == 'service';
  bool get isUpcoming =>
      (isEvent || isService) && date != null && date!.isAfter(DateTime.now());

  /// Parse a date string "YYYY-MM-DD" and optional time string "HH:MM AM/PM"
  /// into a DateTime. Returns null if the date string is null/empty.
  static DateTime? _parseDateTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    final datePart = DateTime.tryParse(dateStr);
    if (datePart == null) return null;
    if (timeStr == null || timeStr.isEmpty) return datePart;

    // Try to parse time like "10:00 AM", "2:30 PM", "14:00", etc.
    final cleaned = timeStr.trim().toUpperCase();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)?$').firstMatch(cleaned);
    if (match != null) {
      var hour = int.tryParse(match.group(1)!) ?? 0;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      final ampm = match.group(3);
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
    }
    return datePart;
  }

  /// Parsed registration start date+time
  DateTime? get registrationStartDateTime =>
      _parseDateTime(registrationStart, registrationStartTime);

  /// Parsed registration end date+time
  DateTime? get registrationEndDateTime =>
      _parseDateTime(registrationEnd, registrationEndTime);

  /// True if registration window hasn't opened yet
  bool get isBeforeRegistration {
    final start = registrationStartDateTime;
    if (start == null) return false;
    return DateTime.now().isBefore(start);
  }

  /// True if we are currently within the registration window
  bool get isRegistrationOpen {
    final start = registrationStartDateTime;
    final end = registrationEndDateTime;
    final now = DateTime.now();
    if (start == null) return false;
    if (now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }

  /// True if registration window has closed
  bool get isAfterRegistration {
    final end = registrationEndDateTime;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  /// True if registration dates are configured at all
  bool get hasRegistrationDates =>
      registrationStart != null && registrationStart!.isNotEmpty;

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
          ? DateTime.tryParse(json['date'].toString())?.toLocal()
          : null,
      time: json['time']?.toString(),
      timeFrom: json['timeFrom']?.toString(),
      timeTo: json['timeTo']?.toString(),
      location: json['location']?.toString(),
      locationType: json['locationType']?.toString(),
      locationUrl: json['locationUrl']?.toString(),
      coverAsset: (json['coverImage'] != null && json['coverImage'].toString().isNotEmpty)
          ? json['coverImage'].toString()
          : (json['image'] != null && json['image'].toString().isNotEmpty)
              ? json['image'].toString()
              : null,
      attachments: attachments,
      descriptionImages: (json['descriptionImages'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      rsvps: rsvpsCount,
      budgetImageUrl: json['budgetImage']?.toString(),
      budgetVerified: json['budgetVerified'] as bool?,
      reportUrl: json['reportUrl']?.toString(),
      reportSubmittedByName: json['reportSubmittedByName']?.toString(),
      reportSubmittedAt: json['reportSubmittedAt'] != null
          ? DateTime.tryParse(json['reportSubmittedAt'].toString())?.toLocal()
          : null,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 1,
      certificateTemplate: json['certificateTemplate'] as Map<String, dynamic>?,
      registrationStart: json['registrationStart']?.toString(),
      registrationStartTime: json['registrationStartTime']?.toString(),
      registrationEnd: json['registrationEnd']?.toString(),
      registrationEndTime: json['registrationEndTime']?.toString(),
      registrationLink: json['registrationLink']?.toString(),
      responseSpreadsheetUrl: json['responseSpreadsheetUrl']?.toString(),
      eventWhatsappLink: json['eventWhatsappLink']?.toString(),
      relatedEventId: json['relatedEventId']?.toString(),
      relatedEventTitle: json['relatedEventTitle']?.toString(),
      visibility: json['visibility']?.toString(),
    );
  }
}

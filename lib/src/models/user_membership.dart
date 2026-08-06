/// Represents a user's membership in a specific club.
/// Parsed from the `memberships` array returned by the `/auth/me` endpoint.
class UserMembership {
  UserMembership({
    required this.clubId,
    required this.clubName,
    required this.role,
    required this.boardType,
    this.clubImage,
    this.clubSlug,
    this.email,
    this.officerRole,
    this.isCurrent = true,
  });

  final String clubId;
  final String clubName;
  final String role;       // Custom role in the club (e.g. "Coordinator", "President", "Member")
  final String boardType;  // "main", "executive", or "member"
  final String? clubImage;
  final String? clubSlug;
  final String? email;
  final String? officerRole; // Officer role derived from Club email fields (e.g. "president", "secretary")
  final bool isCurrent;

  /// Standard officer role names that the backend recognizes.
  static const _officerRoles = [
    'secretary', 'president', 'treasurer', 'advisor', 'vice-president', 'vice president',
  ];

  /// Whether this membership grants officer-level access.
  /// Matches the backend middleware logic: boardType in [main, executive]
  /// OR role is a standard officer role.
  bool get isOfficer {
    if (!isCurrent) return false;
    if (boardType == 'main' || boardType == 'executive') return true;
    final r = role.toLowerCase().trim();
    if (_officerRoles.contains(r)) return true;
    // Fallback for custom roles containing officer keywords
    if (r.contains('president') || 
        r.contains('secretary') || 
        r.contains('treasurer') || 
        r.contains('advisor') || 
        r.contains('coordinator')) {
      return true;
    }
    return false;
  }

  /// Whether this membership grants report submission access.
  /// President, Secretary, or any main/executive board member can submit reports.
  bool get canSubmitReport {
    if (!isCurrent) return false;
    if (boardType == 'main' || boardType == 'executive') return true;
    final r = role.toLowerCase();
    return r == 'president' || r == 'secretary';
  }

  /// Whether this membership grants permission to manage members.
  /// Only President, Vice-President, Secretary, and Advisor can manage members.
  bool get canManageMembers {
    if (!isCurrent) return false;
    final r = role.toLowerCase();
    return r == 'president' || r == 'vice-president' || r == 'secretary' || r == 'advisor';
  }

  /// Whether this membership grants permission to manage events & posts (create/edit/delete).
  /// Only President, Vice-President, Secretary, and Assistant Secretary can manage events & posts.
  bool get canManageEvents {
    if (!isCurrent) return false;
    final r = role.toLowerCase().trim();
    return r == 'president' ||
        r == 'secretary' ||
        r == 'vice-president' ||
        r == 'assistant secretary' ||
        r.contains('president') ||
        r.contains('secretary');
  }

  factory UserMembership.fromJson(Map<String, dynamic> json) {
    return UserMembership(
      clubId: json['clubId']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Member',
      boardType: json['boardType']?.toString() ?? 'member',
      clubImage: json['clubImage']?.toString(),
      clubSlug: json['clubSlug']?.toString(),
      email: json['email']?.toString(),
      officerRole: json['officerRole']?.toString(),
      isCurrent: json['isCurrent'] as bool? ?? true,
    );
  }
}

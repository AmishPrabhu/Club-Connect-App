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
  });

  final String clubId;
  final String clubName;
  final String role;       // Custom role in the club (e.g. "Coordinator", "President", "Member")
  final String boardType;  // "main", "executive", or "member"
  final String? clubImage;
  final String? clubSlug;
  final String? email;
  final String? officerRole; // Officer role derived from Club email fields (e.g. "president", "secretary")

  /// Standard officer role names that the backend recognizes.
  static const _officerRoles = [
    'secretary', 'president', 'treasurer', 'advisor',
  ];

  /// Whether this membership grants officer-level access.
  /// Matches the backend middleware logic: boardType in [main, executive]
  /// OR role is a standard officer role.
  bool get isOfficer {
    if (boardType == 'main' || boardType == 'executive') return true;
    if (_officerRoles.contains(role.toLowerCase())) return true;
    return false;
  }

  /// Whether this membership grants report submission access.
  /// President, Secretary, or any main/executive board member can submit reports.
  bool get canSubmitReport {
    if (boardType == 'main' || boardType == 'executive') return true;
    final r = role.toLowerCase();
    return r == 'president' || r == 'secretary';
  }

  /// Whether this membership grants permission to manage members.
  /// Only President, Vice-President, Secretary, and Advisor can manage members.
  bool get canManageMembers {
    final r = role.toLowerCase();
    return r == 'president' || r == 'vice-president' || r == 'secretary' || r == 'advisor';
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
    );
  }
}

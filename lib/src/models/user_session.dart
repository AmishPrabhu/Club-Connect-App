class Membership {
  const Membership({
    required this.clubId,
    required this.clubName,
    required this.clubImage,
    required this.clubSlug,
    required this.role,
    this.boardType,
    required this.email,
    this.officerRole,
  });

  final String clubId;
  final String clubName;
  final String clubImage;
  final String clubSlug;
  final String role;
  final String? boardType;
  final String email;
  final String? officerRole;

  bool get isManagementMembership {
    final r = role.toLowerCase();
    final bt = boardType?.toLowerCase() ?? '';
    return r == 'president' ||
        r == 'club-secretary' ||
        r == 'secretary' ||
        r == 'treasurer' ||
        r == 'advisor' ||
        bt == 'main' ||
        bt == 'executive' ||
        (officerRole != null && officerRole!.trim().isNotEmpty);
  }

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      clubId: json['clubId']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? '',
      clubImage: json['clubImage']?.toString() ?? '',
      clubSlug: json['clubSlug']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      boardType: json['boardType']?.toString(),
      email: json['email']?.toString() ?? '',
      officerRole: json['officerRole']?.toString(),
    );
  }
}

class UserSession {
  UserSession({
    required this.name,
    required this.email,
    required this.role,
    required this.id,
    this.clubId,
    this.clubName,
    this.profileImage,
    List<String>? likedClubs,
    List<Membership>? memberships,
  }) : likedClubs = likedClubs ?? [],
       memberships = memberships ?? [];

  final String? id;
  final String name;
  final String email;
  final String role;
  final String? clubId;
  final String? clubName;
  final String? profileImage;
  final List<String> likedClubs;
  final List<Membership> memberships;

  bool get hasAdminAccess => role.toLowerCase() == 'admin';

  bool hasRole(String roleName) => role.toLowerCase() == roleName.toLowerCase();

  bool hasAnyRole(List<String> roleNames) =>
      roleNames.any((r) => r.toLowerCase() == role.toLowerCase());

  bool canManageClubMembers(String targetClubId) {
    if (hasAdminAccess) return true;
    final isOfficer = hasRole('president') ||
        hasRole('club-secretary') ||
        hasRole('secretary') ||
        hasRole('treasurer') ||
        hasRole('advisor');
    if (isOfficer && clubId == targetClubId) return true;

    return memberships.any(
      (m) => m.clubId == targetClubId && m.isManagementMembership,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final liked = (json['likedClubs'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final membershipsJson = json['memberships'] as List<dynamic>? ?? const [];
    final parsedMemberships = membershipsJson
        .map((item) => Membership.fromJson(item as Map<String, dynamic>))
        .toList();

    return UserSession(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: json['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      clubId: json['clubId']?.toString(),
      clubName: json['clubName']?.toString(),
      profileImage: json['profileImage']?.toString(),
      likedClubs: liked,
      memberships: parsedMemberships,
    );
  }
}

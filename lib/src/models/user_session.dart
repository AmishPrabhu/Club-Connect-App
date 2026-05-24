class UserMembership {
  UserMembership({
    required this.clubId,
    required this.clubName,
    required this.role,
    this.clubImage,
    this.boardType,
    this.officerRole,
  });

  final String clubId;
  final String clubName;
  final String role;
  final String? clubImage;
  final String? boardType;
  final String? officerRole;

  factory UserMembership.fromJson(Map<String, dynamic> json) {
    return UserMembership(
      clubId: json['clubId']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      clubImage: json['clubImage']?.toString(),
      boardType: json['boardType']?.toString(),
      officerRole: json['officerRole']?.toString(),
    );
  }

  bool matchesAnyRole(Iterable<String> roles) {
    final normalized = roles.map(_normalizeRole).toSet();
    final roleMatches = normalized.contains(_normalizeRole(role));
    final officerMatches =
        officerRole != null &&
        normalized.contains(_normalizeRole(officerRole!));
    final boardMatches =
        (boardType == 'main' || boardType == 'executive') &&
        normalized.intersection(const {
          'club-secretary',
          'president',
          'treasurer',
          'advisor',
        }).isNotEmpty;
    return roleMatches || officerMatches || boardMatches;
  }

  bool get isManagementMembership => matchesAnyRole(const [
    'club-secretary',
    'president',
    'treasurer',
    'advisor',
  ]);

  static String _normalizeRole(String role) =>
      role.trim().toLowerCase().replaceAll(' ', '-');
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
    List<String>? roles,
    List<UserMembership>? memberships,
    List<String>? likedClubs,
  }) : roles = roles ?? const [],
       memberships = memberships ?? const [],
       likedClubs = likedClubs ?? [];

  final String? id;
  final String name;
  final String email;
  final String role;
  final String? clubId;
  final String? clubName;
  final String? profileImage;
  final List<String> roles;
  final List<UserMembership> memberships;
  final List<String> likedClubs;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final memberships = (json['memberships'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserMembership.fromJson)
        .toList();

    final rawRoles = (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final roles = <String>[
      json['role']?.toString().trim() ?? '',
      ...rawRoles,
    ].where((item) => item.isNotEmpty).toList();

    String? clubId = json['clubId']?.toString();
    String? clubName = json['clubName']?.toString();
    if ((clubId == null || clubId.isEmpty) && memberships.isNotEmpty) {
      clubId = memberships.first.clubId;
    }
    if ((clubName == null || clubName.isEmpty) && memberships.isNotEmpty) {
      clubName = memberships.first.clubName;
    }

    final liked = (json['likedClubs'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    return UserSession(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: json['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      clubId: clubId,
      clubName: clubName,
      profileImage: json['profileImage']?.toString(),
      roles: roles,
      memberships: memberships,
      likedClubs: liked,
    );
  }

  bool hasRole(String roleName) {
    final normalized = _normalizeRole(roleName);
    return _allRolesNormalized.contains(normalized);
  }

  bool hasAnyRole(Iterable<String> roleNames) => roleNames.any(hasRole);

  bool hasClubRole(String clubId, Iterable<String> roleNames) {
    final normalized = roleNames.map(_normalizeRole).toSet();
    return memberships.any((membership) {
      if (membership.clubId != clubId) return false;
      return membership.matchesAnyRole(normalized);
    });
  }

  List<String> get allRoles {
    final combined = <String>[
      role,
      ...roles,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    final seen = <String>{};
    final result = <String>[];
    for (final item in combined) {
      final normalized = _normalizeRole(item);
      if (seen.add(normalized)) {
        result.add(item);
      }
    }
    return result;
  }

  bool get hasAdminAccess => hasAnyRole(const ['admin', 'super-admin']);

  static String _normalizeRole(String role) =>
      role.trim().toLowerCase().replaceAll(' ', '-');

  Set<String> get _allRolesNormalized => allRoles.map(_normalizeRole).toSet();
}

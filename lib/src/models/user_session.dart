import 'user_membership.dart';
import 'club.dart';

class UserSession {
  UserSession({
    required this.name,
    required this.email,
    required this.role,
    required this.id,
    this.clubId,
    this.clubName,
    this.profileImage,
    this.bio,
    List<String>? likedClubs,
    List<String>? roles,
    List<UserMembership>? memberships,
  })  : likedClubs = likedClubs ?? [],
        roles = roles ?? [],
        memberships = memberships ?? [];

  final String? id;
  final String name;
  final String email;
  final String role;
  final String? clubId;
  final String? clubName;
  final String? profileImage;
  final String? bio;
  final List<String> likedClubs;
  final List<String> roles;
  final List<UserMembership> memberships;

  /// Check if this user is an officer of a specific club.
  /// Mirrors the backend verifyClubOfficer middleware logic.
  bool isClubOfficerOf(String clubId, {Club? club}) {
    if (role == 'admin') return true;
    final hasMembershipOfficer = memberships.any((m) => m.clubId == clubId && m.isOfficer);
    if (hasMembershipOfficer) return true;

    // Fallback: check if user's email matches the Club's direct officer email fields
    // Club email fields are non-nullable String (default ''), so no ?? needed.
    if (club != null) {
      final emailLower = email.toLowerCase();
      if (club.presidentEmail.toLowerCase() == emailLower ||
          club.secretaryEmail.toLowerCase() == emailLower ||
          club.treasurerEmail.toLowerCase() == emailLower ||
          club.advisorEmail.toLowerCase() == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Check if this user is a member of a specific club.
  bool isClubMemberOf(String clubId) {
    if (role == 'admin') return true;
    return memberships.any((m) => m.clubId == clubId);
  }

  /// Check if the user can submit reports for a specific club.
  bool canSubmitReportFor(String clubId, {Club? club}) {
    if (role == 'admin') return true;
    final hasMembershipReport = memberships.any((m) => m.clubId == clubId && m.canSubmitReport);
    if (hasMembershipReport) return true;

    // Fallback: President/Secretary can always submit reports
    // Club email fields are non-nullable String (default ''), so no ?? needed.
    if (club != null) {
      final emailLower = email.toLowerCase();
      if (club.presidentEmail.toLowerCase() == emailLower ||
          club.secretaryEmail.toLowerCase() == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Check if the user can manage members (add/edit/remove) for a specific club.
  /// Assistant Secretary is intentionally excluded.
  bool canManageMembersOf(String clubId, {Club? club}) {
    if (role == 'admin') return true;
    final hasMembershipManager = memberships.any((m) => m.clubId == clubId && m.canManageMembers);
    if (hasMembershipManager) return true;

    // Fallback: check if user's email matches the Club's direct manager email fields
    // Club email fields are non-nullable String (default ''), so no ?? needed.
    if (club != null) {
      final emailLower = email.toLowerCase();
      if (club.presidentEmail.toLowerCase() == emailLower ||
          club.secretaryEmail.toLowerCase() == emailLower ||
          club.advisorEmail.toLowerCase() == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Check if the user can edit club profile details
  /// (name, full form, profile picture, links, description, etc.).
  /// Mirrors the backend `verifyClubDetailsOfficer` middleware.
  /// Assistant Secretary is explicitly excluded.
  bool canEditClubDetailsOf(String clubId, {Club? club}) {
    if (role == 'admin') return true;
    final hasMembership = memberships.any((m) => m.clubId == clubId && m.canEditClubDetails);
    if (hasMembership) return true;

    // Fallback: Club-level email fields are always full officers (President, Secretary, Treasurer, Advisor)
    // Club email fields are non-nullable String (default ''), so no ?? needed.
    if (club != null) {
      final emailLower = email.toLowerCase();
      if (club.presidentEmail.toLowerCase() == emailLower ||
          club.secretaryEmail.toLowerCase() == emailLower ||
          club.treasurerEmail.toLowerCase() == emailLower ||
          club.advisorEmail.toLowerCase() == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Check if the user can manage events & posts (create/edit/delete) for a specific club.
  /// Matches backend verifyEventOfficer middleware (President, Secretary, Assistant Secretary only).
  bool canManageEventsOf(String clubId, {Club? club}) {
    if (role == 'admin') return true;
    final hasMembershipManager = memberships.any((m) => m.clubId == clubId && m.canManageEvents);
    if (hasMembershipManager) return true;

    // Club email fields are non-nullable String (default ''), so no ?? needed.
    if (club != null) {
      final emailLower = email.toLowerCase();
      if (club.presidentEmail.toLowerCase() == emailLower ||
          club.secretaryEmail.toLowerCase() == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Check if the user is an officer of any club (for showing management UI).
  bool get isAnyClubOfficer {
    if (role == 'admin') return true;
    return memberships.any((m) => m.isOfficer);
  }

  /// Check if the user is authorized to delete a notification.
  /// Rules:
  /// 1. Super Admin can delete any notification.
  /// 2. Teachers and Advisors CANNOT delete any notification.
  /// 3. Main Board officers of the specific club (President, Secretary, Treasurer, boardType=='main')
  ///    can delete notifications belonging to THEIR club ONLY.
  bool canDeleteNotification(String? notificationClubId, {Club? club}) {
    if (role == 'admin') return true;

    final rLower = role.toLowerCase();
    if (rLower == 'advisor' || rLower == 'teacher') return false;

    if (notificationClubId != null && notificationClubId.isNotEmpty) {
      final isMainBoardMember = memberships.any((m) =>
          m.clubId == notificationClubId &&
          (m.boardType == 'main' ||
              ['president', 'secretary', 'treasurer'].contains(m.role.toLowerCase())) &&
          !['advisor', 'teacher'].contains(m.role.toLowerCase()));
      if (isMainBoardMember) return true;

      if (club != null && club.id == notificationClubId) {
        final emailLower = email.toLowerCase();
        // Club email fields are non-nullable String (default ''), so no ?? needed.
        if (club.presidentEmail.toLowerCase() == emailLower ||
            club.secretaryEmail.toLowerCase() == emailLower ||
            club.treasurerEmail.toLowerCase() == emailLower) {
          return true;
        }
      }
    }

    return false;
  }

  /// Get the user's membership for a specific club, if any.
  UserMembership? membershipFor(String clubId) {
    final matches = memberships.where((m) => m.clubId == clubId);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Get the user's display role in a specific club.
  /// Returns the custom ClubMember role (e.g. "Coordinator", "President"),
  /// falling back to the officerRole or "Member".
  String roleInClub(String clubId) {
    final m = membershipFor(clubId);
    if (m == null) return 'Member';
    return m.role;
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final liked = (json['likedClubs'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final rolesList = (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final membershipsList = (json['memberships'] as List<dynamic>? ?? const [])
        .map((item) => UserMembership.fromJson(item as Map<String, dynamic>))
        .toList();
    return UserSession(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: json['name']?.toString() ?? 'User',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      clubId: json['clubId']?.toString(),
      clubName: json['clubName']?.toString(),
      profileImage: json['profileImage']?.toString(),
      bio: json['bio']?.toString(),
      likedClubs: liked,
      roles: rolesList,
      memberships: membershipsList,
    );
  }
}

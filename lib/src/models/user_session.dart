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
    List<String>? roles,
  })  : likedClubs = likedClubs ?? [],
        roles = roles ?? [];

  final String? id;
  final String name;
  final String email;
  final String role;
  final String? clubId;
  final String? clubName;
  final String? profileImage;
  final List<String> likedClubs;
  final List<String> roles;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final liked = (json['likedClubs'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList();
    final rolesList = (json['roles'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
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
      roles: rolesList,
    );
  }
}

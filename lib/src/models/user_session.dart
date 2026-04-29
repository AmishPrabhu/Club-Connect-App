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
  }) : likedClubs = likedClubs ?? [];

  final String? id;
  final String name;
  final String email;
  final String role;
  final String? clubId;
  final String? clubName;
  final String? profileImage;
  final List<String> likedClubs;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final liked = (json['likedClubs'] as List<dynamic>? ?? const [])
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
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/club.dart';
import '../models/notification_item.dart';
import '../models/post_item.dart';
import '../models/user_session.dart';
import '../services/api_client.dart';

class GoogleSignupData {
  GoogleSignupData({
    required this.email,
    required this.name,
    required this.credential,
  });

  final String email;
  final String name;
  final String credential;
}

class GoogleAuthResult {
  const GoogleAuthResult._({
    required this.success,
    required this.needsSignup,
    this.error,
    this.googleData,
  });

  final bool success;
  final bool needsSignup;
  final String? error;
  final GoogleSignupData? googleData;

  const GoogleAuthResult.success()
    : this._(success: true, needsSignup: false);

  const GoogleAuthResult.failure(String error)
    : this._(success: false, needsSignup: false, error: error);

  const GoogleAuthResult.cancelled()
    : this._(
        success: false,
        needsSignup: false,
        error: 'Google sign-in cancelled.',
      );

  const GoogleAuthResult.needsSignup(
    GoogleSignupData googleData, [
    String? error,
  ]) : this._(
         success: false,
         needsSignup: true,
         error: error,
         googleData: googleData,
       );
}

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  static const _tokenKey = 'club_connect_token';
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '158552043080-f7nf9tej36hgo4oidu1dnn9shkq8tan1.apps.googleusercontent.com',
  );

  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _googleServerClientId,
    scopes: ['email', 'profile'],
  );

  bool isBootstrapping = true;
  bool isLoading = false;
  String? error;

  UserSession? session;
  List<Club> clubs = const [];
  List<PostItem> posts = const [];
  List<NotificationItem> notifications = const [];

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _apiClient.setToken(token);
      try {
        session = await _fetchCurrentUser();
      } catch (_) {
        await prefs.remove(_tokenKey);
        _apiClient.setToken(null);
      }
    }

    await refreshAll();
    isBootstrapping = false;
    notifyListeners();
  }

  Future<void> refreshAll() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final clubsResponse = await _apiClient.get('/clubs') as List<dynamic>;
      final postsResponse = await _apiClient.get('/posts') as List<dynamic>;
      final notificationsResponse =
          await _apiClient.get('/notifications') as List<dynamic>;

      clubs = clubsResponse
          .map((item) => Club.fromJson(item as Map<String, dynamic>))
          .toList();
      posts = postsResponse
          .map((item) => PostItem.fromJson(item as Map<String, dynamic>))
          .toList();
      notifications = notificationsResponse
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<UserSession> login({
    required String email,
    required String password,
  }) async {
    final response =
        await _apiClient.post(
              '/auth/login',
              body: {'email': email, 'password': password},
            )
            as Map<String, dynamic>;

    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Login failed: token missing.');
    }

    _apiClient.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    session = await _fetchCurrentUser();
    await refreshAll();
    notifyListeners();
    return session!;
  }

  Future<void> sendOtp(String email) async {
    await _apiClient.post('/auth/send-otp-signup', body: {'email': email});
  }

  Future<void> verifyOtp(String email, String otp) async {
    await _apiClient.post(
      '/auth/verify-otp',
      body: {'email': email, 'otp': otp},
    );
  }

  Future<UserSession> signUp({
    required String name,
    required String email,
    required String password,
    required String otp,
  }) async {
    final response =
        await _apiClient.post(
              '/auth/signup',
              body: {
                'name': name,
                'email': email,
                'password': password,
                'otp': otp,
              },
            )
            as Map<String, dynamic>;

    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Signup failed: token missing.');
    }

    _apiClient.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    session = await _fetchCurrentUser();
    await refreshAll();
    notifyListeners();
    return session!;
  }

  Future<void> logout() async {
    session = null;
    _apiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _googleSignIn.signOut();
    await refreshAll();
  }

  Future<GoogleAuthResult> signInWithGoogle() async {
    GoogleSignInAccount? account;
    String? idToken;

    try {
      account = await _googleSignIn.signIn();
      if (account == null) {
        return const GoogleAuthResult.cancelled();
      }

      final auth = await account.authentication;
      idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw ApiException(
          'Google sign-in did not return an ID token. Make sure the app is configured with a Google OAuth client.',
        );
      }

      final response =
          await _apiClient.post('/auth/google', body: {'credential': idToken})
              as Map<String, dynamic>;
      final token = response['token']?.toString();
      if (token == null || token.isEmpty) {
        throw ApiException('Google sign-in failed: token missing.');
      }

      await _activateToken(token);
      return const GoogleAuthResult.success();
    } on ApiException catch (error) {
      final payload = error.payload;
      if (error.statusCode == 404 && payload?['code'] == 'USER_NOT_FOUND') {
        final googleData = payload?['googleData'];
        final email = googleData is Map<String, dynamic>
            ? googleData['email']?.toString() ?? account?.email ?? ''
            : account?.email ?? '';
        final name = googleData is Map<String, dynamic>
            ? googleData['name']?.toString() ?? account?.displayName ?? ''
            : account?.displayName ?? '';
        final credential = googleData is Map<String, dynamic>
            ? googleData['credential']?.toString() ?? idToken ?? ''
            : idToken ?? '';
        return GoogleAuthResult.needsSignup(
          GoogleSignupData(email: email, name: name, credential: credential),
          error.message,
        );
      }
      return GoogleAuthResult.failure(error.message);
    } catch (error) {
      return GoogleAuthResult.failure(error.toString());
    }
  }

  Future<UserSession> signUpWithGoogle({
    required String credential,
    required String password,
    String? name,
  }) async {
    final response =
        await _apiClient.post(
              '/auth/google/signup',
              body: {
                'credential': credential,
                'password': password,
                if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
              },
            )
            as Map<String, dynamic>;
    final token = response['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Google signup failed: token missing.');
    }

    return _activateToken(token);
  }

  Future<UserSession> _activateToken(String token) async {
    _apiClient.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    session = await _fetchCurrentUser();
    await refreshAll();
    notifyListeners();
    return session!;
  }

  Future<List<Map<String, dynamic>>> fetchClubMembers(String clubId) async {
    final response =
        await _apiClient.get('/clubs/$clubId/members') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<PostItem> fetchPost(String postId) async {
    final response =
        await _apiClient.get('/posts/$postId') as Map<String, dynamic>;
    return PostItem.fromJson(response);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _apiClient.put('/notifications/$notificationId/read', body: {});
    notifications = notifications.map((item) {
      if (item.id == notificationId) return item.copyWith(isRead: true);
      return item;
    }).toList();
    notifyListeners();
  }

  Future<void> toggleClubLike(String clubId) async {
    final current = session;
    if (current == null || current.id == null) {
      throw ApiException('Please sign in first.');
    }

    final isLiked = current.likedClubs.contains(clubId);
    if (isLiked) {
      await _apiClient.delete('/users/${current.id}/like/$clubId');
      current.likedClubs.remove(clubId);
    } else {
      await _apiClient.post('/users/${current.id}/like/$clubId');
      current.likedClubs.add(clubId);
    }
    notifyListeners();
  }

  Future<void> rsvpToEvent(String eventId) async {
    final current = session;
    if (current == null) {
      throw ApiException('Please sign in to RSVP.');
    }

    await _apiClient.post(
      '/posts/$eventId/rsvp',
      body: {'name': current.name, 'email': current.email},
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubTasks(String clubId) async {
    final response =
        await _apiClient.get('/tasks?clubId=$clubId') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTask({
    required String clubId,
    required String title,
    required String description,
    required List<String> assignedTo,
    required List<String> assignedToEmails,
    String? deadline,
    String? relatedEventId,
    String? relatedEventTitle,
  }) async {
    final response = await _apiClient.post(
      '/tasks',
      body: {
        'clubId': clubId,
        'title': title,
        'description': description,
        'assignedTo': assignedTo,
        'assignedToEmails': assignedToEmails,
        'deadline': deadline,
        'relatedEventId': relatedEventId,
        'relatedEventTitle': relatedEventTitle,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTask(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put('/tasks/$taskId', body: updates);
    return response as Map<String, dynamic>;
  }

  Future<void> deleteTask(String taskId) async {
    await _apiClient.delete('/tasks/$taskId');
  }

  Future<PostItem> createPost({
    required String clubId,
    required String clubName,
    required String title,
    required String content,
    required String type,
    required String status,
    String? date,
    String? time,
    String? location,
    String? coverImage,
  }) async {
    final response =
        await _apiClient.post(
              '/posts',
              body: {
                'clubId': clubId,
                'clubName': clubName,
                'title': title,
                'content': content,
                'type': type,
                'status': status,
                if (date != null) 'date': date,
                if (time != null) 'time': time,
                if (location != null) 'location': location,
                if (coverImage != null) 'coverImage': coverImage,
              },
            )
            as Map<String, dynamic>;
    final created = PostItem.fromJson(response);
    posts = [created, ...posts];
    notifyListeners();
    return created;
  }

  Future<PostItem> updatePost(
    String postId,
    Map<String, dynamic> updates,
  ) async {
    final response =
        await _apiClient.put('/posts/$postId', body: updates)
            as Map<String, dynamic>;
    final updated = PostItem.fromJson(response);
    posts = posts.map((post) => post.id == postId ? updated : post).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deletePost(String postId) async {
    await _apiClient.delete('/posts/$postId');
    posts = posts.where((post) => post.id != postId).toList();
    notifyListeners();
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? clubId,
  }) async {
    await _apiClient.post(
      '/notifications',
      body: {
        'title': title,
        'message': message,
        'type': type,
        'clubId': clubId,
        'read': false,
      },
    );
    await refreshAll();
  }

  Future<List<Map<String, dynamic>>> fetchTeachers() async {
    final response = await _apiClient.get('/users/teachers') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<Club> createClub({
    required String name,
    required String description,
    required String category,
    String fullForm = '',
    List<String> departments = const [],
    String image = '',
  }) async {
    final response =
        await _apiClient.post(
              '/clubs',
              body: {
                'name': name,
                'description': description,
                'fullForm': fullForm,
                'category': category,
                'departments': departments,
                'image': image,
                'icon': '🏛️',
              },
            )
            as Map<String, dynamic>;
    final club = Club.fromJson(response);
    clubs = [...clubs, club]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return club;
  }

  Future<Club> updateClub(
    String clubId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put('/clubs/$clubId', body: updates)
        as Map<String, dynamic>;
    final updated = Club.fromJson(response);
    clubs = clubs.map((c) => c.id == clubId ? updated : c).toList();
    notifyListeners();
    return updated;
  }

  Future<void> deleteClub(String clubId) async {
    await _apiClient.delete('/clubs/$clubId');
    clubs = clubs.where((c) => c.id != clubId).toList();
    notifyListeners();
  }

  Future<void> removeClubMember(String clubId, String memberId) async {
    await _apiClient.delete('/clubs/$clubId/members/$memberId');
  }

  Future<void> addClubMember(
    String clubId, {
    required String name,
    required String email,
    required String role,
    required String boardType,
    required String academicYear,
    required DateTime joinedAt,
  }) async {
    await _apiClient.post(
      '/clubs/$clubId/members',
      body: {
        'name': name,
        'email': email,
        'role': role,
        'boardType': boardType,
        'academicYear': academicYear,
        'joinedAt': joinedAt.toIso8601String(),
      },
    );
  }

  Future<void> updateClubMember(
    String clubId,
    String memberId,
    Map<String, dynamic> updates,
  ) async {
    await _apiClient.put('/clubs/$clubId/members/$memberId', body: updates);
  }

  Future<List<Map<String, dynamic>>> fetchTeacherClubs() async {
    final response = await _apiClient.get('/teachers/clubs') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<void> addTeacherClub(String clubId) async {
    await _apiClient.post('/teachers/clubs', body: {'clubId': clubId});
  }

  Future<void> removeTeacherClub(String clubId) async {
    await _apiClient.delete('/teachers/clubs/$clubId');
  }

  Future<List<Map<String, dynamic>>> fetchTeacherReports() async {
    final response = await _apiClient.get('/teachers/reports') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<void> assignTeacher({
    required String name,
    required String email,
  }) async {
    await _apiClient.post(
      '/users/assign-teacher',
      body: {'name': name, 'email': email},
    );
  }

  Future<void> assignOfficer({
    required String clubId,
    required String email,
    required String name,
    required String role,
  }) async {
    await _apiClient.post(
      '/auth/assign-officer',
      body: {'clubId': clubId, 'email': email, 'name': name, 'role': role},
    );

    final updates = <String, dynamic>{};
    if (role == 'club-secretary') {
      updates['secretaryEmail'] = email;
    } else if (role == 'president') {
      updates['presidentEmail'] = email;
    } else if (role == 'treasurer') {
      updates['treasurerEmail'] = email;
    } else if (role == 'advisor') {
      updates['advisorEmail'] = email;
      updates['advisorName'] = name;
    }
    await _apiClient.put('/clubs/$clubId', body: updates);
    await refreshAll();
  }

  Future<void> removeClubOfficer(String clubId, String role) async {
    await _apiClient.post(
      '/auth/remove-officer',
      body: {'clubId': clubId, 'role': role},
    );
    await refreshAll();
  }

  Future<bool> verifyEventBudget(String postId) async {
    try {
      await _apiClient.post('/posts/$postId/verify-budget');
      await refreshAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _apiClient.post('/auth/forgot-password', body: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String email,
    required String password,
  }) async {
    await _apiClient.post('/auth/reset-password', body: {
      'token': token,
      'email': email,
      'password': password,
    });
  }

  Future<void> updateProfile({
    required String name,
    String? profileImage,
  }) async {
    final current = session;
    if (current == null || current.id == null) {
      throw ApiException('Please sign in first.');
    }
    final body = <String, dynamic>{'name': name};
    if (profileImage != null) {
      body['profileImage'] = profileImage;
    }
    await _apiClient.put('/users/${current.id}', body: body);
    session = await _fetchCurrentUser();
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> requestDeleteOtp() async {
    await _apiClient.post('/auth/request-delete-otp');
  }

  Future<void> deleteAccount(String otp) async {
    await _apiClient.delete('/auth/delete-account', body: {'otp': otp});
    await logout();
  }

  Future<UserSession> _fetchCurrentUser() async {
    final response = await _apiClient.get('/auth/me') as Map<String, dynamic>;
    return UserSession.fromJson(response);
  }
}

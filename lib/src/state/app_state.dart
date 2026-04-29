import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/club.dart';
import '../models/notification_item.dart';
import '../models/post_item.dart';
import '../models/user_session.dart';
import '../services/api_client.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  static const _tokenKey = 'club_connect_token';

  final ApiClient _apiClient;

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
    await refreshAll();
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

  Future<List<Map<String, dynamic>>> fetchEventRsvps(String eventId) async {
    final response = await _apiClient.get('/posts/$eventId/rsvps') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<void> updateParticipantAttendance(
    String eventId,
    String rsvpId,
    bool attended,
  ) async {
    await _apiClient.patch(
      '/posts/$eventId/rsvps/$rsvpId',
      body: {'attended': attended, 'source': 'manual'},
    );
  }

  Future<void> saveCertificateTemplate({
    required String eventId,
    required String templateUrl,
    required double x,
    required double y,
    required double fontSize,
    required String color,
  }) async {
    await _apiClient.put(
      '/posts/$eventId/certificate-template',
      body: {
        'templateUrl': templateUrl,
        'namePosition': {
          'x': x,
          'y': y,
          'fontSize': fontSize,
          'color': color,
        }
      },
    );
  }

  Future<void> updateParticipantCertificate(
    String eventId,
    String rsvpId,
    String certificateUrl,
  ) async {
    await _apiClient.patch(
      '/posts/$eventId/rsvps/$rsvpId/certificate',
      body: {'certificateUrl': certificateUrl},
    );
  }

  Future<void> submitReport(
    String eventId,
    String reportUrl,
    String reportFilename,
  ) async {
    await _apiClient.put(
      '/posts/$eventId/report',
      body: {
        'reportUrl': reportUrl,
        'reportFilename': reportFilename,
      },
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

  Future<Map<String, dynamic>> bulkImportMembers(String clubId, String filePath) async {
    // We need to use multipart request directly since ApiClient doesn't support it natively yet
    final uri = Uri.parse('${_apiClient.baseUrl}/clubs/$clubId/members/bulk-import');
    final request = http.MultipartRequest('POST', uri);
    
    // Add auth header
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException('Bulk import failed: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchTeacherClubs() async {
    final response = await _apiClient.get('/teachers/clubs');
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> addTeacherClub(String clubId) async {
    await _apiClient.post('/teachers/clubs', body: {'clubId': clubId});
  }

  Future<void> removeTeacherClub(String clubId) async {
    await _apiClient.delete('/teachers/clubs/$clubId');
  }

  Future<List<Map<String, dynamic>>> fetchTeacherReports() async {
    final response = await _apiClient.get('/teachers/reports');
    return List<Map<String, dynamic>>.from(response.data);
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

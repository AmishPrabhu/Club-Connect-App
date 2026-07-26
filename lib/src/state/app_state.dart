import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/club.dart';
import '../models/notification_item.dart';
import '../models/post_item.dart';
import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/push_notifications_manager.dart';
import '../services/sse_service.dart';

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

  // Expose base URL so SSEService can build its endpoint URL
  String get apiBaseUrl => _apiClient.baseUrl;

  // Store current token for SSE reconnect on token refresh
  String? _currentToken;

  /// Exposes the current JWT token so [SSEService] can reconnect after lifecycle changes.
  String? get currentToken => _currentToken;

  UserSession? session;
  List<Club> clubs = const [];
  List<PostItem> posts = const [];
  List<NotificationItem> notifications = const [];
  Set<String> interestedEventIds = {};

  Future<void> bootstrap() async {
    isBootstrapping = true;
    notifyListeners();

    // Log the API URL so we can confirm it in logcat during debugging
    if (kDebugMode) {
      print('[AppState] API base URL: ${_apiClient.baseUrl}');
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _apiClient.setToken(token);
      _currentToken = token;
      try {
        session = await _fetchCurrentUser();
        // Initialize push notifications manager and sync token in the background so it doesn't block startup
        PushNotificationsManager.instance.init(this).then((_) {
          PushNotificationsManager.instance.syncToken();
        });
        // Connect SSE for real-time updates while app is open
        SSEService.instance.connect(this, token);
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

      if (session != null) {
        try {
          final interestsResponse = await _apiClient.get('/posts/user/interests') as List<dynamic>;
          interestedEventIds = interestsResponse.map((id) => id.toString()).toSet();
        } catch (_) {
          // Ignore failures for interest fetching
        }
      } else {
        interestedEventIds.clear();
      }
    } catch (err) {
      error = err.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Refreshes only the posts list — used by targeted FCM/SSE dispatch.
  Future<void> refreshPosts() async {
    try {
      final postsResponse = await _apiClient.get('/posts') as List<dynamic>;
      posts = postsResponse
          .map((item) => PostItem.fromJson(item as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  /// Refreshes only the notifications list — used by targeted FCM/SSE dispatch.
  Future<void> refreshNotifications() async {
    try {
      final notificationsResponse =
          await _apiClient.get('/notifications') as List<dynamic>;
      notifications = notificationsResponse
          .map((item) => NotificationItem.fromJson(item as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  // ─── Targeted In-Place Update Methods (called by SSEService) ────────────────

  /// Instantly prepends a newly created post without any HTTP call.
  void applyPostCreated(PostItem post) {
    // Avoid duplicates (change stream might fire twice in some edge cases)
    if (posts.any((p) => p.id == post.id)) return;
    posts = [post, ...posts];
    notifyListeners();
  }

  /// Instantly replaces an updated post in-place without any HTTP call.
  void applyPostUpdated(PostItem post) {
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx == -1) {
      // Post not in list yet — prepend it
      posts = [post, ...posts];
    } else {
      final updated = List<PostItem>.from(posts);
      updated[idx] = post;
      posts = updated;
    }
    notifyListeners();
  }

  /// Instantly removes a deleted post without any HTTP call.
  void applyPostDeleted(String id) {
    posts = posts.where((p) => p.id != id).toList();
    notifications = notifications.where((n) => n.relatedId != id).toList();
    notifyListeners();
  }

  /// Instantly prepends a new notification without any HTTP call.
  void applyNotificationCreated(NotificationItem notif) {
    if (notifications.any((n) => n.id == notif.id)) return;
    notifications = [notif, ...notifications];
    notifyListeners();

    // Show live WhatsApp-style floating alert banner when app is open
    final title = notif.title;
    final message = notif.message;
    if (title.isNotEmpty || message.isNotEmpty) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    if (message.isNotEmpty)
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Instantly updates an existing notification (e.g. read status) without HTTP.
  void applyNotificationUpdated(NotificationItem notif) {
    final idx = notifications.indexWhere((n) => n.id == notif.id);
    if (idx != -1) {
      final updated = List<NotificationItem>.from(notifications);
      updated[idx] = notif;
      notifications = updated;
      notifyListeners();
    }
  }

  /// Instantly replaces an updated club in-place without any HTTP call.
  void applyClubUpdated(Club club) {
    final idx = clubs.indexWhere((c) => c.id == club.id);
    if (idx == -1) {
      clubs = [...clubs, club]..sort((a, b) => a.name.compareTo(b.name));
    } else {
      final updated = List<Club>.from(clubs);
      updated[idx] = club;
      clubs = updated;
    }
    notifyListeners();
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
    _currentToken = token;
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
    // Unregister FCM token on logout
    await PushNotificationsManager.instance.unregisterToken();

    // Disconnect SSE stream
    SSEService.instance.disconnect();

    session = null;
    _currentToken = null;
    _apiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _googleSignIn.signOut();
    notifyListeners();
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
    _currentToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    session = await _fetchCurrentUser();

    // Initialize push notifications and sync token
    await PushNotificationsManager.instance.init(this);
    await PushNotificationsManager.instance.syncToken();

    // Connect SSE for real-time updates
    SSEService.instance.connect(this, token);

    await refreshAll();
    notifyListeners();
    return session!;
  }

  Future<void> registerFcmToken(String token) async {
    if (session == null) return;
    await _apiClient.post('/auth/fcm-token', body: {'token': token});
  }

  Future<void> unregisterFcmToken(String token) async {
    await _apiClient.delete('/auth/fcm-token', body: {'token': token});
  }

  Future<List<Map<String, dynamic>>> fetchClubMembers(
    String clubId, {
    String? termYear,
  }) async {
    final path = termYear != null && termYear.isNotEmpty
        ? '/clubs/$clubId/members?termYear=${Uri.encodeComponent(termYear)}'
        : '/clubs/$clubId/members';
    final response = await _apiClient.get(path) as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchClubTerms(String clubId) async {
    final response =
        await _apiClient.get('/clubs/$clubId/terms') as Map<String, dynamic>;
    return response;
  }

  Future<void> handoverClubTerm({
    required String clubId,
    required String newTermYear,
    required String newPresidentEmail,
    String? newSecretaryEmail,
    String? newTreasurerEmail,
    String? newPresidentRoleTitle,
  }) async {
    await _apiClient.post(
      '/clubs/$clubId/handover',
      body: {
        'newTermYear': newTermYear,
        'newPresidentEmail': newPresidentEmail,
        if (newSecretaryEmail != null && newSecretaryEmail.isNotEmpty)
          'newSecretaryEmail': newSecretaryEmail,
        if (newTreasurerEmail != null && newTreasurerEmail.isNotEmpty)
          'newTreasurerEmail': newTreasurerEmail,
        if (newPresidentRoleTitle != null && newPresidentRoleTitle.isNotEmpty)
          'newPresidentRoleTitle': newPresidentRoleTitle,
      },
    );
    await refreshAll();
  }

  Future<void> promoteClubMembers({
    required String clubId,
    required List<Map<String, dynamic>> members,
    String? targetTermYear,
  }) async {
    await _apiClient.post(
      '/clubs/$clubId/members/promote',
      body: {
        'members': members,
        if (targetTermYear != null) 'targetTermYear': targetTermYear,
      },
    );
    await refreshAll();
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
      throw ApiException('Please sign in to Register.');
    }

    await _apiClient.post(
      '/posts/$eventId/rsvp',
      body: {'name': current.name, 'email': current.email},
    );
  }

  Future<void> cancelRsvp(String eventId, String rsvpId) async {
    await _apiClient.delete('/posts/$eventId/rsvps/$rsvpId');
    await refreshAll();
  }

  Future<void> markInterested(String eventId) async {
    final current = session;
    if (current == null) {
      throw ApiException('Please sign in first.');
    }
    await _apiClient.post('/posts/$eventId/interest');
    interestedEventIds.add(eventId);
    notifyListeners();
  }

  Future<void> removeInterest(String eventId) async {
    await _apiClient.delete('/posts/$eventId/interest');
    interestedEventIds.remove(eventId);
    notifyListeners();
  }

  Future<bool> checkInterest(String eventId) async {
    return interestedEventIds.contains(eventId);
  }

  bool isInterested(String eventId) => interestedEventIds.contains(eventId);

  Future<void> submitEventReport(String postId, String reportUrl, String reportFilename) async {
    await _apiClient.put(
      '/posts/$postId/report',
      body: {'reportUrl': reportUrl, 'reportFilename': reportFilename},
    );
    await refreshAll();
  }

  Future<void> deleteEventReport(String postId) async {
    await _apiClient.delete('/posts/$postId/report');
    await refreshAll();
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
    String? timeFrom,
    String? timeTo,
    String? location,
    String? locationType,
    String? locationUrl,
    String? coverImage,
    List<String> descriptionImages = const [],
    String? registrationStart,
    String? registrationStartTime,
    String? registrationEnd,
    String? registrationEndTime,
    String? registrationLink,
    String? responseSpreadsheetUrl,
    String? eventWhatsappLink,
    String? relatedEventId,
    String? relatedEventTitle,
    int? totalSessions,
  }) async {
    final body = <String, dynamic>{
      'clubId': clubId,
      'clubName': clubName,
      'title': title,
      'content': content,
      'type': type,
      'status': status,
    };
    if (date != null) body['date'] = date;
    if (time != null) body['time'] = time;
    if (timeFrom != null) body['timeFrom'] = timeFrom;
    if (timeTo != null) body['timeTo'] = timeTo;
    if (location != null) body['location'] = location;
    if (locationType != null) body['locationType'] = locationType;
    if (locationUrl != null) body['locationUrl'] = locationUrl;
    if (coverImage != null) body['coverImage'] = coverImage;
    if (descriptionImages.isNotEmpty) body['descriptionImages'] = descriptionImages;
    if (registrationStart != null) body['registrationStart'] = registrationStart;
    if (registrationStartTime != null) body['registrationStartTime'] = registrationStartTime;
    if (registrationEnd != null) body['registrationEnd'] = registrationEnd;
    if (registrationEndTime != null) body['registrationEndTime'] = registrationEndTime;
    if (registrationLink != null) body['registrationLink'] = registrationLink;
    if (responseSpreadsheetUrl != null) body['responseSpreadsheetUrl'] = responseSpreadsheetUrl;
    if (eventWhatsappLink != null) body['eventWhatsappLink'] = eventWhatsappLink;
    if (relatedEventId != null) body['relatedEventId'] = relatedEventId;
    if (relatedEventTitle != null) body['relatedEventTitle'] = relatedEventTitle;
    if (totalSessions != null) body['totalSessions'] = totalSessions;

    final response = await _apiClient.post('/posts', body: body) as Map<String, dynamic>;
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
    notifications =
        notifications.where((notif) => notif.relatedId != postId).toList();
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
    final response = await _apiClient.get('/users/teacher/clubs') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<void> addTeacherClub(String clubId) async {
    await _apiClient.post('/users/teacher/clubs', body: {'clubId': clubId});
  }

  Future<void> removeTeacherClub(String clubId) async {
    await _apiClient.delete('/users/teacher/clubs/$clubId');
  }

  Future<List<Map<String, dynamic>>> fetchTeacherReports() async {
    final response = await _apiClient.get('/users/teacher/reports') as List<dynamic>;
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
      updates['secretaryName'] = name;
    } else if (role == 'president') {
      updates['presidentEmail'] = email;
      updates['presidentName'] = name;
    } else if (role == 'treasurer') {
      updates['treasurerEmail'] = email;
      updates['treasurerName'] = name;
    } else if (role == 'advisor') {
      updates['advisorEmail'] = email;
      updates['advisorName'] = name;
    }
    await _apiClient.put('/clubs/$clubId', body: updates);
    await refreshAll();
  }

  Future<void> removeClubOfficer(String clubId, String role) async {
    final updates = <String, dynamic>{};
    if (role == 'club-secretary') {
      updates['secretaryEmail'] = null;
      updates['secretaryId'] = null;
      updates['secretaryName'] = null;
    } else if (role == 'president') {
      updates['presidentEmail'] = null;
      updates['presidentId'] = null;
      updates['presidentName'] = null;
    } else if (role == 'treasurer') {
      updates['treasurerEmail'] = null;
      updates['treasurerId'] = null;
      updates['treasurerName'] = null;
    } else if (role == 'advisor') {
      updates['advisorEmail'] = null;
      updates['advisorId'] = null;
      updates['advisorName'] = null;
    }
    await _apiClient.put('/clubs/$clubId', body: updates);
    await refreshAll();
  }

  Future<bool> verifyEventBudget(String postId) async {
    try {
      await _apiClient.put('/posts/$postId/budget/verify');
      await refreshAll();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uploadEventBudget(String postId, String budgetImageUrl) async {
    try {
      await _apiClient.put(
        '/posts/$postId/budget',
        body: {'budgetImage': budgetImageUrl},
      );
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
    String? bio,
  }) async {
    final current = session;
    if (current == null || current.id == null) {
      throw ApiException('Please sign in first.');
    }
    final body = <String, dynamic>{'name': name};
    if (profileImage != null) {
      body['profileImage'] = profileImage;
    }
    if (bio != null) {
      body['bio'] = bio;
    }
    await _apiClient.put('/users/${current.id}', body: body);
    session = await _fetchCurrentUser();
    notifyListeners();
  }

  Future<void> deleteProfileImage() async {
    final current = session;
    if (current == null || current.id == null) {
      throw ApiException('Please sign in first.');
    }
    await updateProfile(
      name: current.name,
      profileImage: '',
      bio: current.bio,
    );
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

  Future<List<Map<String, dynamic>>> fetchClubMessages(String clubId) async {
    final response = await _apiClient.get('/clubs/$clubId/messages') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendClubMessage({
    required String clubId,
    required String title,
    required String body,
  }) async {
    final response = await _apiClient.post(
      '/clubs/$clubId/messages',
      body: {'title': title, 'body': body},
    );
    return response as Map<String, dynamic>;
  }

  Future<void> deleteNotification(String notificationId) async {
    await _apiClient.delete('/notifications/$notificationId');
    await refreshAll();
  }

  Future<void> deleteTeacher(String teacherId) async {
    await _apiClient.delete('/users/$teacherId');
    await refreshAll();
  }

  Future<UserSession> _fetchCurrentUser() async {
    final response = await _apiClient.get('/auth/me') as Map<String, dynamic>;
    return UserSession.fromJson(response);
  }

  Future<List<Map<String, dynamic>>> fetchUserRsvps() async {
    final response = await _apiClient.get('/posts/user/rsvps') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchEventRsvps(String eventId) async {
    final response = await _apiClient.get('/posts/$eventId/rsvps') as List<dynamic>;
    return response.cast<Map<String, dynamic>>();
  }

  Future<void> updateRsvpAttendance(String eventId, String rsvpId, String status, int session) async {
    await _apiClient.patch(
      '/posts/$eventId/rsvps/$rsvpId',
      body: {'status': status, 'session': session},
    );
  }

  Future<void> addEventParticipant(String eventId, String name, String email) async {
    await _apiClient.post(
      '/posts/$eventId/rsvps/add',
      body: {'name': name, 'email': email},
    );
  }

  Future<void> deleteEventParticipant(String eventId, String rsvpId) async {
    await _apiClient.delete('/posts/$eventId/rsvps/$rsvpId');
  }

  Future<void> saveCertificateTemplate(String eventId, String templateUrl, Map<String, dynamic> namePosition) async {
    await _apiClient.put(
      '/posts/$eventId/certificate-template',
      body: {'templateUrl': templateUrl, 'namePosition': namePosition},
    );
  }

  Future<void> updateParticipantCertificate(String eventId, String rsvpId, String certificateUrl) async {
    await _apiClient.patch(
      '/posts/$eventId/rsvps/$rsvpId/certificate',
      body: {'certificateUrl': certificateUrl},
    );
  }

  Future<dynamic> bulkImportMembers(String clubId, String filePath) async {
    return await _apiClient.uploadFile('/clubs/$clubId/members/bulk-import', filePath);
  }

  Future<void> downloadMemberTemplate(String savePath) async {
    await _apiClient.downloadFile('/clubs/template/members', savePath);
  }

  Future<void> exportClubMembers(String clubId, String savePath) async {
    await _apiClient.downloadFile('/clubs/$clubId/members/export', savePath);
  }

  Future<void> exportEventAttendance(String eventId, String savePath) async {
    await _apiClient.downloadFile('/posts/$eventId/rsvps/export-pdf', savePath);
  }
}

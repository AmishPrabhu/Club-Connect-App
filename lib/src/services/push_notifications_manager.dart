import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../state/app_state.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for club notifications and updates.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

class PushNotificationsManager {
  PushNotificationsManager._();
  static final PushNotificationsManager instance = PushNotificationsManager._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  AppState? _appState;
  bool _initialized = false;

  Future<void> init(AppState appState) async {
    if (_initialized) return;
    _appState = appState;

    try {
      // Initialize Firebase (for Android/iOS native bindings)
      await Firebase.initializeApp();

      // Initialize local notifications for foreground heads-up
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );
      await _localNotificationsPlugin.initialize(settings: initializationSettings);

      // Create high-importance notification channel for Android
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // Configure Firebase to display native heads-up alerts on iOS in the foreground
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Set the background messaging handler early on
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Request notification permissions (critical for iOS and Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }

      // 2. Handle foreground messages (app is open and active)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Got a message whilst in the foreground!');
          print('Message data: ${message.data}');
        }

        // Route to targeted refresh based on 'action' field in data payload.
        // This avoids fetching all 3 endpoints when only one changed.
        // NOTE: When app is foreground the SSE stream already handles most updates
        // in-place without any HTTP call. This FCM listener is a safety net.
        _applyTargetedRefresh(message.data);

        if (message.notification != null) {
          if (kDebugMode) {
            print('Message also contained a notification: ${message.notification?.title}');
          }

          // Show premium floating SnackBar alert
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          if (title.isNotEmpty || body.isNotEmpty) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Column(
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
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1E293B), // Slate dark theme color
                duration: const Duration(seconds: 4),
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }

          // Trigger native heads-up system notification card on Android/iOS
          if (!kIsWeb) {
            _localNotificationsPlugin.show(
              id: message.notification.hashCode,
              title: title,
              body: body,
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  _androidChannel.id,
                  _androidChannel.name,
                  channelDescription: _androidChannel.description,
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
              ),
            );
          }
        }
      });

      // 3. Handle when app is in background and user taps on push notification to open the app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from notification: ${message.messageId}');
        }
        _handleNotificationClick(message);
      });

      // 4. Handle when app was terminated completely and is opened via a notification click
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('App opened from terminated state via notification: ${initialMessage.messageId}');
        }
        _handleNotificationClick(initialMessage);
      }

      // 5. Listen to token refresh and update backend
      _fcm.onTokenRefresh.listen((newToken) {
        _registerToken(newToken);
      });

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase Messaging: $e');
      }
    }
  }

  /// Fetch token and register it on the server
  Future<void> syncToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }
  }

  /// Remove token from server on logout
  Future<void> unregisterToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await _appState?.unregisterFcmToken(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering FCM token: $e');
      }
    }
  }

  Future<void> _registerToken(String token) async {
    if (_appState?.session == null) return;
    try {
      await _appState?.registerFcmToken(token);
      if (kDebugMode) {
        print('Successfully registered FCM token: $token');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register FCM token: $e');
      }
    }
  }

  void _handleNotificationClick(RemoteMessage message) {
    // Use targeted refresh on notification click too
    _applyTargetedRefresh(message.data);

    // You can inspect message.data to perform navigation if needed
    // e.g. Navigator.of(context).push(MaterialPageRoute(...));
  }

  /// Routes an FCM data payload to the appropriate targeted refresh.
  /// Called for both foreground messages and notification clicks.
  void _applyTargetedRefresh(Map<String, dynamic> data) {
    final action = data['action']?.toString();

    switch (action) {
      case 'update_post':
      case 'delete_post':
        // Only refetch posts, not clubs or notifications
        _appState?.refreshPosts();
        break;
      case 'new_club_message':
        // Refresh notifications to show the new message badge
        _appState?.refreshNotifications();
        break;
      case 'certificate_ready':
        // Refresh notifications to show the certificate notification
        _appState?.refreshNotifications();
        break;
      default:
        // Unknown or no action — do a full refresh as safe fallback
        _appState?.refreshAll();
        break;
    }
  }
}

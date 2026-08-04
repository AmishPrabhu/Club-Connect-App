import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/club.dart';
import '../models/notification_item.dart';
import '../models/post_item.dart';
import '../state/app_state.dart';

/// Parses a raw SSE frame into an event name and JSON data map.
/// Returns null if the frame is incomplete or a heartbeat comment.
({String event, Map<String, dynamic> data})? _parseSseFrame(String frame) {
  String? event;
  String? dataStr;

  for (final line in frame.split('\n')) {
    if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      dataStr = line.substring(5).trim();
    }
    // lines starting with ':' are heartbeat comments — ignore
  }

  if (event == null || dataStr == null) return null;

  try {
    final data = jsonDecode(dataStr) as Map<String, dynamic>;
    return (event: event, data: data);
  } catch (_) {
    return null;
  }
}

/// SSEService
///
/// Opens a persistent HTTP stream to the server's `/api/sse` endpoint.
/// Parses incoming SSE frames and applies targeted in-place updates to [AppState].
///
/// - Starts automatically when [connect] is called (after login)
/// - Disconnects on [disconnect] (logout / app background)
/// - Auto-reconnects with exponential backoff on errors
class SSEService {
  SSEService._();
  static final SSEService instance = SSEService._();

  AppState? _appState;
  StreamSubscription<String>? _subscription;
  http.Client? _httpClient;
  bool _shouldReconnect = false;
  int _reconnectDelay = 1; // seconds
  static const int _maxReconnectDelay = 30;

  /// Call after user logs in (token is set on ApiClient).
  Future<void> connect(AppState appState, String token) async {
    if (_subscription != null) return; // already connected
    _appState = appState;
    _shouldReconnect = true;
    _reconnectDelay = 1;
    await _openStream(token);
  }

  /// Call on logout or when going deep background.
  void disconnect() {
    _shouldReconnect = false;
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close();
    _httpClient = null;
    if (kDebugMode) print('[SSE] Disconnected.');
  }

  Future<void> _openStream(String token) async {
    if (!_shouldReconnect) return;

    try {
      final baseUrl = _appState?.apiBaseUrl ?? '';
      // SSE endpoint accepts token as query param (EventSource API limitation)
      final uri = Uri.parse('$baseUrl/sse?token=${Uri.encodeComponent(token)}');

      _httpClient = http.Client();
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      if (kDebugMode) print('[SSE] Connecting to $uri');

      final streamedResponse = await _httpClient!.send(request);

      if (streamedResponse.statusCode != 200) {
        if (kDebugMode) {
          print('[SSE] Server returned ${streamedResponse.statusCode}, will retry.');
        }
        _scheduleReconnect(token);
        return;
      }

      // Reset backoff on success
      _reconnectDelay = 1;
      if (kDebugMode) print('[SSE] Connected successfully.');

      // Buffer incomplete frames
      final StringBuffer buffer = StringBuffer();

      _subscription = streamedResponse.stream
          .transform(utf8.decoder)
          .listen(
        (chunk) {
          buffer.write(chunk);
          final raw = buffer.toString();

          // SSE frames are separated by double newline
          final frames = raw.split('\n\n');

          // Last element may be incomplete — keep it in buffer
          buffer.clear();
          buffer.write(frames.last);

          for (var i = 0; i < frames.length - 1; i++) {
            final frame = frames[i].trim();
            if (frame.isEmpty || frame.startsWith(':')) continue; // heartbeat

            final parsed = _parseSseFrame(frame);
            if (parsed != null) {
              _handleEvent(parsed.event, parsed.data);
            }
          }
        },
        onError: (error) {
          if (kDebugMode) print('[SSE] Stream error: $error');
          _cleanupAndReconnect(token);
        },
        onDone: () {
          if (kDebugMode) print('[SSE] Stream closed by server.');
          _cleanupAndReconnect(token);
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (kDebugMode) print('[SSE] Connection failed: $e');
      _scheduleReconnect(token);
    }
  }

  void _cleanupAndReconnect(String token) {
    _subscription?.cancel();
    _subscription = null;
    _httpClient?.close();
    _httpClient = null;
    _scheduleReconnect(token);
  }

  void _scheduleReconnect(String token) {
    if (!_shouldReconnect) return;
    if (kDebugMode) {
      print('[SSE] Reconnecting in ${_reconnectDelay}s...');
    }
    Future.delayed(Duration(seconds: _reconnectDelay), () {
      if (_shouldReconnect) _openStream(token);
    });
    _reconnectDelay = (_reconnectDelay * 2).clamp(1, _maxReconnectDelay);
  }

  // ─── Event Dispatcher ──────────────────────────────────────────────────────

  void _handleEvent(String event, Map<String, dynamic> data) {
    if (kDebugMode) print('[SSE] Event: $event | data keys: ${data.keys.toList()}');

    final state = _appState;
    if (state == null) return;

    switch (event) {
      case 'connected':
        // Initial handshake — no UI update needed
        break;

      case 'post_created':
        try {
          final post = PostItem.fromJson(data);
          state.applyPostCreated(post);
        } catch (e) {
          if (kDebugMode) print('[SSE] post_created parse error: $e');
        }
        break;

      case 'post_updated':
        try {
          final post = PostItem.fromJson(data);
          state.applyPostUpdated(post);
        } catch (e) {
          if (kDebugMode) print('[SSE] post_updated parse error: $e');
        }
        break;

      case 'post_deleted':
        final id = data['id']?.toString() ?? data['_id']?.toString();
        if (id != null) state.applyPostDeleted(id);
        break;

      case 'notification_created':
        try {
          final notif = NotificationItem.fromJson(data);
          state.applyNotificationCreated(notif);
        } catch (e) {
          if (kDebugMode) print('[SSE] notification_created parse error: $e');
        }
        break;

      case 'notification_updated':
        // Typically a read-status update — do a lightweight refresh
        try {
          final notif = NotificationItem.fromJson(data);
          state.applyNotificationUpdated(notif);
        } catch (e) {
          if (kDebugMode) print('[SSE] notification_updated parse error: $e');
        }
        break;

      case 'club_updated':
        try {
          final club = Club.fromJson(data);
          state.applyClubUpdated(club);
        } catch (e) {
          if (kDebugMode) print('[SSE] club_updated parse error: $e');
        }
        break;

      case 'club_members_updated':
        final clubId = data['clubId']?.toString();
        if (clubId != null) {
          state.applyClubMembersUpdated(clubId);
        } else {
          // If no clubId is provided, fallback to refreshing all clubs or doing nothing.
          // In a larger app, you might trigger a global members refresh.
        }
        break;

      case 'certificate_ready':
        // Refresh notifications so the cert notification appears in inbox
        state.refreshNotifications();
        break;

      default:
        if (kDebugMode) print('[SSE] Unknown event: $event');
    }
  }
}

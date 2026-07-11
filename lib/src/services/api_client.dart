import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.payload});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? payload;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl = baseUrl ?? _getDefaultBaseUrl();

  static String _getDefaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        // Using adb reverse to map the device's port 5001 to the PC's port 5001
        return 'http://127.0.0.1:5001/api';
      }
      return 'http://127.0.0.1:5001/api';
    }
    return 'https://club-connect-7fwy.onrender.com/api';
  }

  final String baseUrl;
  final http.Client _httpClient;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Future<dynamic> get(String path) => _request('GET', path);

  Future<dynamic> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _request('DELETE', path, body: body);

  Future<dynamic> uploadFile(String path, String filePath) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    if (_token != null && _token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      dynamic payload;
      if (response.body.isNotEmpty) {
        try {
          payload = jsonDecode(response.body);
        } catch (_) {}
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payloadMap = payload is Map<String, dynamic> ? payload : null;
        final message = payloadMap?['message']?.toString() ??
            'Upload failed (${response.statusCode})';
        throw ApiException(
          message,
          statusCode: response.statusCode,
          payload: payloadMap,
        );
      }
      return payload;
    } catch (_) {
      throw ApiException(
        'Could not connect to the backend during upload. Check that the server is running.',
      );
    }
  }

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    };

    late http.Response response;
    final encoded = body == null ? null : jsonEncode(body);

    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
        case 'POST':
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: encoded,
          );
        case 'PUT':
          response = await _httpClient.put(
            uri,
            headers: headers,
            body: encoded,
          );
        case 'PATCH':
          response = await _httpClient.patch(
            uri,
            headers: headers,
            body: encoded,
          );
        case 'DELETE':
          response = await _httpClient.delete(
            uri,
            headers: headers,
            body: encoded,
          );
        default:
          throw ApiException('Unsupported method: $method');
      }
    } catch (_) {
      throw ApiException(
        'Could not connect to the backend. Check that the server is running and API_BASE_URL is correct.',
      );
    }

    dynamic payload;
    if (response.body.isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
      } catch (_) {
        // Not a JSON payload, or malformed JSON
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payloadMap = payload is Map<String, dynamic> ? payload : null;
      final message = payloadMap?['message']?.toString() ??
          'Request failed (${response.statusCode})';
      throw ApiException(
        message,
        statusCode: response.statusCode,
        payload: payloadMap,
      );
    }

    return payload;
  }
}

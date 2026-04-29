import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://club-connect-7fwy.onrender.com/api',
          );

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

    final dynamic payload = response.body.isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload is Map<String, dynamic> && payload['message'] != null
          ? payload['message'].toString()
          : 'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    }

    return payload;
  }
}

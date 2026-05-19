import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  static const Duration _timeout = Duration(seconds: 6);

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    return _baseUrlCandidates.first;
  }

  static List<String> get _baseUrlCandidates {
    if (_configuredBaseUrl.isNotEmpty) return [_configuredBaseUrl];
    if (kIsWeb) return ['http://localhost:8888'];
    if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        'http://127.0.0.1:8888',
        'http://10.0.2.2:8888',
        'http://10.0.3.2:8888',
      ];
    }
    return ['http://localhost:8888'];
  }

  String? accessToken;

  Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _send(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      request: (requestUri) => http.get(requestUri, headers: _headers()),
    );
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(
      method: 'POST',
      path: path,
      request: (requestUri) =>
          http.post(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send(
      method: 'PATCH',
      path: path,
      request: (requestUri) =>
          http.patch(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(
      method: 'PUT',
      path: path,
      request: (requestUri) =>
          http.put(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> delete(String path) async {
    return _send(
      method: 'DELETE',
      path: path,
      request: (requestUri) => http.delete(requestUri, headers: _headers()),
    );
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  String? _encode(Object? body) {
    if (body == null) return null;
    return jsonEncode(body);
  }

  Future<dynamic> _send({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    required Future<http.Response> Function(Uri uri) request,
  }) async {
    http.Response? response;
    Uri? requestUri;
    Object? lastConnectionError;
    Stopwatch? stopwatch;

    for (final candidateBaseUrl in _baseUrlCandidates) {
      requestUri = uriFor(candidateBaseUrl, path, queryParameters);
      stopwatch = Stopwatch()..start();
      _log('$method $requestUri');

      try {
        response = await request(requestUri).timeout(_timeout);
        stopwatch.stop();
        break;
      } catch (error) {
        stopwatch.stop();
        lastConnectionError = error;
        _log(
          '$method $requestUri -> connection failed in '
          '${stopwatch.elapsedMilliseconds}ms: $error',
        );
      }
    }

    if (response == null || requestUri == null || stopwatch == null) {
      _log('$method $path -> all base URLs failed: $lastConnectionError');
      throw ApiException(
        0,
        'Không thể kết nối máy chủ. Vui lòng kiểm tra backend hoặc mạng.',
      );
    }

    final decoded = _decode(response.body);
    final message = _messageFrom(decoded);
    _log(
      '$method $requestUri -> ${response.statusCode} in '
      '${stopwatch.elapsedMilliseconds}ms',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log('$method $requestUri error: ${message ?? response.body}');
      throw ApiException(
        response.statusCode,
        message ?? 'Yêu cầu không thành công. Vui lòng thử lại.',
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }

    return decoded;
  }

  Uri uriFor(
    String baseUrl,
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[API] $message');
    }
  }

  dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  String? _messageFrom(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;

    final message = decoded['message'];
    if (message is String && message.isNotEmpty) return message;

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final firstError = errors.first;
      if (firstError is Map<String, dynamic>) {
        final errorMessage = firstError['message'];
        if (errorMessage is String && errorMessage.isNotEmpty) {
          return errorMessage;
        }
      }
    }

    return null;
  }
}

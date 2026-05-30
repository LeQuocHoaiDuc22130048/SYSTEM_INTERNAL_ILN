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

enum TokenRefreshResult { success, rejected, unavailable }

class ApiClient {
  final http.Client _client;
  VoidCallback? onSessionExpired;

  ApiClient({http.Client? client, this.onSessionExpired})
    : _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 6);

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    return _baseUrlCandidates.first;
  }

  static List<String> get _baseUrlCandidates {
    if (_configuredBaseUrl.isNotEmpty) return [_configuredBaseUrl];
    if (kIsWeb) return ['http://192.168.1.152:8888'];
    if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        'http://192.168.1.152:8888',
        'http://127.0.0.1:8888',
        'http://10.0.2.2:8888',
        'http://10.0.3.2:8888',
      ];
    }
    return ['http://192.168.1.152:8888'];
  }

  String? accessToken;
  String? refreshToken;
  bool _isRefreshing = false;
  String? _lastSuccessfulBaseUrl;

  String get activeBaseUrl => _lastSuccessfulBaseUrl ?? baseUrl;

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
      request: (requestUri) => _client.get(requestUri, headers: _headers()),
    );
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(
      method: 'POST',
      path: path,
      request: (requestUri) =>
          _client.post(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String filename,
    required Uint8List bytes,
  }) async {
    return _send(
      method: 'POST',
      path: path,
      request: (requestUri) async {
        final request = http.MultipartRequest('POST', requestUri)
          ..headers.addAll({
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          })
          ..fields.addAll(fields)
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
        return http.Response.fromStream(await request.send());
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send(
      method: 'PATCH',
      path: path,
      request: (requestUri) =>
          _client.patch(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(
      method: 'PUT',
      path: path,
      request: (requestUri) =>
          _client.put(requestUri, headers: _headers(), body: _encode(body)),
    );
  }

  Future<dynamic> delete(String path) async {
    return _send(
      method: 'DELETE',
      path: path,
      request: (requestUri) => _client.delete(requestUri, headers: _headers()),
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
    Duration timeout = _timeout,
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
        response = await request(requestUri).timeout(timeout);
        stopwatch.stop();
        _lastSuccessfulBaseUrl = candidateBaseUrl;
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

    http.Response finalResponse = response;
    final decoded = _decode(finalResponse.body);
    final message = _messageFrom(decoded);
    _log(
      '$method $requestUri -> ${finalResponse.statusCode} in '
      '${stopwatch.elapsedMilliseconds}ms',
    );

    if (finalResponse.statusCode < 200 || finalResponse.statusCode >= 300) {
      if ((finalResponse.statusCode == 401 ||
              finalResponse.statusCode == 403) &&
          path != '/api/v1/auth/refresh' &&
          refreshToken != null) {
        final refreshResult = await _tryRefreshToken();
        if (refreshResult == TokenRefreshResult.success) {
          try {
            _log('Retrying $method $requestUri after token refresh');
            finalResponse = await request(requestUri).timeout(timeout);
            final decodedRetry = _decode(finalResponse.body);
            _log(
              'Retry $method $requestUri -> ${finalResponse.statusCode} in '
              '${stopwatch.elapsedMilliseconds}ms',
            );
            if (finalResponse.statusCode >= 200 &&
                finalResponse.statusCode < 300) {
              if (decodedRetry is Map<String, dynamic> &&
                  decodedRetry.containsKey('data')) {
                return decodedRetry['data'];
              }
              return decodedRetry;
            }
          } catch (e) {
            _log('Retry failed: $e');
          }
        } else if (refreshResult == TokenRefreshResult.rejected) {
          onSessionExpired?.call();
        }
      }

      _log('$method $requestUri error: ${message ?? finalResponse.body}');
      throw ApiException(
        finalResponse.statusCode,
        message ?? 'Yêu cầu không thành công. Vui lòng thử lại.',
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }

    return decoded;
  }

  Future<TokenRefreshResult> _tryRefreshToken() async {
    if (_isRefreshing) return TokenRefreshResult.unavailable;
    _isRefreshing = true;
    _log('Attempting to refresh token...');
    try {
      final refreshUri = Uri.parse('$activeBaseUrl/api/v1/auth/refresh');
      final response = await _client
          .post(
            refreshUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
          final data = decoded['data'];
          if (data is Map<String, dynamic>) {
            accessToken = data['accessToken']?.toString();
            refreshToken = data['refreshToken']?.toString();
            _log('Token refresh successful!');
            return TokenRefreshResult.success;
          }
        }
      }
      _log('Token refresh failed: status=${response.statusCode}');
      if (response.statusCode == 401 || response.statusCode == 403) {
        return TokenRefreshResult.rejected;
      }
    } catch (e) {
      _log('Token refresh error: $e');
    } finally {
      _isRefreshing = false;
    }
    return TokenRefreshResult.unavailable;
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

  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$activeBaseUrl$normalizedPath';
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

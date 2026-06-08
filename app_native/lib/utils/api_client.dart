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

  static const Duration _timeout = Duration(seconds: 12);

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const bool _allowInsecureApi = bool.fromEnvironment(
    'ALLOW_INSECURE_API',
    defaultValue: false,
  );

  static String get baseUrl {
    return _baseUrlCandidates.first;
  }

  static List<String> get _baseUrlCandidates {
    if (_configuredBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is required. For local development run Flutter with '
        '--dart-define=API_BASE_URL=http://<backend-host>:8080 '
        '--dart-define=ALLOW_INSECURE_API=true. '
        'Production must use HTTPS because biometric face data must never be '
        'sent over HTTP.',
      );
    }
    final candidates = _configuredBaseUrl
        .split(',')
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    for (final candidate in candidates) {
      _assertHttpsBaseUrl(candidate);
    }
    return candidates;
  }

  String? accessToken;
  String? refreshToken;
  bool _isRefreshing = false;
  String? _lastSuccessfulBaseUrl;

  String get activeBaseUrl => _lastSuccessfulBaseUrl ?? baseUrl;

  Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
    _assertHttpsUri(uri);
    return uri;
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

  Future<dynamic> delete(String path, {Object? body}) async {
    return _send(
      method: 'DELETE',
      path: path,
      request: (requestUri) =>
          _client.delete(requestUri, headers: _headers(), body: _encode(body)),
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
        'Khong the ket noi may chu. Hay kiem tra tablet va may backend '
        'dang cung mang WiFi, mo duoc /health, va cong 8080 khong bi firewall chan.',
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
      _assertHttpsUri(refreshUri);
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
    final uri = Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
    _assertHttpsUri(uri);
    return uri;
  }

  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      _assertHttpsUri(Uri.parse(path));
      return path;
    }
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$activeBaseUrl$normalizedPath';
  }

  static void _assertHttpsBaseUrl(String value) {
    _assertHttpsUri(Uri.parse(value));
  }

  static void _assertHttpsUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && !(_allowInsecureApi && scheme == 'http')) {
      throw StateError(
        'Blocked insecure API URL: $uri. HTTPS/TLS is required for biometric data. '
        'For local development only, run with --dart-define=ALLOW_INSECURE_API=true.',
      );
    }
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

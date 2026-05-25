import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();

  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  String? get refreshToken => api.refreshToken;
  bool get isAuthenticated => api.accessToken != null;
  bool get isLoading => _isLoading;
  UserRole get role => _currentUser?.role ?? UserRole.employee;
  bool get isEmployee => role == UserRole.employee;

  Future<void> login({
    required String username,
    required String password,
  }) async {
    await _run(() async {
      _log('Login started for username=$username');
      final data = await api.post(
        '/api/v1/auth/login',
        body: {
          'username': username,
          'password': password,
          'deviceInfo': 'flutter-app',
        },
      );

      if (data is! Map<String, dynamic>) {
        throw ApiException(500, 'Phản hồi đăng nhập không hợp lệ.');
      }

      api.accessToken = data['accessToken']?.toString();
      api.refreshToken = data['refreshToken']?.toString();

      final userInfo = data['userInfo'];
      if (api.accessToken == null || userInfo is! Map<String, dynamic>) {
        throw ApiException(500, 'Thiếu thông tin phiên đăng nhập.');
      }

      _currentUser = User.fromLoginJson(userInfo);
      _log('Login success for username=${_currentUser?.username}, role=${_currentUser?.roleLabel}');
      Future.microtask(loadMe);
    });
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    required String phone,
    String? department,
  }) async {
    await _run(() async {
      _log('Register started for username=$username');
      await api.post(
        '/api/v1/auth/register',
        body: {
          'username': username,
          'password': password,
          'fullName': fullName,
          'phone': phone,
          'department': department,
        },
      );
      _log('Register success for username=$username');
    });
  }

  Future<void> forgotPassword({
    required String username,
    required String phone,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _run(() async {
      await api.post(
        '/api/v1/auth/forgot-password',
        body: {
          'username': username,
          'phone': phone,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
    });
  }

  Future<void> loadMe() async {
    try {
      _log('Loading current user profile');
      final data = await api.get('/api/v1/employees/me');
      if (data is Map<String, dynamic>) {
        _currentUser = User.fromJson(data);
        _log('Profile loaded for username=${_currentUser?.username}');
        notifyListeners();
      }
    } catch (_) {
      _log('Profile load failed; keeping login user info');
      // Login data is enough to keep the session usable.
    }
  }

  Future<void> logout() async {
    _log('Logout started');
    final token = api.refreshToken;
    if (token != null) {
      try {
        await api.post('/api/v1/auth/logout', body: {'refreshToken': token});
      } catch (_) {
        // Local logout still clears credentials if the server is unreachable.
      }
    }

    api.accessToken = null;
    api.refreshToken = null;
    _currentUser = null;
    _log('Logout completed locally');
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _isLoading = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AUTH] $message');
    }
  }
}

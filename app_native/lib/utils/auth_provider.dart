import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_permission.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api;
  static const _userCacheKey = 'cached_user_info';
  final _secureStorage = const FlutterSecureStorage();

  AuthProvider({ApiClient? apiClient})
      : api = apiClient ?? ApiClient(secureStorage: const FlutterSecureStorage()) {
    api.onSessionExpired = _expireSession;
  }

  User? _currentUser;
  bool _isLoading = false;
  bool _isLoadingProfile = false;
  String? _profileError;
  String? _logoutWarning;

  User? get currentUser => _currentUser;
  String? get refreshToken => api.refreshToken;
  bool get isAuthenticated => api.accessToken != null;
  bool get isLoading => _isLoading;
  bool get isLoadingProfile => _isLoadingProfile;
  String? get profileError => _profileError;
  String? get logoutWarning => _logoutWarning;
  UserRole get role => _currentUser?.role ?? UserRole.employee;
  bool get isEmployee => role == UserRole.employee;
  bool get isManagerOrAbove => role.isManagerOrAbove;
  bool get isAdminOrAbove => role.isAdminOrAbove;
  bool get isAttendanceAccount =>
      _currentUser?.username.trim().toLowerCase() == 'attendance' ||
      role == UserRole.attendance;

  bool can(AppPermission permission) {
    return _currentUser?.can(permission) ?? role.can(permission);
  }

  bool canAny(Iterable<AppPermission> permissions) {
    return permissions.any(can);
  }

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
      _profileError = null;
      _logoutWarning = null;

      final userInfo = data['userInfo'];
      if (api.accessToken == null || userInfo is! Map<String, dynamic>) {
        throw ApiException(500, 'Thiếu thông tin phiên đăng nhập.');
      }

      _currentUser = User.fromLoginJson(userInfo);
      await _secureStorage.write(
        key: _userCacheKey,
        value: jsonEncode(_currentUser!.toJson()),
      );
      _log(
        'Login success for username=${_currentUser?.username}, role=${_currentUser?.roleLabel}',
      );
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
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _run(() async {
      await api.post(
        '/api/v1/auth/forgot-password',
        body: {
          'username': username,
          'phone': phone,
          'otp': otp,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );
    });
  }

  Future<void> requestPasswordResetOtp({
    required String username,
    required String phone,
  }) async {
    await _run(() async {
      await api.post(
        '/api/v1/auth/forgot-password/otp',
        body: {'username': username, 'phone': phone},
      );
    });
  }

  Future<void> updateProfile({
    required String fullName,
    String? phone,
    String? department,
    String? avatarUrl,
  }) async {
    final userId = _currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw ApiException(401, 'Phiên đăng nhập không hợp lệ.');
    }

    await _run(() async {
      final data = await api.patch(
        '/api/v1/employees/$userId',
        body: {
          'fullName': fullName,
          'phone': _emptyToNull(phone),
          'department': _emptyToNull(department),
          'avatarUrl': _emptyToNull(avatarUrl),
        },
      );

      if (data is Map<String, dynamic>) {
        _currentUser = User.fromJson(data);
      }
      await loadMe();
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _run(() async {
      await api.post(
        '/api/v1/auth/change-password',
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': confirmPassword,
        },
      );

      api.accessToken = null;
      api.refreshToken = null;
      _currentUser = null;
      _profileError = null;
      _logoutWarning = 'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.';
    });
  }

  Future<void> loadMe() async {
    _isLoadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      _log('Loading current user profile');
      final data = await api.get('/api/v1/employees/me');
      if (data is Map<String, dynamic>) {
        final loadedUser = User.fromJson(data);
        _currentUser = loadedUser.permissions == null && _currentUser != null
            ? User(
                id: loadedUser.id,
                username: loadedUser.username,
                name: loadedUser.name,
                email: loadedUser.email,
                employeeId: loadedUser.employeeId,
                role: loadedUser.role,
                status: loadedUser.status,
                avatar: loadedUser.avatar,
                department: loadedUser.department,
                phone: loadedUser.phone,
                faceEnrolled: loadedUser.faceEnrolled,
                permissions: _currentUser!.permissions,
              )
            : loadedUser;
        await _secureStorage.write(
          key: _userCacheKey,
          value: jsonEncode(_currentUser!.toJson()),
        );
        _log('Profile loaded for username=${_currentUser?.username}');
        notifyListeners();
      }
    } on ApiException catch (error) {
      _log('Profile load failed; keeping login user info');
      _profileError = error.message;
    } catch (_) {
      _log('Profile load failed; keeping login user info');
      _profileError = 'Không thể tải thông tin hồ sơ. Vui lòng thử lại.';
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _log('Logout started');
    _logoutWarning = null;
    final token = api.refreshToken;
    if (token != null) {
      try {
        await api.post('/api/v1/auth/logout', body: {'refreshToken': token});
      } catch (_) {
        _logoutWarning =
            'Đã đăng xuất trên thiết bị, nhưng máy chủ chưa xác nhận thu hồi phiên do mất kết nối.';
      }
    }

    api.accessToken = null;
    api.refreshToken = null;
    _currentUser = null;
    await _secureStorage.delete(key: _userCacheKey);
    _log('Logout completed locally');
    notifyListeners();
  }

  void _expireSession() {
    api.accessToken = null;
    api.refreshToken = null;
    _currentUser = null;
    _profileError = null;
    _secureStorage.delete(key: _userCacheKey);
    _log('Session expired because refresh token was rejected');
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    _log('Attempting auto login');
    try {
      await api.loadPersistedTokens();
      if (api.accessToken == null) {
        _log('No access token found in secure storage');
        return false;
      }

      try {
        await loadMe();
      } catch (e) {
        _log('loadMe failed during auto login, will try cache: $e');
      }

      if (api.accessToken == null) {
        _log('Session was invalidated during auto login profile load');
        return false;
      }

      if (_currentUser == null) {
        final cachedUserJson = await _secureStorage.read(key: _userCacheKey);
        if (cachedUserJson != null) {
          try {
            _currentUser = User.fromJson(jsonDecode(cachedUserJson));
            _log('Loaded cached user profile offline: username=${_currentUser?.username}');
          } catch (e) {
            _log('Failed to parse cached user: $e');
          }
        }
      }

      if (_currentUser != null) {
        _log('Auto login successful for user=${_currentUser?.username}');
        return true;
      }

      _log('Auto login failed: no user profile available (online or offline)');
      api.accessToken = null;
      api.refreshToken = null;
      return false;
    } catch (e) {
      _log('Auto login failed with exception: $e');
      api.accessToken = null;
      api.refreshToken = null;
      _currentUser = null;
      notifyListeners();
      return false;
    }
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

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

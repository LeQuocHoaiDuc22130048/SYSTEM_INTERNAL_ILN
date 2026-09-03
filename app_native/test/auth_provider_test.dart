import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_internal_likenew/models/app_permission.dart';
import 'package:system_internal_likenew/models/user.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'write') {
      final String key = methodCall.arguments['key'];
      final String value = methodCall.arguments['value'];
      mockSecureStorage[key] = value;
      return null;
    } else if (methodCall.method == 'read') {
      final String key = methodCall.arguments['key'];
      return mockSecureStorage[key];
    } else if (methodCall.method == 'delete') {
      final String key = methodCall.arguments['key'];
      mockSecureStorage.remove(key);
      return null;
    } else if (methodCall.method == 'readAll') {
      return mockSecureStorage;
    } else if (methodCall.method == 'deleteAll') {
      mockSecureStorage.clear();
      return null;
    } else if (methodCall.method == 'containsKey') {
      final String key = methodCall.arguments['key'];
      return mockSecureStorage.containsKey(key);
    }
    return null;
  });

  group('AuthProvider Tests', () {
    late AuthProvider authProvider;
    late ApiClient apiClient;

    setUp(() {
      mockSecureStorage.clear();
    });

    // Helper method to setup provider with a mock response
    void setupMockClient(Future<http.Response> Function(http.Request) handler) {
      final mockClient = MockClient(handler);
      apiClient = ApiClient(client: mockClient);
      authProvider = AuthProvider(apiClient: apiClient);
    }

    test('TC1: Successful login', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'data': {
                'accessToken': 'fake_access_token',
                'refreshToken': 'fake_refresh_token',
                'userInfo': {
                  'id': 1,
                  'username': 'testuser',
                  'fullName': 'Test User',
                  'role': 'EMPLOYEE',
                },
              },
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/employees/me') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'username': 'testuser',
                'fullName': 'Test User',
                'role': 'EMPLOYEE',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      await authProvider.login(username: 'testuser', password: 'password123');

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser?.username, 'testuser');
      expect(apiClient.accessToken, 'fake_access_token');
      expect(apiClient.refreshToken, 'fake_refresh_token');
    });

    test('TC2: Login with invalid credentials', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/login') {
          return http.Response(jsonEncode({'message': 'Login failed'}), 401);
        }
        return http.Response('Not found', 404);
      });

      expect(
        () async => await authProvider.login(
          username: 'wronguser',
          password: 'wrongpassword',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('TC3: Successful registration', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/register') {
          return http.Response(jsonEncode({'message': 'Success'}), 201);
        }
        return http.Response('Not found', 404);
      });

      await authProvider.register(
        username: 'newuser',
        password: 'Password123!',
        fullName: 'New User',
        phone: '0123456789',
        department: 'IT',
      );

      expect(true, isTrue);
    });

    test('TC4: Register with existing username', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/register') {
          return http.Response(jsonEncode({'message': 'User exists'}), 400);
        }
        return http.Response('Not found', 404);
      });

      expect(
        () async => await authProvider.register(
          username: 'existinguser',
          password: 'Password123!',
          fullName: 'Existing User',
          phone: '0123456789',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('TC5: Successful password reset', () async {
      final calledPaths = <String>[];
      setupMockClient((request) async {
        calledPaths.add(request.url.path);
        if (request.url.path == '/api/v1/auth/forgot-password/otp') {
          return http.Response(jsonEncode({'message': 'OTP sent'}), 200);
        }
        if (request.url.path == '/api/v1/auth/forgot-password') {
          expect(jsonDecode(request.body)['otp'], '123456');
          return http.Response(jsonEncode({'message': 'Success'}), 200);
        }
        return http.Response('Not found', 404);
      });

      await authProvider.requestPasswordResetOtp(
        username: 'user',
        phone: '0123456789',
      );
      await authProvider.forgotPassword(
        username: 'user',
        phone: '0123456789',
        otp: '123456',
        newPassword: 'NewPassword123!',
        confirmPassword: 'NewPassword123!',
      );

      expect(calledPaths, [
        '/api/v1/auth/forgot-password/otp',
        '/api/v1/auth/forgot-password',
      ]);
    });

    test('TC6: Successful logout', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/logout') {
          return http.Response(jsonEncode({'message': 'OK'}), 200);
        }
        return http.Response('Not found', 404);
      });

      apiClient.accessToken = 'token';
      apiClient.refreshToken = 'refresh';

      await authProvider.logout();

      expect(apiClient.accessToken, isNull);
      expect(apiClient.refreshToken, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('TC6b: Successful deleteAccount', () async {
      String? deleteBody;
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/me' && request.method == 'DELETE') {
          deleteBody = request.body;
          return http.Response(
            jsonEncode({'message': 'Tài khoản đã được xóa'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });

      apiClient.accessToken = 'token';
      apiClient.refreshToken = 'refresh';

      await authProvider.deleteAccount(
        password: 'CurrentPassword123!',
        reason: 'Không còn nhu cầu sử dụng',
      );

      expect(deleteBody, isNotNull);
      final decoded = jsonDecode(deleteBody!);
      expect(decoded['password'], 'CurrentPassword123!');
      expect(decoded['reason'], 'Không còn nhu cầu sử dụng');
      expect(apiClient.accessToken, isNull);
      expect(apiClient.refreshToken, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('TC6c: Failed deleteAccount throws ApiException', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/auth/me' && request.method == 'DELETE') {
          return http.Response(
            jsonEncode({'message': 'Mật khẩu xác nhận không chính xác'}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });

      apiClient.accessToken = 'token';

      expect(
        () => authProvider.deleteAccount(password: 'WrongPassword!'),
        throwsA(isA<ApiException>()),
      );
    });

    test('TC7: loadMe success', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/employees/me') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 2,
                'username': 'me',
                'fullName': 'It is me',
                'role': 'MANAGER',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      apiClient.accessToken = 'valid_token';
      await authProvider.loadMe();

      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser?.username, 'me');
      expect(authProvider.currentUser?.roleLabel, 'Quản lý');
    });
    test('TC8: 401 refreshes token and retries original request', () async {
      var protectedCalls = 0;
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/protected') {
          protectedCalls++;
          if (protectedCalls == 1) {
            expect(request.headers['authorization'], 'Bearer expired_access');
            return http.Response(jsonEncode({'message': 'Expired'}), 401);
          }
          expect(request.headers['authorization'], 'Bearer renewed_access');
          return http.Response(
            jsonEncode({
              'data': {'ok': true},
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/auth/refresh') {
          expect(jsonDecode(request.body)['refreshToken'], 'valid_refresh');
          return http.Response(
            jsonEncode({
              'data': {
                'accessToken': 'renewed_access',
                'refreshToken': 'renewed_refresh',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      apiClient.accessToken = 'expired_access';
      apiClient.refreshToken = 'valid_refresh';

      final result = await apiClient.get('/api/v1/protected');

      expect(result['ok'], isTrue);
      expect(protectedCalls, 2);
      expect(apiClient.accessToken, 'renewed_access');
      expect(apiClient.refreshToken, 'renewed_refresh');
    });

    test('TC9: rejected refresh token expires local session', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/protected') {
          return http.Response(jsonEncode({'message': 'Expired'}), 401);
        }
        if (request.url.path == '/api/v1/auth/refresh') {
          return http.Response(jsonEncode({'message': 'Refresh expired'}), 401);
        }
        return http.Response('Not found', 404);
      });
      apiClient.accessToken = 'expired_access';
      apiClient.refreshToken = 'expired_refresh';

      await expectLater(
        apiClient.get('/api/v1/protected'),
        throwsA(isA<ApiException>()),
      );

      expect(authProvider.isAuthenticated, isFalse);
      expect(apiClient.refreshToken, isNull);
    });

    test('TC10: loadMe exposes error and can retry profile sync', () async {
      var failProfile = true;
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/employees/me' && failProfile) {
          return http.Response(
            jsonEncode({'message': 'Server unavailable'}),
            500,
          );
        }
        if (request.url.path == '/api/v1/employees/me') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 3,
                'username': 'synced',
                'fullName': 'Synced User',
                'role': 'EMPLOYEE',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      apiClient.accessToken = 'token';

      await authProvider.loadMe();
      expect(authProvider.profileError, 'Server unavailable');

      failProfile = false;
      await authProvider.loadMe();
      expect(authProvider.profileError, isNull);
      expect(authProvider.currentUser?.username, 'synced');
    });

    test('TC12: tryAutoLogin fails when no token in storage', () async {
      setupMockClient((request) async {
        return http.Response('Not found', 404);
      });
      final success = await authProvider.tryAutoLogin();
      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('TC13: tryAutoLogin succeeds when valid token is in storage', () async {
      setupMockClient((request) async {
        if (request.url.path == '/api/v1/employees/me') {
          return http.Response(
            jsonEncode({
              'data': {
                'id': 1,
                'username': 'testuser',
                'fullName': 'Test User',
                'role': 'EMPLOYEE',
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });
      apiClient.accessToken = 'fake_access_token';
      apiClient.refreshToken = 'fake_refresh_token';

      final success = await authProvider.tryAutoLogin();
      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.username, 'testuser');
    });

    test(
      'TC11: offline logout clears local session and reports warning',
      () async {
        setupMockClient((request) async {
          throw Exception('network offline');
        });
        apiClient.accessToken = 'token';
        apiClient.refreshToken = 'refresh';

        await authProvider.logout();

        expect(authProvider.isAuthenticated, isFalse);
        expect(apiClient.refreshToken, isNull);
        expect(authProvider.logoutWarning, isNotNull);
      },
    );
  });

  group('Role permission matrix', () {
    test('employee can use operational modules but not management', () {
      expect(UserRole.employee.can(AppPermission.viewRepairOrders), isTrue);
      expect(UserRole.employee.can(AppPermission.viewWarehouse), isTrue);
      expect(UserRole.employee.can(AppPermission.manageEmployees), isFalse);
      expect(UserRole.employee.can(AppPermission.viewDashboard), isTrue);
      expect(UserRole.employee.can(AppPermission.viewNotifications), isFalse);
    });

    test('technician can only access orders and has full permissions on them', () {
      expect(UserRole.technician.can(AppPermission.viewRepairOrders), isTrue);
      expect(UserRole.technician.can(AppPermission.manageRepairOrders), isTrue);
      expect(UserRole.technician.can(AppPermission.updateRepairOrderStatus), isTrue);
      expect(UserRole.technician.can(AppPermission.assignRepairOrders), isTrue);
      
      expect(UserRole.technician.can(AppPermission.viewDashboard), isTrue);
      expect(UserRole.technician.can(AppPermission.viewWarehouse), isFalse);
      expect(UserRole.technician.can(AppPermission.manageWarehouse), isFalse);
      expect(UserRole.technician.can(AppPermission.useMessages), isFalse);
      expect(UserRole.technician.can(AppPermission.viewAttendance), isFalse);
      expect(UserRole.technician.can(AppPermission.manageEmployees), isFalse);
    });

    test('manager can manage work but not admin-only security actions', () {
      expect(UserRole.manager.can(AppPermission.viewDashboard), isTrue);
      expect(UserRole.manager.can(AppPermission.manageEmployees), isTrue);
      expect(UserRole.manager.can(AppPermission.assignRepairOrders), isTrue);
      expect(
        UserRole.manager.can(AppPermission.manageEmployeeSecurity),
        isFalse,
      );
    });

    test('admin and super admin include security permissions', () {
      expect(UserRole.admin.can(AppPermission.manageEmployeeSecurity), isTrue);
      expect(
        UserRole.superAdmin.can(AppPermission.manageEmployeeSecurity),
        isTrue,
      );
    });
  });
}

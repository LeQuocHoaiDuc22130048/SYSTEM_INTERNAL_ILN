import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/app/app_routes.dart';
import 'package:system_inverter_likenew/screens/login_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/network_provider.dart';

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

  Widget createLoginPageWidget({required AuthProvider auth}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => BackendDataProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
      ],
      child: MaterialApp(
        home: const LoginPage(),
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('TRANG CHỦ SCREEN')),
          AppRoutes.dashboard: (_) => const Scaffold(body: Text('DASHBOARD SCREEN')),
        },
      ),
    );
  }

  testWidgets('Start page renders Login and Register buttons from Stitch design', (tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Unauthenticated'}), 401);
        }),
      ),
    );

    await tester.pumpWidget(createLoginPageWidget(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Start screen shows the Stitch action buttons by Key
    expect(find.byKey(const Key('btn-welcome-login')), findsOneWidget);
    expect(find.byKey(const Key('btn-welcome-register')), findsOneWidget);
    expect(find.text('Chính sách bảo mật'), findsWidgets);
    expect(find.text('SYSTEM INVERTER LIKENEW'), findsOneWidget);
  });

  testWidgets('Tapping Login opens bottom sheet in Login mode and can be closed', (tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Unauthenticated'}), 401);
        }),
      ),
    );

    await tester.pumpWidget(createLoginPageWidget(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Login button
    final loginBtnFinder = find.byKey(const Key('btn-welcome-login'));
    expect(loginBtnFinder, findsOneWidget);
    await tester.tap(loginBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet should be open with subtitle and username input
    expect(find.text('Nhập thông tin tài khoản để tiếp tục'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.byKey(const Key('btn-auth-submit')), findsOneWidget);

    // Tap close button (X)
    final closeBtnFinder = find.byKey(const Key('btn-auth-close'));
    expect(closeBtnFinder, findsOneWidget);
    await tester.tap(closeBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Should return to Start screen with buttons
    expect(find.byKey(const Key('btn-welcome-login')), findsOneWidget);
    expect(find.byKey(const Key('btn-welcome-register')), findsOneWidget);
  });

  testWidgets('Tapping Register opens bottom sheet in Register mode', (tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Unauthenticated'}), 401);
        }),
      ),
    );

    await tester.pumpWidget(createLoginPageWidget(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Register button
    final registerBtnFinder = find.byKey(const Key('btn-welcome-register'));
    expect(registerBtnFinder, findsOneWidget);
    await tester.tap(registerBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet should be open with register fields
    expect(find.text('Điền thông tin để đăng ký tài khoản mới'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
  });

  testWidgets('Opening modal keeps app logo visible in top area and tapping top area closes modal', (tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'message': 'Unauthenticated'}), 401);
        }),
      ),
    );

    await tester.pumpWidget(createLoginPageWidget(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Initially logo is visible
    expect(find.text('SYSTEM INVERTER LIKENEW'), findsOneWidget);

    // Open login modal
    await tester.tap(find.byKey(const Key('btn-welcome-login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Logo remains visible in top frame
    expect(find.text('SYSTEM INVERTER LIKENEW'), findsOneWidget);
    expect(find.text('Nhập thông tin tài khoản để tiếp tục'), findsOneWidget);

    // Tap in top area (Y=80) to dismiss modal
    await tester.tapAt(const Offset(195, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Modal closed, welcome buttons back
    expect(find.byKey(const Key('btn-welcome-login')), findsOneWidget);
    expect(find.byKey(const Key('btn-welcome-register')), findsOneWidget);
  });

  testWidgets('Successful login navigates to Home Screen first', (tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/login') {
            return http.Response(
              jsonEncode({
                'accessToken': 'test-token',
                'refreshToken': 'test-refresh-token',
                'userInfo': {
                  'id': '1',
                  'username': 'duc',
                  'fullName': 'Hoai Duc',
                  'role': 'EMPLOYEE',
                  'status': 'ACTIVE',
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path == '/api/v1/employees/me') {
            return http.Response(
              jsonEncode({
                'id': '1',
                'username': 'duc',
                'fullName': 'Hoai Duc',
                'role': 'EMPLOYEE',
                'status': 'ACTIVE',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(jsonEncode({'data': []}), 200);
        }),
      ),
    );

    await tester.pumpWidget(createLoginPageWidget(auth: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Login button
    await tester.tap(find.byKey(const Key('btn-welcome-login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Fill in credentials
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));
    await tester.enterText(textFields.at(0), 'duc');
    await tester.enterText(textFields.at(1), 'Password123');
    await tester.pump();

    // Submit login
    await tester.tap(find.byKey(const Key('btn-auth-submit')));
    await tester.pump();
    await tester.pumpAndSettle();

    // Should land on TRANG CHỦ SCREEN first (AppRoutes.home)
    expect(find.text('TRANG CHỦ SCREEN'), findsOneWidget);
    expect(find.text('DASHBOARD SCREEN'), findsNothing);

    // Pump to drain pending network check timeout timer (3 seconds)
    await tester.pump(const Duration(seconds: 4));
  });
}

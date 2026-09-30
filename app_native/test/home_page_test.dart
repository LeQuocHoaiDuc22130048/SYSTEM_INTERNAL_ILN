import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/navigation/main_tabs.dart';
import 'package:system_internal_likenew/screens/home_page.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/backend_data_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:system_internal_likenew/utils/update_provider.dart';

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

  Widget createHomeScreen({
    required AuthProvider auth,
    bool showBottomNav = true,
    int initialNavTab = 0,
    void Function(int)? onNavigateToTab,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => BackendDataProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
      ],
      child: MaterialApp(
        home: HomePage(
          showBottomNav: showBottomNav,
          initialNavTab: initialNavTab,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
    );
  }

  testWidgets('HomePage renders all sections matching Stitch Home Screen design', (tester) async {
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
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    await auth.login(username: 'duc', password: 'password');

    await tester.pumpWidget(createHomeScreen(auth: auth, showBottomNav: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Top bar: Location & Logo
    expect(find.text('VỊ TRÍ CỦA BẠN'), findsOneWidget);
    expect(find.text('124 Oxford St, Quận 1'), findsOneWidget);

    // 2. Greeting section
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);

    // 3. Ongoing booking card
    expect(find.text('ĐÃ XÁC NHẬN ✓'), findsOneWidget);
    expect(find.text('Bảo trì Inverter & Nạp linh kiện'), findsOneWidget);
    final ongoingCardFinder = find.ancestor(
      of: find.text('Bảo trì Inverter & Nạp linh kiện'),
      matching: find.byType(Container),
    ).first;
    final ongoingCardWidth = tester.getSize(ongoingCardFinder).width;
    expect(ongoingCardWidth, 358.0);

    // 4. Promotional banner with 3D Character image (width matches the card above it)
    expect(find.text('⚡ ƯU ĐÃI ĐẶC BIỆT'), findsOneWidget);
    expect(find.text('Bảo Trì & Sửa Chữa Inverter'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    final promoHeadline = find.text('Bảo Trì & Sửa Chữa Inverter');
    final bannerContainerFinder = find.ancestor(
      of: promoHeadline,
      matching: find.byType(Container),
    ).first;
    expect(tester.getSize(bannerContainerFinder).width, ongoingCardWidth);

    // 5. Functions section (Dashboard, Đơn, Kho, Nhắn tin, Quản lý nhân viên)
    expect(find.text('Chức năng'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Đơn'), findsOneWidget);
    expect(find.text('Kho'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Quản lý nhân viên'), findsOneWidget);

    // 6. Top Rated Experts
    expect(find.text('Kỹ thuật viên tiêu biểu'), findsOneWidget);
    expect(find.text('David Miller'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);

    // 7. Stitch Bottom Nav
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);

    // Tap Book Now button to open booking sheet
    final bookNowBtn = find.text('Đặt lịch ngay');
    expect(bookNowBtn, findsOneWidget);
    await tester.tap(bookNowBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Xác nhận đặt lịch'), findsOneWidget);
  });

  testWidgets('HomePage syncs seamlessly with ProfilePage via bottom nav and back action', (tester) async {
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
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    await auth.login(username: 'duc', password: 'password');

    await tester.pumpWidget(createHomeScreen(auth: auth, showBottomNav: true, initialNavTab: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Initially on Home page
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('Hồ sơ của tôi'), findsNothing);

    // Tap Tab 3 "Cá nhân" in the Stitch bottom nav
    final profileTabFinder = find.text('Cá nhân');
    expect(profileTabFinder, findsOneWidget);
    await tester.tap(profileTabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now synchronized and switched to Profile page
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Hoai Duc'), findsWidgets);

    // Tap Tab 1 "Trang chủ" in the Stitch bottom nav
    final homeTabFinder = find.text('Trang chủ');
    expect(homeTabFinder, findsOneWidget);
    await tester.tap(homeTabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Switched back to Home page
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('Hồ sơ của tôi'), findsNothing);

    // Switch to Profile again and test Profile's top bar back button
    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);

    final backButtonFinder = find.byIcon(LucideIcons.chevronLeft);
    expect(backButtonFinder, findsOneWidget);
    await tester.tap(backButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Returned to Home page via top bar back button
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('Hồ sơ của tôi'), findsNothing);
  });

  testWidgets('HomePage with initialNavTab: 2 opens directly to Profile and can switch to Home', (tester) async {
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
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    await auth.login(username: 'duc', password: 'password');

    await tester.pumpWidget(createHomeScreen(auth: auth, showBottomNav: true, initialNavTab: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Directly in Profile
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('Xin chào, Hoai Duc 👋'), findsNothing);

    // Tap Tab 1 "Trang chủ" in the Stitch bottom nav
    await tester.tap(find.text('Trang chủ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Switched to Home
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('Hồ sơ của tôi'), findsNothing);
  });

  testWidgets('HomePage functions section allows navigating to dashboard, đơn, kho, nhắn tin, and quản lý nhân viên', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int? navigatedTab;

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
                  'role': 'MANAGER',
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
                'role': 'MANAGER',
                'status': 'ACTIVE',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    await auth.login(username: 'duc', password: 'password');

    await tester.pumpWidget(createHomeScreen(
      auth: auth,
      showBottomNav: true,
      initialNavTab: 0,
      onNavigateToTab: (tabIndex) => navigatedTab = tabIndex,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Tap Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pump();
    expect(navigatedTab, MainTabs.dashboard);

    // 2. Tap Đơn
    await tester.tap(find.text('Đơn'));
    await tester.pump();
    expect(navigatedTab, MainTabs.repairOrders);

    // 3. Tap Kho
    await tester.tap(find.text('Kho'));
    await tester.pump();
    expect(navigatedTab, MainTabs.warehouse);

    // 4. Tap Nhắn tin
    await tester.tap(find.text('Nhắn tin'));
    await tester.pump();
    expect(navigatedTab, MainTabs.messages);

    // 5. Tap Quản lý nhân viên (Manager role has permission)
    await tester.tap(find.text('Quản lý nhân viên'));
    await tester.pump();
    expect(navigatedTab, MainTabs.employeeManagement);
  });
}


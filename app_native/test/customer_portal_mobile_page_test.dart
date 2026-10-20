import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/screens/customer_portal_mobile_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock secure storage
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
    } else if (methodCall.method == 'deleteAll') {
      mockSecureStorage.clear();
      return null;
    }
    return null;
  });

  testWidgets('CustomerPortalMobilePage renders VIP card, search bar, filters and empty state', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'test-token',
            'refreshToken': 'test-refresh-token',
            'userInfo': {
              'id': '10',
              'username': 'khachhangtest',
              'fullName': 'Cong Ty Tnhh Tu Dong Hoa Bien Tany',
              'role': 'CUSTOMER',
              'status': 'ACTIVE',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders') {
        return http.Response(
          jsonEncode({
            'content': [],
            'totalElements': 0,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);

    await auth.login(username: 'khachhangtest', password: 'password');

    bool loggedOut = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(
            onLogout: () async {
              loggedOut = true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar
    expect(find.text('CỔNG KHÁCH HÀNG'), findsOneWidget);
    expect(find.text('Theo dõi tiến độ sửa chữa thiết bị'), findsOneWidget);

    // Verify VIP Membership Card
    expect(find.text('ĐỐI TÁC DOANH NGHIỆP'), findsOneWidget);
    expect(find.text('Cong Ty Tnhh Tu Dong Hoa Bien Tany'), findsOneWidget);
    expect(find.text('Hotline Kỹ Thuật'), findsOneWidget);
    expect(find.text('Chat Zalo Tiếp Nhận'), findsOneWidget);

    // Verify Search Bar & Quick Filters
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tất cả (0)'), findsOneWidget);
    expect(find.text('Đang xử lý (0)'), findsOneWidget);
    expect(find.text('Sẵn sàng nhận (0)'), findsOneWidget);

    // Verify Empty State
    expect(find.text('Chưa có đơn sửa chữa nào'), findsOneWidget);
    expect(find.text('Liên hệ gửi máy mới'), findsOneWidget);

    // Verify Popup Menu has logout
    final popupBtn = find.byType(PopupMenuButton<String>);
    expect(popupBtn, findsOneWidget);
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Tap logout in menu
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng xuất'));
    await tester.pumpAndSettle();

    expect(loggedOut, isTrue);
  });

  testWidgets('CustomerPortalMobilePage displays order cards and opens detail sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'test-token',
            'refreshToken': 'test-refresh-token',
            'userInfo': {
              'id': '10',
              'username': 'khachhangtest',
              'fullName': 'Cong Ty Tnhh Tu Dong Hoa Bien Tany',
              'role': 'CUSTOMER',
              'status': 'ACTIVE',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders') {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'id': 'ord-123',
                'orderCode': 'SC-2026-009',
                'orderTitle': 'Sửa biến tần Schneider ATV310 7.5kW',
                'status': 'IN_PROGRESS',
                'friendlyStatus': 'Đang sửa chữa',
                'deviceCount': 2,
                'receivedDate': '2026-10-18T08:30:00',
                'expectedDeliveryDate': '2026-10-22T17:00:00',
              }
            ],
            'totalElements': 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-123') {
        return http.Response(
          jsonEncode({
            'id': 'ord-123',
            'orderCode': 'SC-2026-009',
            'orderTitle': 'Sửa biến tần Schneider ATV310 7.5kW',
            'status': 'IN_PROGRESS',
            'devices': [
              {
                'modelName': 'Schneider ATV310HD11N4E',
                'serialNumber': 'SN-SCH-99812',
                'issueDescription': 'Nổ IGBT nhánh U, mất nguồn 24V'
              }
            ],
            'updates': [
              {
                'content': 'Đã thay thế module IGBT và kích thử xung',
                'createdAt': '2026-10-18T14:20:00',
              }
            ],
            'media': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: 'khachhangtest', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(
            onLogout: () async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify order card is displayed
    expect(find.text('SC-2026-009'), findsOneWidget);
    expect(find.text('Sửa biến tần Schneider ATV310 7.5kW'), findsOneWidget);
    expect(find.text('Đang sửa chữa'), findsOneWidget);
    expect(find.text('2 thiết bị'), findsOneWidget);

    // Tap on the order card to open detail sheet
    await tester.tap(find.text('SC-2026-009'));
    await tester.pumpAndSettle();

    // Verify detail sheet opened
    expect(find.text('Chi tiết đơn hàng'), findsNothing); // Should find order code title
    expect(find.text('Schneider ATV310HD11N4E'), findsOneWidget);
    expect(find.text('SN-SCH-99812'), findsOneWidget);
    expect(find.text('Đã thay thế module IGBT và kích thử xung'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage loads and displays dynamic support contact info', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'test-token',
            'refreshToken': 'test-refresh-token',
            'userInfo': {
              'id': '10',
              'username': 'khachhangtest',
              'fullName': 'Cong Ty Tnhh Tu Dong Hoa Bien Tany',
              'role': 'CUSTOMER',
              'status': 'ACTIVE',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders') {
        return http.Response(
          jsonEncode({'content': [], 'totalElements': 0}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/support-info') {
        return http.Response(
          jsonEncode({
            'hotlineNumber': '0912345678',
            'hotlineLabel': 'Hotline Khẩn Cấp 24/7',
            'zaloUrl': 'https://zalo.me/0912345678',
            'zaloLabel': 'Chat Zalo Kỹ Thuật Viên',
            'workingHours': '07:30 - 18:00',
            'workshopAddress': '123 Đường Công Nghệ Cao, TP.HCM',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: 'khachhangtest', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(
            onLogout: () async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dynamic labels rendered
    expect(find.text('Hotline Khẩn Cấp 24/7'), findsOneWidget);
    expect(find.text('Chat Zalo Kỹ Thuật Viên'), findsOneWidget);
  });
}

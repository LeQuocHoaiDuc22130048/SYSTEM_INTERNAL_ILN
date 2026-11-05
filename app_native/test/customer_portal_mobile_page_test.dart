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
    expect(find.text('Liên hệ kỹ thuật'), findsOneWidget);
    expect(find.text('Số điện thoại: 0964 266 771'), findsOneWidget);
    expect(find.text('Gọi 0964 266 771'), findsOneWidget);
    expect(find.text('Chat Zalo Tiếp Nhận'), findsNothing);

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
                'deviceName': 'Schneider ATV310 7.5kW',
                'deviceType': 'Biến tần',
                'serialNumber': 'SN-SCH-99812',
                'description': 'Mất nguồn điều khiển',
                'status': 'PENDING',
                'deviceCount': 2,
                'receivedAt': '2026-10-18T08:30:00',
                'estimatedDone': '2026-10-22T17:00:00',
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
            'deviceName': 'Schneider ATV310 7.5kW',
            'deviceType': 'Biến tần',
            'status': 'PENDING',
            'receivedAt': '2026-10-18T08:30:00',
            'assignedTechnicianName': 'Lê Hoàng Nam',
            'devices': [
              {
                'deviceName': 'Schneider ATV310HD11N4E',
                'deviceType': 'Biến tần 3 pha',
                'serialNumber': 'SN-SCH-99812',
                'description': 'Nổ IGBT nhánh U, mất nguồn 24V',
                'status': 'CHECKING',
              }
            ],
            'updates': [
              {
                'title': 'Kiểm tra bo công suất',
                'message': 'Đã thay thế module IGBT và kích thử xung',
                'publishedAt': '2026-10-18T14:20:00',
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

    // Verify order card is displayed with Vietnamese status and real DB fields
    expect(find.text('SC-2026-009'), findsOneWidget);
    expect(find.text('Schneider ATV310 7.5kW (Biến tần)'), findsOneWidget);
    expect(find.text('Đã tiếp nhận'), findsOneWidget);
    expect(find.text('PENDING'), findsNothing);
    expect(find.text('2 thiết bị'), findsOneWidget);

    // Tap on the order card to open detail sheet
    await tester.tap(find.text('SC-2026-009'));
    await tester.pumpAndSettle();

    // Verify detail sheet opened with real database data and no mock labels
    expect(find.text('Schneider ATV310HD11N4E (Biến tần 3 pha)'), findsOneWidget);
    expect(find.text('SN-SCH-99812'), findsWidgets);
    expect(find.text('Tình trạng: Nổ IGBT nhánh U, mất nguồn 24V'), findsOneWidget);
    expect(find.text('Đã thay thế module IGBT và kích thử xung'), findsOneWidget);
    expect(find.text('Kỹ thuật viên: Lê Hoàng Nam'), findsOneWidget);
    expect(find.text('KTV. Nguyễn Văn An'), findsNothing);
    expect(find.text('Đã kiểm thử QC'), findsNothing);
    expect(find.text('Tải 100% OK'), findsNothing);
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
            'hotlineNumber': '0964 266 771',
            'hotlineLabel': 'Tổng đài kỹ thuật 24/7',
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

    // Verify dynamic Vietnamese label and single phone contact rendered
    expect(find.text('Tổng đài kỹ thuật 24/7'), findsOneWidget);
    expect(find.text('Số điện thoại: 0964 266 771'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage loads and displays account profile in VIP card and opens profile dialog', (tester) async {
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
              'fullName': 'Công ty TNHH Biến Tần',
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
      if (request.url.path == '/api/v1/customer/account-profile') {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'userId': '10',
                'username': 'khachhangtest',
                'contactName': 'Nguyễn Văn Tuấn',
                'phone': '0987654321',
                'email': 'tuan@bientan.vn',
                'avatarUrl': '',
                'customerId': 'cust-1',
                'customerCode': 'KH-TEST-01',
                'customerName': 'Công ty TNHH Biến Tần',
                'companyAddress': '123 Đường ABC, TP.HCM',
                'companyTaxCode': '0312345678',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        } else if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Cập nhật thành công',
              'data': {
                'userId': '10',
                'username': 'khachhangtest',
                'contactName': body['contactName'],
                'phone': body['phone'],
                'email': body['email'],
                'avatarUrl': '',
                'customerId': 'cust-1',
                'customerCode': 'KH-TEST-01',
                'customerName': 'Công ty TNHH Biến Tần',
                'companyAddress': '123 Đường ABC, TP.HCM',
                'companyTaxCode': '0312345678',
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
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

    // Verify contact name appears on VIP card
    expect(find.text('Đại diện: Nguyễn Văn Tuấn'), findsOneWidget);

    // Open popup menu and tap 'Hồ sơ cá nhân'
    final popupBtn = find.byType(PopupMenuButton<String>);
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    // Verify profile dialog opened
    expect(find.text('Thông tin tài khoản'), findsOneWidget);
    expect(find.text('KH-TEST-01'), findsOneWidget);
    expect(find.text('0312345678'), findsOneWidget);
    expect(find.text('123 Đường ABC, TP.HCM'), findsOneWidget);

    // Edit contact name
    final nameField = find.widgetWithText(TextField, 'Nguyễn Văn Tuấn');
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'Trần Minh Đức');
    await tester.pumpAndSettle();

    // Save changes
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    // Verify SnackBar and updated representation on card
    expect(find.text('Cập nhật thông tin tài khoản thành công!'), findsOneWidget);
    expect(find.text('Đại diện: Trần Minh Đức'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage displays application logo, distinct status badges, and supports time/device filtering', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
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
                'id': 'ord-1',
                'orderCode': 'SC-2026-001',
                'deviceName': 'Biến tần Fuji Mega 15kW',
                'deviceType': 'Biến tần',
                'status': 'PENDING',
                'receivedAt': '2026-11-01T10:00:00',
              },
              {
                'id': 'ord-2',
                'orderCode': 'SC-2026-002',
                'deviceName': 'PLC Siemens S7-1200',
                'deviceType': 'PLC',
                'status': 'IN_PROGRESS',
                'receivedAt': '2026-10-15T09:00:00',
              },
              {
                'id': 'ord-3',
                'orderCode': 'SC-2026-003',
                'deviceName': 'Màn hình HMI Mitsubishi GOT2000',
                'deviceType': 'HMI',
                'status': 'DELIVERED',
                'receivedAt': '2026-09-01T08:00:00',
              },
            ],
            'totalElements': 3,
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

    // 1. Verify app logo in AppBar
    final logoFinder = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == 'assets/images/app_logo.png',
    );
    expect(logoFinder, findsOneWidget);

    // 2. Verify all 3 orders and their distinct status labels
    expect(find.text('SC-2026-001'), findsOneWidget);
    expect(find.text('SC-2026-002'), findsOneWidget);
    expect(find.text('SC-2026-003'), findsOneWidget);
    expect(find.text('Đã tiếp nhận'), findsOneWidget);
    expect(find.text('Đang tiến hành sửa chữa'), findsOneWidget);
    expect(find.text('Đã bàn giao cho khách'), findsOneWidget);

    // 3. Verify filter tabs counts
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Đang xử lý (2)'), findsOneWidget); // PENDING + IN_PROGRESS
    expect(find.text('Đã bàn giao (1)'), findsOneWidget);

    // 4. Test device type filtering
    await tester.tap(find.text('Tất cả thiết bị'));
    await tester.pumpAndSettle();
    expect(find.text('Lọc theo thiết bị'), findsOneWidget);
    await tester.tap(find.text('PLC').last);
    await tester.pumpAndSettle();

    // Now only PLC order should be visible
    expect(find.text('SC-2026-002'), findsOneWidget);
    expect(find.text('SC-2026-001'), findsNothing);
    expect(find.text('SC-2026-003'), findsNothing);

    // 5. Reset filter
    expect(find.text('Xóa lọc'), findsOneWidget);
    await tester.tap(find.text('Xóa lọc'));
    await tester.pumpAndSettle();

    // All orders restored
    expect(find.text('SC-2026-001'), findsOneWidget);
    expect(find.text('SC-2026-002'), findsOneWidget);
    expect(find.text('SC-2026-003'), findsOneWidget);
  });
}

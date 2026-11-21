import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  testWidgets('CustomerPortalMobilePage renders app banner, profile partner info, search bar, filters and empty state', (tester) async {
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
      if (request.url.path == '/api/v1/banners') {
        return http.Response(
          jsonEncode([
            {
              'id': 'b1',
              'badgeText': 'ƯU ĐÃI DỊCH VỤ',
              'title': 'Bảo trì biến tần định kỳ',
              'subtitle': 'Giảm 25% phí kiểm tra & vệ sinh công nghiệp',
              'buttonText': 'Đặt lịch ngay',
              'actionType': 'BOOKING',
              'isActive': true,
              'displayOrder': 1,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/account-profile') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'customerName': 'Cong Ty Tnhh Tu Dong Hoa Bien Tany',
              'customerCode': 'KH-6f791dd82cd54f6ea4fd1bfe97860701',
              'contactName': 'Anh Bientan',
              'phone': '0988776655',
              'email': 'admin@autotech.vn',
              'username': 'khachhangtest',
            },
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

    // Verify Banner Management carousel replaces old VIP hero & metrics card
    expect(find.text('Bảo trì biến tần định kỳ'), findsOneWidget);
    expect(find.text('Đơn sửa chữa'), findsNothing);
    expect(find.text('Đang thực hiện'), findsNothing);
    expect(find.text('ĐỐI TÁC DOANH NGHIỆP'), findsNothing);
    expect(find.text('Chat Zalo Tiếp Nhận'), findsNothing);

    // Verify Search Bar & Quick Filters
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(LucideIcons.qrCode), findsNothing);
    expect(find.text('Tất cả (0)'), findsOneWidget);
    expect(find.text('Đang xử lý (0)'), findsOneWidget);
    expect(find.text('Sẵn sàng nhận (0)'), findsOneWidget);

    // Verify Empty State
    expect(find.text('Chưa có đơn sửa chữa nào'), findsOneWidget);
    expect(find.text('Liên hệ gửi máy mới'), findsOneWidget);

    // Verify Profile dialog contains moved partner identity, copyable customer code, and call tech button
    final popupBtn = find.byType(PopupMenuButton<String>);
    expect(popupBtn, findsOneWidget);
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    expect(find.text('ĐỐI TÁC DOANH NGHIỆP'), findsOneWidget);
    expect(find.text('24/7'), findsOneWidget);
    expect(find.text('Cong Ty Tnhh Tu Dong Hoa Bien Tany'), findsWidgets);
    await tester.ensureVisible(find.text('#KH-6f791dd82cd54f6ea4fd1bfe97860701'));
    expect(find.text('#KH-6f791dd82cd54f6ea4fd1bfe97860701'), findsOneWidget);
    expect(find.text('Gọi kỹ thuật'), findsOneWidget);
    expect(find.byIcon(LucideIcons.copy), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();

    // Tap logout in menu
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();
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
    await tester.dragUntilVisible(
      find.text('Đã thay thế module IGBT và kích thử xung'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã thay thế module IGBT và kích thử xung'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Kỹ thuật viên: Lê Hoàng Nam'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
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
    expect(find.byTooltip('Tổng đài kỹ thuật 24/7: 0964 266 771'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage loads and displays account profile in VIP card and opens profile dialog', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    String currentEmail = 'tuan@bientan.vn';
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
                'email': currentEmail,
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
          currentEmail = body['email']?.toString() ?? currentEmail;
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

    // Open popup menu and tap 'Hồ sơ cá nhân'
    final popupBtn = find.byType(PopupMenuButton<String>);
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    // Verify profile dialog opened with moved enterprise details
    expect(find.text('Thông tin tài khoản'), findsOneWidget);
    expect(find.text('ĐỐI TÁC DOANH NGHIỆP'), findsOneWidget);
    await tester.ensureVisible(find.text('#KH-TEST-01'));
    expect(find.text('#KH-TEST-01'), findsOneWidget);
    expect(find.text('0312345678'), findsOneWidget);
    expect(find.text('123 Đường ABC, TP.HCM'), findsOneWidget);
    expect(find.text('Nguyễn Văn Tuấn'), findsWidgets);

    // Contact name and phone editing fields are hidden; shown read-only in info card
    expect(find.text('Tên người liên hệ *'), findsNothing);
    expect(find.text('Số điện thoại liên hệ'), findsNothing);
    expect(find.text('Địa chỉ thư điện tử'), findsNothing);
    expect(find.text('Đã xác minh'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nguyễn Văn Tuấn'), findsNothing);
    expect(find.text('Nguyễn Văn Tuấn'), findsWidgets);
    expect(find.text('0987 654 321'), findsWidgets);

    // Edit email only
    final emailField = find.widgetWithText(TextField, 'tuan@bientan.vn');
    expect(emailField, findsOneWidget);
    await tester.enterText(emailField, 'contact@bientan.vn');
    await tester.pumpAndSettle();

    // Save changes
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
    await tester.pumpAndSettle();

    // Verify SnackBar and preserved read-only contact info when re-opening profile dialog
    expect(find.text('Cập nhật thông tin tài khoản thành công!'), findsOneWidget);
    await tester.tap(popupBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn Tuấn'), findsWidgets);
    expect(find.text('contact@bientan.vn'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Loại máy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Loại máy'));
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
    await tester.ensureVisible(find.text('Xóa lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa lọc'));
    await tester.pumpAndSettle();

    // All orders restored
    expect(find.text('SC-2026-001'), findsOneWidget);
    expect(find.text('SC-2026-002'), findsOneWidget);
    expect(find.text('SC-2026-003'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage truncates long customer code and copies full code to clipboard', (tester) async {
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
              'fullName': 'Cong Ty Tnhh Dien Cong Nghiep',
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
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'userId': '10',
              'username': 'khachhangtest',
              'contactName': 'Kỹ sư trưởng',
              'phone': '0988776655',
              'customerId': 'cust-10',
              'customerCode': 'KH-0667c50aa720',
              'customerName': 'Cong Ty Tnhh Dien Cong Nghiep',
            },
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

    // Open profile dialog where customer code is now located
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    // Verify full customer code format (#KH-0667c50aa720) is rendered and copyable
    await tester.dragUntilVisible(
      find.text('#KH-0667c50aa720'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(find.text('#KH-0667c50aa720'), findsOneWidget);

    // Tap copy button on customer code
    await tester.tap(find.text('#KH-0667c50aa720'));
    await tester.pumpAndSettle();

    // Verify copy feedback snackbar shows full customer code
    expect(find.text('Đã sao chép mã khách hàng: #KH-0667c50aa720'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage stepper consistency, delivered completion time, and vertical timeline', (tester) async {
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
                'id': 'ord-delivered-1',
                'orderCode': 'SC-2026-999',
                'deviceName': 'Biến tần Delta VFD-C2000',
                'deviceType': 'Biến tần',
                'status': 'DELIVERED',
                'receivedAt': '2026-10-10T08:00:00',
                'completedAt': '2026-10-12T14:00:00',
                'deliveredAt': '2026-10-13T16:30:00',
              },
            ],
            'totalElements': 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-delivered-1') {
        return http.Response(
          jsonEncode({
            'id': 'ord-delivered-1',
            'orderCode': 'SC-2026-999',
            'orderTitle': 'Biến tần Delta VFD-C2000',
            'status': 'DELIVERED',
            'receivedAt': '2026-10-10T08:00:00',
            'completedAt': '2026-10-12T14:00:00',
            'deliveredAt': '2026-10-13T16:30:00',
            'receivedByName': 'Nguyễn Thị Thu',
            'assignedTechnicianName': 'Trần Văn Hưng',
            'devices': [],
            'updates': [],
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

    // Verify 5-step stages on order card
    expect(find.text('Tiếp nhận'), findsWidgets);
    expect(find.text('Kiểm tra'), findsWidgets);
    expect(find.text('Sửa chữa'), findsWidgets);
    expect(find.text('Kiểm tra tải'), findsWidgets);
    expect(find.text('Bàn giao'), findsWidgets);
    expect(find.text('đã bàn giao'), findsOneWidget);

    // Tap order to open detail sheet
    await tester.tap(find.text('SC-2026-999'));
    await tester.pumpAndSettle();

    // Verify detail sheet 5-step stepper and delivery timestamp under 'Bàn giao'
    expect(find.text('Đã bàn giao cho khách'), findsWidgets);
    expect(find.text('16:30 13/10/2026'), findsWidgets);

    // Scroll to see technical timeline and empty media section
    await tester.ensureVisible(find.text('Tiếp nhận thiết bị tại xưởng'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp nhận thiết bị tại xưởng'), findsOneWidget);
    expect(find.text('Người tiếp nhận: Nguyễn Thị Thu'), findsOneWidget);

    await tester.ensureVisible(find.text('Kỹ thuật viên sẽ cập nhật ảnh sau khi đo kiểm'));
    await tester.pumpAndSettle();
    expect(find.text('Kỹ thuật viên sẽ cập nhật ảnh sau khi đo kiểm'), findsOneWidget);
    expect(find.text('Hình ảnh bo mạch, xung kích IGBT và tem kiểm định tải sẽ xuất hiện tại đây khi nghiệm thu.'), findsOneWidget);
  });

  testWidgets('CustomerPortalMobilePage profile menu uses modern layout, formatted phone, dividers, and synced notification dot', (tester) async {
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
              'username': '0964384499',
              'fullName': 'Anh Long Nha Trang',
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
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: '0964384499', password: 'password');

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

    // Avatar notification dot is shown
    expect(find.byKey(const ValueKey('avatar_notification_dot')), findsOneWidget);

    // Open profile popup menu
    final popupBtn = find.byType(PopupMenuButton<String>);
    final popupWidget = tester.widget<PopupMenuButton<String>>(popupBtn);
    final shape = popupWidget.shape as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(12));
    expect(shape.side.color, const Color(0xFFF1F5F9));
    expect(shape.side.width, 1);
    expect(popupWidget.color, Colors.white);

    await tester.tap(popupBtn);
    await tester.pumpAndSettle();

    // Formatted phone & header typography
    final phoneFinder = find.text('0964 384 499');
    expect(phoneFinder, findsOneWidget);
    final phoneText = tester.widget<Text>(phoneFinder);
    expect(phoneText.style?.fontSize, 13);
    expect(phoneText.style?.fontWeight, FontWeight.w400);
    expect(phoneText.style?.color, const Color(0xFF6B7280));

    final menuNameText = tester.widget<Text>(find.text('Anh Long Nha Trang').last);
    expect(menuNameText.style?.fontSize, 15);
    expect(menuNameText.style?.fontWeight, FontWeight.w600);
    expect(menuNameText.style?.color, const Color(0xFF111827));

    // Synced 6px red dot next to 'Hồ sơ cá nhân'
    final menuDotFinder = find.byKey(const ValueKey('profile_menu_notification_dot'));
    expect(menuDotFinder, findsOneWidget);
    final menuDotSize = tester.getSize(menuDotFinder);
    expect(menuDotSize, const Size(6, 6));

    // Menu item typography and icons
    final profileItemText = tester.widget<Text>(find.text('Hồ sơ cá nhân'));
    expect(profileItemText.style?.fontSize, 14);
    expect(profileItemText.style?.fontWeight, FontWeight.w500);

    final logoutItemText = tester.widget<Text>(find.text('Đăng xuất'));
    expect(logoutItemText.style?.fontSize, 14);
    expect(logoutItemText.style?.fontWeight, FontWeight.w500);
    expect(logoutItemText.style?.color, const Color(0xFFDC2626));

    // Two light-gray dividers (under phone and above logout)
    final dividerBoxes = find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == const Color(0xFFF1F5F9),
    );
    expect(dividerBoxes, findsNWidgets(2));

    // Hover/highlight block styling for normal & logout items
    final profileInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('Hồ sơ cá nhân'), matching: find.byType(InkWell)).first,
    );
    final changePwdInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('Đổi mật khẩu'), matching: find.byType(InkWell)).first,
    );
    final logoutInkWell = tester.widget<InkWell>(
      find.ancestor(of: find.text('Đăng xuất'), matching: find.byType(InkWell)).first,
    );
    expect(profileInkWell.borderRadius, BorderRadius.circular(8));
    expect(profileInkWell.hoverColor, const Color(0xFFF8FAFC));
    expect(changePwdInkWell.borderRadius, BorderRadius.circular(8));
    expect(changePwdInkWell.hoverColor, const Color(0xFFF8FAFC));
    expect(logoutInkWell.borderRadius, BorderRadius.circular(8));
    expect(logoutInkWell.hoverColor, const Color(0xFFFEF2F2));
  });

  testWidgets('CustomerPortalMobilePage profile email uses backend email and never falls back to username', (tester) async {
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
              'username': '0964384499',
              'fullName': 'Anh Long Nha Trang',
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
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'userId': '10',
              'username': '0964384499',
              'contactName': 'Anh Long Nha Trang',
              'phone': '0964384499',
              'email': null,
              'avatarUrl': '',
              'customerId': 'cust-1',
              'customerCode': 'KH-001',
              'customerName': 'Anh Long Nha Trang',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: '0964384499', password: 'password');

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

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ cá nhân'));
    await tester.pumpAndSettle();

    // Email TextField must be empty when backend returns null (not username '0964384499')
    expect(find.widgetWithText(TextField, '0964384499'), findsNothing);
    final emailField = tester.widget<TextField>(find.widgetWithText(TextField, 'Email'));
    expect(emailField.controller?.text, isEmpty);
  });

  testWidgets('CustomerPortalMobilePage detail stepper nodes stay horizontally aligned when receivedDate is shown', (tester) async {
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
              'username': '0964384499',
              'fullName': 'Anh Long Nha Trang',
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
                'id': 'ord-align-1',
                'orderCode': 'RO-20261106-005',
                'deviceName': 'Huawei 110ktl-m0',
                'deviceType': 'Biến tần',
                'serialNumber': '6T19B9071495',
                'status': 'CHECKING',
                'deviceCount': 1,
                'receivedAt': '2026-11-06T08:30:00',
              }
            ],
            'totalElements': 1,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-align-1') {
        return http.Response(
          jsonEncode({
            'id': 'ord-align-1',
            'orderCode': 'RO-20261106-005',
            'deviceName': 'Huawei 110ktl-m0',
            'deviceType': 'Biến tần',
            'status': 'CHECKING',
            'receivedAt': '2026-11-06T08:30:00',
            'devices': [],
            'updates': [],
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
    await auth.login(username: '0964384499', password: 'password');

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

    await tester.tap(find.text('RO-20261106-005'));
    await tester.pumpAndSettle();

    expect(find.text('Bước 2/5'), findsOneWidget);

    final stepperColumn = find.ancestor(of: find.text('Bước 2/5'), matching: find.byType(Column)).first;
    expect(find.descendant(of: stepperColumn, matching: find.text('06/11/2026')), findsOneWidget);
    final avatarFinders = find.descendant(of: stepperColumn, matching: find.byType(CircleAvatar));
    expect(avatarFinders, findsNWidgets(5));

    final ys = List.generate(5, (i) => tester.getCenter(avatarFinders.at(i)).dy);
    for (var i = 1; i < ys.length; i++) {
      expect(ys[i], closeTo(ys[0], 0.01));
    }
  });

  testWidgets('Order detail places confirm button above contact and completes approve + payment proof flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? confirmedAction;
    int? confirmedWarranty;
    bool uploadedProof = false;
    final List<String> clipboardWrites = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        final args = call.arguments as Map?;
        final text = args?['text']?.toString();
        if (text != null) {
          clipboardWrites.add(text);
        }
      }
      return null;
    });

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'fake-jwt-token',
            'refreshToken': 'fake-refresh-token',
            'userInfo': {
              'id': 'u1',
              'username': '0964384499',
              'fullName': 'A. Quang',
              'role': 'CUSTOMER',
              'status': 'ACTIVE',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/account-profile' ||
          request.url.path == '/api/v1/customer/me') {
        return http.Response(
          jsonEncode({
            'fullName': 'A. Quang',
            'contactName': 'A. Quang',
            'phone': '0964384499',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/support-info') {
        return http.Response(
          jsonEncode({'hotlineNumber': '0964266771'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders') {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'id': 'ord-confirm-1',
                'orderCode': 'RO-20261106-005',
                'deviceName': 'Huawei 110ktl-m0',
                'deviceType': 'Biến tần',
                'serialNumber': '6T19B9071495',
                'status': 'CHECKED',
                'receivedAt': '2026-11-06T08:30:00',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-confirm-1') {
        return http.Response(
          jsonEncode({
            'id': 'ord-confirm-1',
            'orderCode': 'RO-20261106-005',
            'deviceName': 'Huawei 110ktl-m0',
            'deviceType': 'Biến tần',
            'serialNumber': '6T19B9071495',
            'customerName': 'A. Quang',
            'status': 'CHECKED',
            'receivedAt': '2026-11-06T08:30:00',
            'devices': [],
            'updates': [],
            'media': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-confirm-1/confirmation') {
        return http.Response(
          jsonEncode({
            'data': {
              'orderId': 'ord-confirm-1',
              'confirmationStatus': 'PENDING_CUSTOMER',
              'warrantyMonths': 6,
              'warrantyExtraFee': 0,
              'baseAmount': 4850000,
              'totalAmount': 4850000,
              'diagnosisTags': ['Hỏng công suất vào/ra', 'Cháy relay đóng ngắt'],
              'quoteItems': [
                {'label': 'Thay thế Module Công suất (IGBT x2)', 'amount': 3200000},
                {'label': 'Cụm Relay cao tần + Phục hồi mạch DC', 'amount': 950000},
                {'label': 'Công kỹ thuật & Kiểm tra tải xưởng', 'amount': 700000},
              ],
              'bankName': 'MB Bank (Quân Đội)',
              'bankCode': 'MB',
              'accountNumber': '9964266771',
              'accountHolder': 'CONG TY TNHH KY THUAT CONG NGHE',
              'transferContent': 'RO-20261106-005 - 6T19B9071495',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-confirm-1/confirm') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        confirmedAction = payload['action']?.toString();
        confirmedWarranty = payload['warrantyMonths'] as int?;
        final extra = confirmedWarranty == 12 ? 500000 : 0;
        return http.Response(
          jsonEncode({
            'data': {
              'orderId': 'ord-confirm-1',
              'confirmationStatus': 'APPROVED',
              'warrantyMonths': confirmedWarranty ?? 6,
              'warrantyExtraFee': extra,
              'baseAmount': 4850000,
              'totalAmount': 4850000 + extra,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-confirm-1/payment-proof') {
        uploadedProof = true;
        return http.Response(
          jsonEncode({
            'data': {
              'orderId': 'ord-confirm-1',
              'confirmationStatus': 'PAYMENT_SUBMITTED',
              'warrantyMonths': 12,
              'warrantyExtraFee': 500000,
              'baseAmount': 4850000,
              'totalAmount': 5350000,
              'paymentProofFileName': 'Bien-lai-MB.png',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final fakePicker = _FakeProofImagePicker();
    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: '0964384499', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(
            onLogout: () async {},
            imagePicker: fakePicker,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('RO-20261106-005'));
    await tester.pumpAndSettle();

    final confirmBtnFinder = find.byKey(const ValueKey('order_confirm_button'));
    final contactBtnFinder = find.byKey(const ValueKey('order_contact_button'));
    expect(confirmBtnFinder, findsOneWidget);
    expect(contactBtnFinder, findsOneWidget);

    // Button "Xác nhận đơn hàng" must be positioned above "Liên hệ kỹ thuật"
    final confirmRect = tester.getRect(confirmBtnFinder);
    final contactRect = tester.getRect(contactBtnFinder);
    expect(confirmRect.bottom, lessThan(contactRect.top));

    await tester.tap(confirmBtnFinder);
    await tester.pumpAndSettle();

    // Screen 1: Báo giá & Xác nhận dịch vụ
    expect(find.text('Báo giá & Xác nhận dịch vụ'), findsOneWidget);
    expect(find.text('Hỏng công suất vào/ra'), findsOneWidget);
    expect(find.byKey(const ValueKey('quote_final_total_text')), findsOneWidget);
    expect(find.text('4.850.000 đ'), findsNWidgets(2)); // subtotal + final total

    // Switch warranty to 1 year (+500.000 đ) and verify live total update
    final warranty12Finder = find.byKey(const ValueKey('warranty_option_12m'));
    await tester.ensureVisible(warranty12Finder);
    await tester.pumpAndSettle();
    await tester.tap(warranty12Finder);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('quote_final_total_text')));
    await tester.pumpAndSettle();
    expect(find.text('5.350.000 đ'), findsOneWidget);

    // Approve & proceed to Screen 2
    await tester.tap(find.byKey(const ValueKey('quote_approve_btn')));
    await tester.pumpAndSettle();

    expect(confirmedAction, 'APPROVE');
    expect(confirmedWarranty, 12);
    expect(find.text('Xác nhận & Thanh toán đơn hàng'), findsOneWidget);
    expect(find.text('5.350.000'), findsOneWidget);
    expect(find.text('MB Bank (Quân Đội)'), findsOneWidget);

    // Copy bank account number
    await tester.ensureVisible(find.byKey(const ValueKey('copy_account_number_btn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy_account_number_btn')));
    await tester.pump();
    expect(clipboardWrites, contains('9964266771'));

    // Attempting submit without selecting proof shows validation error
    await tester.tap(find.byKey(const ValueKey('submit_payment_proof_btn')));
    await tester.pumpAndSettle();
    expect(uploadedProof, isFalse);
    expect(find.textContaining('chứng từ'), findsWidgets);

    // Pick receipt image, verify preview & remove toggle, then pick again and submit
    final pickBtn = find.byKey(const ValueKey('pick_proof_gallery_btn'));
    await tester.ensureVisible(pickBtn);
    await tester.tap(pickBtn);
    await tester.pumpAndSettle();
    expect(find.text('Bien-lai-MB.png'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('remove_proof_btn')));
    await tester.tap(find.byKey(const ValueKey('remove_proof_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Bien-lai-MB.png'), findsNothing);

    await tester.ensureVisible(pickBtn);
    await tester.tap(pickBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('submit_payment_proof_btn')));
    await tester.pumpAndSettle();
    expect(uploadedProof, isTrue);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('Order confirmation modal supports rejecting quotation with reason', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? rejectedAction;
    String? rejectedReason;

    final mockClient = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/login') {
        return http.Response(
          jsonEncode({
            'accessToken': 'fake-jwt-token',
            'refreshToken': 'fake-refresh-token',
            'userInfo': {
              'id': 'u1',
              'username': '0964384499',
              'fullName': 'A. Quang',
              'role': 'CUSTOMER',
              'status': 'ACTIVE',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/account-profile' ||
          request.url.path == '/api/v1/customer/me') {
        return http.Response(
          jsonEncode({'fullName': 'A. Quang', 'contactName': 'A. Quang', 'phone': '0964384499'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/support-info') {
        return http.Response(
          jsonEncode({'hotlineNumber': '0964266771'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders') {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'id': 'ord-rej-1',
                'orderCode': 'RO-20261106-009',
                'deviceName': 'ABB ACS580',
                'status': 'CHECKED',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-rej-1') {
        return http.Response(
          jsonEncode({
            'id': 'ord-rej-1',
            'orderCode': 'RO-20261106-009',
            'deviceName': 'ABB ACS580',
            'status': 'CHECKED',
            'devices': [],
            'updates': [],
            'media': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-rej-1/confirmation') {
        return http.Response(
          jsonEncode({
            'data': {
              'orderId': 'ord-rej-1',
              'confirmationStatus': 'PENDING_CUSTOMER',
              'warrantyMonths': 6,
              'baseAmount': 2100000,
              'totalAmount': 2100000,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/customer/orders/ord-rej-1/confirm') {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        rejectedAction = payload['action']?.toString();
        rejectedReason = payload['rejectionReason']?.toString();
        return http.Response(
          jsonEncode({
            'data': {
              'orderId': 'ord-rej-1',
              'confirmationStatus': 'REJECTED',
              'rejectionReason': rejectedReason,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient, baseUrl: 'https://test.api');
    final auth = AuthProvider(apiClient: apiClient);
    await auth.login(username: '0964384499', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(onLogout: () async {}),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('RO-20261106-009'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order_confirm_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quote_reject_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Từ chối báo giá sửa chữa?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Chi phí chưa phù hợp');
    await tester.tap(find.text('Xác nhận từ chối'));
    await tester.pumpAndSettle();

    expect(rejectedAction, 'REJECT');
    expect(rejectedReason, 'Chi phí chưa phù hợp');
  });

  testWidgets('CustomerPortalMobilePage shows pending confirmation warning only on unconfirmed active orders', (tester) async {
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
              'username': '0964384499',
              'fullName': 'Cong Ty Test',
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
                'id': 'ord-pending-1',
                'orderCode': 'RO-WARN-001',
                'deviceName': 'Biến tần Delta VFD',
                'status': 'CHECKING',
                'confirmationStatus': 'PENDING_CUSTOMER',
              },
              {
                'id': 'ord-approved-1',
                'orderCode': 'RO-OK-002',
                'deviceName': 'Biến tần Yaskawa A1000',
                'status': 'IN_PROGRESS',
                'confirmationStatus': 'APPROVED',
              },
              {
                'id': 'ord-delivered-1',
                'orderCode': 'RO-DEL-003',
                'deviceName': 'PLC Siemens S7',
                'status': 'DELIVERED',
                'confirmationStatus': 'PENDING_CUSTOMER',
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
    await auth.login(username: '0964384499', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(
          home: CustomerPortalMobilePage(onLogout: () async {}),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Cảnh báo: Chờ xác nhận'), findsOneWidget);
  });
}

class _MemoryXFile extends XFile {
  _MemoryXFile(this._data, {required String fileName})
      : _fileName = fileName,
        super.fromData(_data, name: fileName, mimeType: 'image/png');

  final Uint8List _data;
  final String _fileName;

  @override
  String get name => _fileName;

  @override
  Future<Uint8List> readAsBytes() async => _data;
}

class _FakeProofImagePicker extends ImagePicker {
  static final Uint8List _valid1x1Png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return _MemoryXFile(_valid1x1Png, fileName: 'Bien-lai-MB.png');
  }
}

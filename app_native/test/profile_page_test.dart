import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/screens/profile_page.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';
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

  Widget createProfileScreen({required AuthProvider auth}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
      ],
      child: const MaterialApp(
        home: ProfilePage(),
      ),
    );
  }

  testWidgets('ProfilePage renders all Stitch components and preserved options', (tester) async {
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
                  'username': 'alexcarter',
                  'fullName': 'Alex Carter',
                  'role': 'EMPLOYEE',
                  'status': 'ACTIVE',
                  'phone': '0901234567',
                  'department': 'Kỹ thuật Inverter',
                  'employeeCode': 'NV-0089',
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
                'username': 'alexcarter',
                'fullName': 'Alex Carter',
                'role': 'EMPLOYEE',
                'status': 'ACTIVE',
                'phone': '0901234567',
                'department': 'Kỹ thuật Inverter',
                'employeeCode': 'NV-0089',
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
    await auth.login(username: 'alexcarter', password: 'password');

    await tester.pumpWidget(createProfileScreen(auth: auth));
    await tester.pumpAndSettle();

    // 1. Top bar
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);

    // 2. Hero Section
    expect(find.text('Alex Carter'), findsOneWidget);
    expect(find.text('@alexcarter'), findsOneWidget);
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);

    // 3. Section 1: Thông tin tài khoản
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('alexcarter'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Bộ phận'), findsOneWidget);
    expect(find.text('Kỹ thuật Inverter'), findsOneWidget);
    expect(find.text('Mã nhân viên / Vai trò'), findsOneWidget);
    expect(find.text('NV-0089 (Nhân viên)'), findsOneWidget);

    // 4. Section 2: Cài đặt & Hệ thống
    expect(find.text('CÀI ĐẶT & HỆ THỐNG'), findsOneWidget);
    expect(find.text('Cài đặt tài khoản'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Kiểm tra cập nhật'), findsOneWidget);
    expect(find.text('Chính sách bảo mật'), findsOneWidget);

    // 5. Section 3: Bảo mật & Tài khoản
    expect(find.text('BẢO MẬT & TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);
    expect(find.text('Xóa tài khoản'), findsOneWidget);

    // 6. Test interaction: Tap 'Chỉnh sửa hồ sơ' opens dialog
    await tester.tap(find.text('Chỉnh sửa hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    // 7. Test interaction: Tap 'Đổi mật khẩu' opens dialog
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(find.text('Mật khẩu mới'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    // 8. Test interaction: Tap 'Đăng xuất' opens confirmation dialog
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 100);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    // 9. Test interaction: Tap 'Xóa tài khoản' opens warning dialog
    await tester.scrollUntilVisible(find.text('Xóa tài khoản'), 100);
    await tester.tap(find.text('Xóa tài khoản'));
    await tester.pumpAndSettle();
    expect(find.text('CẢNH BÁO BẢO MẬT & DỮ LIỆU:'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
  });
}

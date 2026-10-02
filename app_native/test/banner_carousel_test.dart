import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/models/app_banner.dart';
import 'package:system_internal_likenew/screens/home_page.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/backend_data_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';
import 'package:system_internal_likenew/utils/update_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStorage = {};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          mockSecureStorage[methodCall.arguments['key']] =
              methodCall.arguments['value'];
          return null;
        } else if (methodCall.method == 'read') {
          return mockSecureStorage[methodCall.arguments['key']];
        } else if (methodCall.method == 'delete') {
          mockSecureStorage.remove(methodCall.arguments['key']);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          mockSecureStorage.clear();
          return null;
        } else if (methodCall.method == 'containsKey') {
          return mockSecureStorage.containsKey(methodCall.arguments['key']);
        }
        return null;
      });

  group('AppBanner Model Tests', () {
    test('gradientColorList parses comma-separated hex strings correctly', () {
      const banner = AppBanner(
        id: 'b1',
        title: 'Test',
        gradientColors: '#FF0000,#00FF00,#0000FF',
      );
      final colors = banner.gradientColorList;
      expect(colors.length, 3);
      expect(colors[0], const Color(0xFFFF0000));
      expect(colors[1], const Color(0xFF00FF00));
      expect(colors[2], const Color(0xFF0000FF));
    });

    test('gradientColorList falls back gracefully on invalid format', () {
      const banner = AppBanner(
        id: 'b2',
        title: 'Test',
        gradientColors: 'invalid,bad_color',
      );
      final colors = banner.gradientColorList;
      expect(colors.length, 3);
      expect(colors[0], const Color(0xFF2563EB));
    });
  });

  group('HomePage Banner Dynamic Carousel Widget Tests', () {
    testWidgets('Renders dynamic banners fetched from API with carousel dots',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customBanners = [
        {
          'id': 'b-1',
          'title': 'Ưu Đãi Siêu Cấp 50%',
          'badgeText': '🔥 SIÊU HOT',
          'subtitle': 'Giảm ngay 25% GIÁ TRỊ cho đơn đặt hôm nay',
          'buttonText': 'Nhận ưu đãi',
          'actionType': 'BOOKING',
          'actionValue': 'Gói siêu cấp 50%',
          'gradientColors': '#7C3AED,#9333EA,#4F46E5',
          'displayOrder': 1,
          'isActive': true,
        },
        {
          'id': 'b-2',
          'title': 'Bảo Trì & Sửa Chữa Inverter',
          'badgeText': '⚡ ƯU ĐÃI ĐẶC BIỆT',
          'subtitle': 'Miễn phí kiểm tra thiết bị tận nơi',
          'buttonText': 'Đặt lịch ngay',
          'actionType': 'BOOKING',
          'actionValue': 'Bảo trì inverter',
          'gradientColors': '#2563EB,#4F46E5,#1D4ED8',
          'displayOrder': 2,
          'isActive': true,
        },
      ];

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
            if (request.url.path == '/api/v1/banners') {
              return http.Response(
                jsonEncode({'data': customBanners}),
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

      final backendProvider = BackendDataProvider(api: auth.api);
      await backendProvider.loadBanners();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: backendProvider),
            ChangeNotifierProvider(
                create: (_) => NotificationProvider(api: auth.api)),
            ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
          ],
          child: const MaterialApp(
            home: HomePage(showBottomNav: false),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify first banner from API renders
      expect(find.text('Ưu Đãi Siêu Cấp 50%'), findsOneWidget);
      expect(find.text('🔥 SIÊU HOT'), findsOneWidget);
      expect(find.text('Nhận ưu đãi'), findsOneWidget);

      // Tap CTA button of first banner
      final btn = find.text('Nhận ưu đãi');
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Quick booking sheet opens
      expect(find.text('Xác nhận đặt lịch'), findsOneWidget);
    });
  });
}

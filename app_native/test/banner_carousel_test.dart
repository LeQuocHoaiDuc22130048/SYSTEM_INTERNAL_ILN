import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/app_banner.dart';
import 'package:system_inverter_likenew/screens/home_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';
import 'package:system_inverter_likenew/utils/update_provider.dart';

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

    test('imagePosition parses correctly and defaults to RIGHT', () {
      const bannerDefault = AppBanner(id: 'b1', title: 'Default');
      expect(bannerDefault.imagePosition, 'RIGHT');

      final fromJsonLeft = AppBanner.fromJson({
        'id': 'b2',
        'title': 'Left',
        'imagePosition': 'LEFT',
      });
      expect(fromJsonLeft.imagePosition, 'LEFT');

      final jsonMap = fromJsonLeft.toJson();
      expect(jsonMap['imagePosition'], 'LEFT');
    });

    test('custom button position coordinates parse correctly', () {
      final banner = AppBanner.fromJson({
        'id': 'b3',
        'title': 'Custom Coordinates',
        'buttonPosition': 'CUSTOM',
        'buttonTop': 15.5,
        'buttonBottom': 20.0,
        'buttonLeft': 12.0,
        'buttonRight': 16.0,
      });

      expect(banner.buttonPosition, 'CUSTOM');
      expect(banner.buttonTop, 15.5);
      expect(banner.buttonBottom, 20.0);
      expect(banner.buttonLeft, 12.0);
      expect(banner.buttonRight, 16.0);

      final jsonMap = banner.toJson();
      expect(jsonMap['buttonTop'], 15.5);
      expect(jsonMap['buttonBottom'], 20.0);
      expect(jsonMap['buttonLeft'], 12.0);
      expect(jsonMap['buttonRight'], 16.0);
    });

    test('supports zero buttons when buttons is empty list', () {
      final banner = AppBanner.fromJson({
        'id': 'b4',
        'title': 'No Buttons',
        'buttons': [],
      });

      expect(banner.buttons.isEmpty, true);
      expect(banner.buttonText, isNull);
    });

    test('fontFamily parses correctly and defaults to Be Vietnam Pro', () {
      const bannerDefault = AppBanner(id: 'b5', title: 'Default Font');
      expect(bannerDefault.fontFamily, 'Be Vietnam Pro');

      final bannerCustom = AppBanner.fromJson({
        'id': 'b6',
        'title': 'Custom Font',
        'fontFamily': 'Montserrat',
      });
      expect(bannerCustom.fontFamily, 'Montserrat');
      expect(bannerCustom.toJson()['fontFamily'], 'Montserrat');
    });

    test('darkenOverlay parses correctly and defaults to false', () {
      const bannerDefault = AppBanner(id: 'b7', title: 'Banner Default');
      expect(bannerDefault.darkenOverlay, false);

      final bannerFromUpload = AppBanner.fromJson({
        'id': 'b8',
        'title': 'Uploaded Banner',
        'backgroundImageUrl': '/images/uploaded.png',
        'darkenOverlay': false,
      });
      expect(bannerFromUpload.darkenOverlay, false);

      final bannerWithBg = AppBanner.fromJson({
        'id': 'b9',
        'title': 'Background Banner',
        'backgroundImageUrl': '/images/bg.png',
        'darkenOverlay': true,
      });
      expect(bannerWithBg.darkenOverlay, true);
      expect(bannerWithBg.toJson()['darkenOverlay'], true);
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

    testWidgets('Single banner uses the same 2:1 aspect ratio as custom banners',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final singleBanner = [
        {
          'id': 'b-single',
          'title': 'INVERTER LIKE NEW',
          'badgeText': 'SỬA CHỮA BIẾN TẦN',
          'subtitle': '243 Quốc Lộ 1A, khu phố 4, Phường Tam Bình, TP Hồ Chí Minh',
          'buttonText': 'Liên hệ ngay',
          'actionType': 'CALL',
          'actionValue': '0702500551',
          'buttonPosition': 'CUSTOM',
          'buttonBottom': 14.0,
          'buttonLeft': 16.0,
          'gradientColors': '#2563EB,#4F46E5,#1D4ED8',
          'displayOrder': 1,
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
                jsonEncode({'data': singleBanner}),
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

      expect(find.text('INVERTER LIKE NEW'), findsOneWidget);
      expect(find.text('SỬA CHỮA BIẾN TẦN'), findsOneWidget);
      expect(find.text('Liên hệ ngay'), findsOneWidget);

      final titleFinder = find.text('INVERTER LIKE NEW');
      final bannerContainer = find.ancestor(
        of: titleFinder,
        matching: find.byType(Container),
      ).first;

      final bannerSize = tester.getSize(bannerContainer);
      expect(bannerSize.height, bannerSize.width / 2);
      expect(bannerSize.width, 346.0);
    });

    testWidgets('Multiple banners have horizontal spacing (12px total gap) between slides during transition',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final multiBanners = [
        {
          'id': 'b-1',
          'title': 'Banner 1',
          'badgeText': 'HOT',
          'subtitle': 'Sub 1',
          'displayOrder': 1,
          'isActive': true,
        },
        {
          'id': 'b-2',
          'title': 'Banner 2',
          'badgeText': 'SALE',
          'subtitle': 'Sub 2',
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
                jsonEncode({'data': multiBanners}),
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
            ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
            ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
          ],
          child: const MaterialApp(
            home: HomePage(showBottomNav: false),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.clipBehavior, Clip.hardEdge);

      final titleFinder = find.text('Banner 1');
      final bannerContainer = find.ancestor(
        of: titleFinder,
        matching: find.byType(Container),
      ).first;

      final paddingWidgetFinder = find.ancestor(
        of: bannerContainer,
        matching: find.byType(Padding),
      ).first;
      final paddingWidget = tester.widget<Padding>(paddingWidgetFinder);
      expect(paddingWidget.padding, const EdgeInsets.symmetric(horizontal: 6.0));
    });

    testWidgets('Auto-play advances to the next banner automatically after 6 seconds with smooth transition',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final multiBanners = [
        {
          'id': 'b-1',
          'title': 'Banner Alpha',
          'badgeText': 'HOT',
          'subtitle': 'Sub 1',
          'displayOrder': 1,
          'isActive': true,
        },
        {
          'id': 'b-2',
          'title': 'Banner Beta',
          'badgeText': 'SALE',
          'subtitle': 'Sub 2',
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
                jsonEncode({'data': multiBanners}),
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
            ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
            ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
          ],
          child: const MaterialApp(
            home: HomePage(showBottomNav: false),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on Banner Alpha
      expect(find.text('Banner Alpha'), findsOneWidget);

      // Advance time by 6 seconds (auto-play interval) + animation duration
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 1300));

      // Now on Banner Beta
      expect(find.text('Banner Beta'), findsOneWidget);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final pageBefore = pageView.controller!.page!;
      expect(pageBefore, equals(10081.0));

      // Advance time by another 6 seconds + animation duration
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 1300));

      // Loops forward seamlessly into Banner Alpha without rewinding
      expect(find.text('Banner Alpha'), findsOneWidget);
      expect(pageView.controller!.page, equals(10082.0));
      expect(pageView.controller!.page, greaterThan(pageBefore));
    });

    testWidgets('Manual swiping supports infinite loop backward and forward',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final multiBanners = [
        {
          'id': 'b-1',
          'title': 'Banner Alpha',
          'badgeText': 'HOT',
          'subtitle': 'Sub 1',
          'displayOrder': 1,
          'isActive': true,
        },
        {
          'id': 'b-2',
          'title': 'Banner Beta',
          'badgeText': 'SALE',
          'subtitle': 'Sub 2',
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
                  'role': 'EMPLOYEE',
                  'status': 'ACTIVE',
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (request.url.path == '/api/v1/banners') {
              return http.Response(
                jsonEncode({'data': multiBanners}),
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
            ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
            ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
          ],
          child: const MaterialApp(
            home: HomePage(showBottomNav: false),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initial banner is Banner Alpha (virtual page 10080)
      expect(find.text('Banner Alpha'), findsOneWidget);

      // Drag right to go backward into Banner Beta seamlessly
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Banner Beta'), findsOneWidget);
    });
  });
}



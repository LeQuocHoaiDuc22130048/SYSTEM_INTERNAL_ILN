import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/app/app_routes.dart';
import 'package:system_inverter_likenew/app/theme_provider.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:system_inverter_likenew/navigation/main_tabs.dart';
import 'package:system_inverter_likenew/screens/main_screen.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/chat_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';
import 'package:system_inverter_likenew/utils/update_provider.dart';
import 'package:system_inverter_likenew/widgets/navigation/mobile_navigation_bar.dart';
import 'package:system_inverter_likenew/theme/app_colors.dart';

class _AuthenticatedUser extends AuthProvider {
  _AuthenticatedUser(
    ApiClient api, {
    this.allowProfile = true,
    this.customPermissions,
  }) : super(apiClient: api);

  final bool allowProfile;
  final Set<AppPermission>? customPermissions;

  @override
  bool get isAuthenticated => true;

  @override
  bool can(AppPermission permission) {
    if (customPermissions != null) {
      return customPermissions!.contains(permission);
    }
    return permission == AppPermission.viewNotifications ||
        permission == AppPermission.useMessages ||
        (allowProfile && permission == AppPermission.viewProfile);
  }
}

void main() {
  testWidgets(
    'raised action remains tappable with a bottom inset in dark mode',
    (tester) async {
      var bookingOpened = false;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              padding: EdgeInsets.only(bottom: 34),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              bottomNavigationBar: MobileNavigationBar(
                isDark: true,
                profileSelected: true,
                onHome: () {},
                onBooking: () => bookingOpened = true,
                onProfile: () {},
              ),
            ),
          ),
        ),
      );
      final nav = find.byType(MobileNavigationBar);
      final plus = find.byIcon(LucideIcons.plus);
      final navTop = tester.getTopLeft(nav).dy;
      await tester.tapAt(Offset(tester.getCenter(plus).dx, navTop + 8));
      expect(bookingOpened, isTrue);
      final backgrounds = tester.widgetList<DecoratedBox>(
        find.descendant(of: nav, matching: find.byType(DecoratedBox)),
      );
      expect(
        backgrounds.any(
          (box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).color == AppColors.surfaceDark,
        ),
        isTrue,
      );
      expect(
        tester.getBottomRight(find.text('Cá nhân')).dy,
        lessThanOrEqualTo(tester.getBottomRight(nav).dy - 34),
      );
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openScreen(
    WidgetTester tester, {
    bool allowProfile = true,
    Set<AppPermission>? customPermissions,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/check')
              ? '{"updateAvailable":false}'
              : '[]',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final notifications = NotificationProvider(api: api);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _AuthenticatedUser(
              api,
              allowProfile: allowProfile,
              customPermissions: customPermissions,
            ),
          ),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => notifications),
          ChangeNotifierProvider(
            create: (_) =>
                ChatProvider(api: api, notificationProvider: notifications),
          ),
          ChangeNotifierProvider(create: (_) => BackendDataProvider(api: api)),
          ChangeNotifierProvider(create: (_) => UpdateProvider(api: api)),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.dashboard,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: RouteSettings(
              name: settings.name,
              arguments: MainTabs.notifications,
            ),
            builder: (_) => settings.name == AppRoutes.home
                ? const Scaffold(body: Text('Home destination'))
                : const MainScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'functional screen opens quick actions, profile and home from the common navbar',
    (tester) async {
      await openScreen(tester);
      final nav = find.byType(MobileNavigationBar);
      expect(
        find.descendant(of: nav, matching: find.text('Trang chủ')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: nav, matching: find.byIcon(LucideIcons.plus)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tạo mới & Thao tác nhanh'), findsOneWidget);
      expect(find.text('Cuộc trò chuyện mới'), findsOneWidget);
      expect(find.text('Xác nhận đặt lịch'), findsNothing);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Cá nhân')),
      );
      await tester.pumpAndSettle();
      expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
      expect(nav, findsOneWidget);
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Trang chủ')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navbar does not offer profile without permission', (
    tester,
  ) async {
    await openScreen(tester, allowProfile: false);
    final nav = find.byType(MobileNavigationBar);
    expect(
      find.descendant(of: nav, matching: find.text('Trang chủ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Cá nhân')),
      findsNothing,
    );
  });

  testWidgets(
    'quick actions sheet displays options flexibly based on user permissions',
    (tester) async {
      await openScreen(
        tester,
        customPermissions: {
          AppPermission.manageRepairOrders,
          AppPermission.manageWarehouse,
          AppPermission.viewNotifications,
        },
      );
      final nav = find.byType(MobileNavigationBar);
      await tester.tap(
        find.descendant(of: nav, matching: find.byIcon(LucideIcons.plus)),
      );
      await tester.pumpAndSettle();

      // Permitted actions must appear
      expect(find.text('Tạo đơn sửa chữa'), findsOneWidget);
      expect(find.text('Vị trí kho & Kệ hàng'), findsOneWidget);
      expect(find.text('Kho bo mạch & Linh kiện'), findsOneWidget);

      // Actions without permission must NOT appear
      expect(find.text('Cuộc trò chuyện mới'), findsNothing);
      expect(find.text('Chấm công khuôn mặt AI'), findsNothing);

      // Quick booking form is removed from general quick action sheet
      expect(find.text('Xác nhận đặt lịch'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'face attendance is hidden from quick actions even if user has viewAttendance',
    (tester) async {
      await openScreen(
        tester,
        customPermissions: {
          AppPermission.viewAttendance,
          AppPermission.useMessages,
        },
      );
      final nav = find.byType(MobileNavigationBar);
      await tester.tap(
        find.descendant(of: nav, matching: find.byIcon(LucideIcons.plus)),
      );
      await tester.pumpAndSettle();

      // Messages must appear
      expect(find.text('Cuộc trò chuyện mới'), findsOneWidget);

      // Face attendance must NOT appear because it is reserved for the attendance device
      expect(find.text('Chấm công khuôn mặt AI'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
    },
  );
}

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
import 'package:system_inverter_likenew/widgets/navigation/mobile_dashboard_app_bar.dart';
import 'package:system_inverter_likenew/theme/app_colors.dart';

class _AuthenticatedUser extends AuthProvider {
  _AuthenticatedUser(ApiClient api, {this.allowProfile = true})
    : super(apiClient: api);

  final bool allowProfile;
  @override
  bool get isAuthenticated => true;
  @override
  bool can(AppPermission permission) =>
      permission == AppPermission.viewNotifications ||
      permission == AppPermission.useMessages ||
      (allowProfile && permission == AppPermission.viewProfile);
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
      final centerBtn = find.byKey(const ValueKey('bottom-nav-booking-button'));
      expect(centerBtn, findsOneWidget);
      expect(find.byKey(const ValueKey('bottom-nav-center-logo')), findsOneWidget);
      final navTop = tester.getTopLeft(nav).dy;
      await tester.tapAt(Offset(tester.getCenter(centerBtn).dx, navTop + 8));
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
            create: (_) => _AuthenticatedUser(api, allowProfile: allowProfile),
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
    'functional screen opens booking, profile and home from the common navbar',
    (tester) async {
      await openScreen(tester);
      final nav = find.byType(MobileNavigationBar);
      expect(
        find.descendant(of: nav, matching: find.text('Trang chủ')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: nav,
          matching: find.byKey(const ValueKey('bottom-nav-booking-button')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thao tác nhanh'), findsOneWidget);
      expect(find.text('Tạo đơn sửa chữa'), findsNothing);
      await tester.tap(find.byTooltip('Đóng thao tác nhanh'));
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
      expect(find.textContaining('Xin chào,'), findsOneWidget);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'header and footer stay mounted and fixed across home, profile and notifications',
    (tester) async {
      await openScreen(tester);
      final header = find.byType(DashboardMobileAppBar);
      final footer = find.byType(MobileNavigationBar);
      final headerElement = tester.element(header);
      final footerElement = tester.element(footer);
      final headerRect = tester.getRect(header);
      final footerRect = tester.getRect(footer);
      for (final target in ['Cá nhân', 'Trang chủ']) {
        await tester.tap(
          find.descendant(of: footer, matching: find.text(target)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        expect(tester.element(header), same(headerElement));
        expect(tester.element(footer), same(footerElement));
        expect(tester.getRect(header), headerRect);
        expect(tester.getRect(footer), footerRect);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.element(header), same(headerElement));
      expect(tester.element(footer), same(footerElement));
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(footer), footerRect);
      expect(find.byType(MainScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
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

  testWidgets('center button displays app logo image instead of plus icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MobileNavigationBar(
            isDark: false,
            onHome: () {},
            onBooking: () {},
          ),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.plus), findsNothing);
    final logoFinder = find.byKey(const ValueKey('bottom-nav-center-logo'));
    expect(logoFinder, findsOneWidget);
    final imageWidget = tester.widget<Image>(logoFinder);
    expect(imageWidget.image, isA<AssetImage>());
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/app_logo.png');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    'selected tabs are pastel and profile uses neutral or blue accents',
    (tester) async {
      for (final selected in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: MobileNavigationBar(
                isDark: false,
                homeSelected: true,
                profileSelected: selected,
                onHome: () {},
                onBooking: () {},
                onProfile: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final home = find.byKey(const ValueKey('bottom-nav-home-tab'));
        final background =
            tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: home,
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(
          background.color,
          const Color(0xFF2563EB).withValues(alpha: 0.12),
        );
        expect(background.boxShadow, isNull);
        expect(
          tester.widget<Icon>(find.byIcon(LucideIcons.house)).color,
          const Color(0xFF2563EB),
        );
        final avatar = tester.widget<Container>(
          find.byKey(const ValueKey('bottom-account-avatar')),
        );
        final decoration = avatar.decoration! as BoxDecoration;
        final accent = selected
            ? const Color(0xFF2563EB)
            : const Color(0xFF64748B);
        expect((decoration.border! as Border).top.color, accent);
        expect(tester.widget<Text>(find.text('U')).style!.color, accent);
        expect(tester.widget<Text>(find.text('Cá nhân')).style!.color, accent);
      }
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('all five labels share a baseline at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(bottom: 34),
            ),
            child: Scaffold(
              bottomNavigationBar: MobileNavigationBar(
                isDark: false,
                homeSelected: true,
                onHome: () {},
                onBooking: () {},
                onProfile: () {},
              ),
            ),
          ),
        ),
      );
      double baseline(String label) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        );
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.size.width);
        final y = paragraph
            .localToGlobal(
              Offset(0, painter.computeLineMetrics().first.baseline),
            )
            .dy;
        painter.dispose();
        return y;
      }

      final expected = baseline('Trang chủ');
      for (final label in ['Đơn hàng', 'Tạo nhanh', 'Thông báo', 'Cá nhân']) {
        expect(baseline(label), closeTo(expected, 0.01), reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }

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
      expect(
        find.byKey(const ValueKey('bottom-nav-center-icon')),
        findsOneWidget,
      );
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

  testWidgets(
    'center button displays action icon and label instead of repeating app logo',
    (tester) async {
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
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bottom-nav-center-icon')),
        findsOneWidget,
      );
      expect(find.text('Tạo nhanh'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bottom-nav-center-logo')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'DashboardMobileAppBar keeps logo horizontally centered with and without back button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: DashboardMobileAppBar(
              isDark: false,
              showBack: false,
              notificationBadge: '',
              onToggleTheme: () {},
              onToggleNotifications: () {},
            ),
          ),
        ),
      );
      final appBarRect = tester.getRect(find.byType(DashboardMobileAppBar));
      final logoWithoutBack = tester.getCenter(
        find.descendant(
          of: find.byType(DashboardMobileAppBar),
          matching: find.byType(Image),
        ),
      );
      expect(logoWithoutBack.dx, closeTo(appBarRect.center.dx, 0.5));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: DashboardMobileAppBar(
              isDark: false,
              showBack: true,
              notificationBadge: '',
              onToggleTheme: () {},
              onToggleNotifications: () {},
            ),
          ),
        ),
      );
      final logoWithBack = tester.getCenter(
        find.descendant(
          of: find.byType(DashboardMobileAppBar),
          matching: find.byType(Image),
        ),
      );
      expect(logoWithBack.dx, closeTo(appBarRect.center.dx, 0.5));
      expect(logoWithoutBack.dx, closeTo(logoWithBack.dx, 0.5));
    },
  );
}

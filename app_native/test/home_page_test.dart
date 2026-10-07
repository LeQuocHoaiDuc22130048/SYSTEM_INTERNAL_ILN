import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/navigation/main_tabs.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:system_inverter_likenew/models/user.dart';
import 'package:system_inverter_likenew/models/app_banner.dart';
import 'package:system_inverter_likenew/models/attendance.dart';
import 'package:system_inverter_likenew/screens/home_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:system_inverter_likenew/utils/update_provider.dart';
import 'package:system_inverter_likenew/theme/app_colors.dart';
import 'package:system_inverter_likenew/widgets/directional_slide_switcher.dart';
import 'package:system_inverter_likenew/widgets/navigation/mobile_navigation_bar.dart';
import 'package:system_inverter_likenew/widgets/navigation/mobile_dashboard_app_bar.dart';

class _HomeAuth extends AuthProvider {
  _HomeAuth(this.user)
    : super(apiClient: ApiClient(client: MockClient((_) async =>
        http.Response('[]', 200, headers: {'content-type': 'application/json'}))));

  User user;

  @override
  User get currentUser => user;
  @override
  UserRole get role => user.role;
  @override
  bool get isAuthenticated => true;
  @override
  bool can(AppPermission permission) => user.can(permission);

  void updateUser(User value) {
    user = value;
    notifyListeners();
  }
}

class _BannerBackend extends BackendDataProvider {
  _BannerBackend(ApiClient api, AppBanner banner) : super(api: api) {
    banners = [banner];
  }

  @override
  Future<void> loadBanners({bool notify = true}) async {}
}

class _RefreshingBannerBackend extends BackendDataProvider {
  _RefreshingBannerBackend(ApiClient api) : super(api: api) {
    banners = const [AppBanner(id: 'one', title: 'Cũ', imagePosition: 'NONE'), AppBanner(id: 'two', title: 'Cũ 2', imagePosition: 'NONE')];
  }
  int requests = 0;
  @override
  Future<void> loadBanners({bool notify = true}) async {
    requests++;
    banners = [AppBanner(id: 'one', title: 'Mới $requests', imagePosition: 'NONE')];
    if (notify) notifyListeners();
  }
}

class _AttendanceBackend extends _BannerBackend {
  _AttendanceBackend(ApiClient api) : super(api, const AppBanner(id: 'test', title: 'Banner', imagePosition: 'NONE'));
  int teamLoads = 0;
  int ownLoads = 0;
  @override
  Future<void> loadAttendance({bool notify = true}) async { teamLoads++; }
  @override
  Future<void> loadMyTodayAttendance({bool notify = true}) async { ownLoads++; }
}

User _homeUser(UserRole role, {Set<AppPermission>? permissions}) => User(
  id: 'home-test', name: 'Test User', email: '', employeeId: '',
  role: role, status: UserStatus.active, permissions: permissions,
);

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
    BackendDataProvider? backend,
    bool showBottomNav = true,
    int initialNavTab = 0,
    void Function(int)? onNavigateToTab,
    ThemeData? theme,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider<BackendDataProvider>(create: (_) => backend ?? BackendDataProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api: auth.api)),
        ChangeNotifierProvider(create: (_) => UpdateProvider(api: auth.api)),
      ],
      child: MaterialApp(
        theme: theme,
        home: HomePage(
          showBottomNav: showBottomNav,
          initialNavTab: initialNavTab,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
    );
  }

  testWidgets('Home refreshes cached banners on entry and app resume', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _RefreshingBannerBackend(auth.api);
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend, showBottomNav: false));
    await tester.pump();
    expect(find.text('Mới 1'), findsOneWidget);
    expect(backend.requests, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Mới 2'), findsOneWidget);
    expect(backend.requests, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('Mixed legacy and custom slides have identical 2:1 frames', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _BannerBackend(auth.api, const AppBanner(id: 'legacy', title: 'Legacy', imagePosition: 'NONE'));
    backend.banners.add(AppBanner(id: 'custom', title: 'Custom', imagePosition: 'NONE', designJson: jsonEncode({
      'version': 1, 'nodes': {'title': {'x': 5, 'y': 28, 'width': 62, 'height': 23}},
    })));
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend, showBottomNav: false));
    await tester.pump();
    final page = tester.widget<PageView>(find.byType(PageView));
    final first = tester.getSize(find.byKey(const ValueKey('banner-slide-legacy')));
    expect(first.height, (first.width - 12) / 2);
    page.controller!.jumpToPage(1);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('banner-slide-custom'))), first);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('Home uses shared dashboard header and account avatar only in footer', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _BannerBackend(auth.api, const AppBanner(id: 'header', title: 'Banner', imagePosition: 'NONE'));
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend));
    await tester.pump();
    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    final avatar = find.byKey(const ValueKey('bottom-account-avatar'));
    expect(avatar, findsOneWidget);
    expect(find.ancestor(of: avatar, matching: find.byType(MobileNavigationBar)), findsOneWidget);
    expect(find.descendant(of: find.byType(DashboardMobileAppBar), matching: avatar), findsNothing);
    expect(find.text('TU'), findsOneWidget);
    auth.updateUser(User(id: 'home-test', name: 'Nguyễn Văn An', email: '', employeeId: '', role: UserRole.manager, status: UserStatus.active));
    await tester.pump();
    expect(find.text('NA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('Home replaces experts with today attendance and filters other dates', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _AttendanceBackend(auth.api);
    final now = DateTime.now();
    backend.attendanceRecords = [
      AttendanceRecord(id: 'today', employeeId: '1', employeeName: 'Nhân viên hôm nay', date: now, checkIn: '08:00', checkOut: '17:00', status: AttendanceStatus.onTime),
      AttendanceRecord(id: 'old', employeeId: '2', employeeName: 'Dữ liệu cũ', date: now.subtract(const Duration(days: 1)), status: AttendanceStatus.late),
    ];
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend));
    await tester.pump();
    expect(find.text('Chấm công hôm nay'), findsOneWidget);
    expect(find.text('Nhân viên hôm nay'), findsOneWidget);
    expect(find.text('Vào: 08:00'), findsOneWidget);
    expect(find.text('Ra: 17:00'), findsOneWidget);
    expect(find.text('Dữ liệu cũ'), findsNothing);
    expect(find.text('Kỹ thuật viên tiêu biểu'), findsNothing);
    expect(backend.teamLoads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('Employee only sees own attendance; no team report is loaded', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.employee));
    final backend = _AttendanceBackend(auth.api);
    backend.myTodayAttendance = MyTodayAttendance(date: DateTime.now(), checkIn: DateTime.now(), isLate: true);
    backend.attendanceRecords = [AttendanceRecord(id: 'other', employeeId: '2', employeeName: 'Thông tin người khác', date: DateTime.now(), status: AttendanceStatus.onTime)];
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend));
    await tester.pump();
    expect(find.text('Chấm công của bạn'), findsOneWidget);
    expect(find.text('Muộn'), findsOneWidget);
    expect(find.text('Thông tin người khác'), findsNothing);
    expect(backend.teamLoads, 0);
    expect(backend.ownLoads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('bottom plus opens the existing create repair order form', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _AttendanceBackend(auth.api);
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-booking-button')));
    await tester.pumpAndSettle();
    expect(find.text('Thao tác nhanh'), findsOneWidget);
    await tester.tap(find.text('Tạo đơn sửa chữa'));
    await tester.pumpAndSettle();
    expect(find.text('Thao tác nhanh'), findsNothing);
    expect(find.text('Tạo đơn sửa chữa mới'), findsOneWidget);
    expect(find.text('Tên khách hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('quick actions respect explicit permissions and navigate after closing menu', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.employee, permissions: {AppPermission.viewProfile, AppPermission.useMessages}));
    final backend = _AttendanceBackend(auth.api);
    int? destination;
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend, onNavigateToTab: (tab) => destination = tab));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bottom-nav-booking-button')));
    await tester.pumpAndSettle();
    expect(find.text('Tạo đơn sửa chữa'), findsNothing);
    expect(find.text('Kho linh kiện'), findsNothing);
    expect(find.text('Chấm công hôm nay'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Nhắn tin'));
    await tester.pumpAndSettle();
    expect(destination, MainTabs.messages);
    expect(find.text('Thao tác nhanh'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('Banner and CTA navigate to their own configured screens', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.manager));
    final backend = _BannerBackend(auth.api, const AppBanner(
      id: 'action-test', title: 'Điều hướng banner', imagePosition: 'NONE',
      actionType: 'SCREEN', actionValue: 'repair_orders',
      buttons: [AppBannerButton(text: 'Mở kho', actionType: 'SCREEN', actionValue: 'warehouse')],
    ));
    int? navigatedTab;
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend,
      showBottomNav: false, onNavigateToTab: (tab) => navigatedTab = tab));
    await tester.pump();
    await tester.tap(find.text('Điều hướng banner'));
    expect(navigatedTab, MainTabs.repairOrders);
    await tester.tap(find.text('Mở kho'));
    expect(navigatedTab, MainTabs.warehouse);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  for (final route in {
    'attendance': MainTabs.attendance,
    'notifications': MainTabs.notifications,
    'account_approval': MainTabs.accountApproval,
  }.entries) {
    testWidgets('Banner opens configured screen ${route.key}', (tester) async {
      final auth = _HomeAuth(_homeUser(UserRole.superAdmin));
      final backend = _BannerBackend(auth.api, AppBanner(
        id: 'route-test', title: 'Mở màn hình', imagePosition: 'NONE',
        actionType: 'SCREEN', actionValue: route.key,
      ));
      int? navigatedTab;
      await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend,
        showBottomNav: false, onNavigateToTab: (tab) => navigatedTab = tab));
      await tester.pump();
      await tester.tap(find.text('Mở màn hình'));
      expect(navigatedTab, route.value);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    });
  }

  testWidgets('Banner action cannot navigate to a screen without permission', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.technician));
    final backend = _BannerBackend(auth.api, const AppBanner(
      id: 'denied-action', title: 'Mở kho từ banner', imagePosition: 'NONE',
      actionType: 'SCREEN', actionValue: 'warehouse',
    ));
    int? navigatedTab;
    await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend,
      showBottomNav: false, onNavigateToTab: (tab) => navigatedTab = tab));
    await tester.pump();
    await tester.tap(find.text('Mở kho từ banner'));
    await tester.pump();
    expect(navigatedTab, isNull);
    expect(find.text('Bạn không có quyền truy cập chức năng này.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  for (final position in ['RIGHT', 'LEFT', 'RIGHT_TOP', 'NONE', 'EMPTY']) {
    testWidgets('Banner with uploaded background respects mascot position $position', (tester) async {
      const backgroundUrl = 'https://inverterlikenew.com/test-banner.png';
      final bytes = await rootBundle.load('assets/images/image_character.png');
      final image = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      });
      final provider = const NetworkImage(backgroundUrl);
      final key = await provider.obtainKey(ImageConfiguration.empty);
      PaintingBinding.instance.imageCache.putIfAbsent(key, () =>
        OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image!))));
      await tester.pump();

      final auth = _HomeAuth(_homeUser(UserRole.employee));
      final backend = _BannerBackend(auth.api, AppBanner.fromJson({
        'id': 'uploaded-bg', 'title': 'Banner test',
        'backgroundImageUrl': backgroundUrl, 'imagePosition': position,
      }));
      await tester.pumpWidget(createHomeScreen(auth: auth, backend: backend, showBottomNav: false));
      await tester.pump();
      final mascot = find.byWidgetPredicate((widget) => widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/images/image_character.png');
      expect(mascot, ['NONE', 'EMPTY'].contains(position) ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      auth.dispose();
    });
  }

  for (final width in [320.0, 360.0, 393.0]) {
    testWidgets('HomePage fits width $width with enlarged text', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = _HomeAuth(_homeUser(UserRole.manager));
      await tester.pumpWidget(createHomeScreen(auth: auth));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    });
  }

  final visibleFunctionsByRole = {
    UserRole.superAdmin: ['Dashboard', 'Đơn', 'Kho', 'Nhắn tin', 'Quản lý nhân viên'],
    UserRole.admin: ['Dashboard', 'Đơn', 'Kho', 'Nhắn tin', 'Quản lý nhân viên'],
    UserRole.manager: ['Dashboard', 'Đơn', 'Kho', 'Nhắn tin', 'Quản lý nhân viên'],
    UserRole.technician: ['Dashboard', 'Đơn'],
    UserRole.warehouse: ['Dashboard', 'Đơn', 'Kho', 'Nhắn tin'],
    UserRole.employee: ['Dashboard', 'Đơn', 'Kho', 'Nhắn tin'],
    UserRole.attendance: <String>[],
  };

  for (final entry in visibleFunctionsByRole.entries) {
    testWidgets('HomePage shows only allowed functions for ${entry.key.name}', (tester) async {
      final auth = _HomeAuth(_homeUser(entry.key));
      await tester.pumpWidget(createHomeScreen(auth: auth, showBottomNav: false));
      await tester.pump();
      for (final label in visibleFunctionsByRole[UserRole.superAdmin]!) {
        expect(find.text(label), entry.value.contains(label) ? findsOneWidget : findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    });
  }

  testWidgets('HomePage respects server permissions and updates after permissions change', (tester) async {
    final auth = _HomeAuth(_homeUser(UserRole.admin, permissions: {AppPermission.viewWarehouse}));
    int? navigatedTab;
    await tester.pumpWidget(createHomeScreen(
      auth: auth, showBottomNav: false, onNavigateToTab: (tab) => navigatedTab = tab,
    ));
    await tester.pump();
    expect(find.text('Kho'), findsOneWidget);
    for (final label in ['Dashboard', 'Đơn', 'Nhắn tin', 'Quản lý nhân viên']) {
      expect(find.text(label), findsNothing);
    }
    await tester.ensureVisible(find.text('Kho'));
    await tester.tap(find.text('Kho'));
    expect(navigatedTab, MainTabs.warehouse);

    auth.updateUser(_homeUser(UserRole.employee, permissions: {AppPermission.approveAccounts}));
    await tester.pump();
    expect(find.text('Kho'), findsNothing);
    expect(find.text('Quản lý nhân viên'), findsOneWidget);

    auth.updateUser(_homeUser(UserRole.admin, permissions: {}));
    await tester.pump();
    for (final label in visibleFunctionsByRole[UserRole.superAdmin]!) {
      expect(find.text(label), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

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
    await tester.pump(const Duration(milliseconds: 1000));

    // 1. Top bar: Account Profile Info (Avatar, Name, and Role)
    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-account-avatar')), findsOneWidget);
    expect(find.text('Nhân viên'), findsNothing);

    // 2. Greeting section
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);

    // Verify search bar and ongoing booking card are hidden from home page
    expect(find.text('ĐÃ XÁC NHẬN ✓'), findsNothing);
    expect(find.text('Bảo trì Inverter & Nạp linh kiện'), findsNothing);
    expect(find.text('Tìm kiếm sửa chữa, điện nước, biến tần...'), findsNothing);

    // 3. Promotional banner with 3D Character image
    expect(find.text('⚡ ƯU ĐÃI ĐẶC BIỆT'), findsOneWidget);
    expect(find.text('Bảo Trì & Sửa Chữa Inverter'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    final promoHeadline = find.text('Bảo Trì & Sửa Chữa Inverter');
    final bannerContainerFinder = find.ancestor(
      of: promoHeadline,
      matching: find.byType(Container),
    ).first;
    expect(tester.getSize(bannerContainerFinder).width, 346.0);

    // 5. Functions section (Dashboard, Đơn, Kho, Nhắn tin, Quản lý nhân viên)
    expect(find.text('Chức năng'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Đơn'), findsOneWidget);
    expect(find.text('Kho'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Quản lý nhân viên'), findsNothing);

    // 6. Top Rated Experts
    expect(find.text('Chấm công hôm nay'), findsOneWidget);
    expect(find.text('David Miller'), findsNothing);
    expect(find.text('Sarah Jenkins'), findsNothing);

    // 7. Stitch Bottom Nav
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);

    // Tap Book Now button to open booking sheet
    final bookNowBtn = find.byKey(const ValueKey('bottom-nav-booking-button'));
    expect(bookNowBtn, findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-nav-center-logo')), findsOneWidget);
    await tester.tap(bookNowBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Thao tác nhanh'), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 1000));

    // Initially on Home page
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsNothing);

    // Tap Tab 3 "Cá nhân" in the Stitch bottom nav
    final profileTabFinder = find.text('Cá nhân');
    expect(profileTabFinder, findsOneWidget);
    await tester.tap(profileTabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Now synchronized and switched to Profile page
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Hoai Duc'), findsWidgets);

    // Tap Tab 1 "Trang chủ" in the Stitch bottom nav
    final homeTabFinder = find.text('Trang chủ');
    expect(homeTabFinder, findsOneWidget);
    await tester.tap(homeTabFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Switched back to Home page
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsNothing);

    // Switch to Profile again and test Profile's top bar back button
    await tester.tap(find.text('Cá nhân'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);

    final backButtonFinder = find.byIcon(LucideIcons.chevronLeft);
    expect(backButtonFinder, findsOneWidget);
    await tester.tap(backButtonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Returned to Home page via top bar back button
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 1000));

    // Directly in Profile
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Xin chào, Hoai Duc 👋'), findsNothing);

    // Tap Tab 1 "Trang chủ" in the Stitch bottom nav
    await tester.tap(find.text('Trang chủ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Switched to Home
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsNothing);
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
    await tester.pump(const Duration(milliseconds: 1000));

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

  testWidgets('HomePage bottom account avatar opens ProfilePage', (tester) async {
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
                  'id': '2',
                  'username': 'tech_user',
                  'fullName': 'Nguyen Van Tech',
                  'role': 'TECHNICIAN',
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
                'id': '2',
                'username': 'tech_user',
                'fullName': 'Nguyen Van Tech',
                'role': 'TECHNICIAN',
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
    await auth.login(username: 'tech_user', password: 'password');

    await tester.pumpWidget(createHomeScreen(auth: auth, showBottomNav: true, initialNavTab: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify avatar initials fallback, name, and role label
    expect(find.text('NT'), findsOneWidget);
    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byKey(const ValueKey('bottom-account-avatar')), findsOneWidget);

    // Tap the top bar profile area to navigate to Profile
    await tester.tap(find.byKey(const ValueKey('bottom-account-avatar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    // Verify it opened ProfilePage
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
  });

  testWidgets('HomePage keeps Header and Footer fixed while sliding middle content directionally', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 1000));

    // Initially at Home
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.byType(MobileNavigationBar), findsOneWidget);
    expect(find.byType(DirectionalSlideSwitcher), findsOneWidget);

    final switcherInitial = tester.widget<DirectionalSlideSwitcher>(find.byType(DirectionalSlideSwitcher));
    expect(switcherInitial.isForward, isTrue);

    // Initial position of bottom nav footer
    final initialNavTop = tester.getTopLeft(find.byType(MobileNavigationBar)).dy;
    final initialNavLeft = tester.getTopLeft(find.byType(MobileNavigationBar)).dx;

    // Tap "Cá nhân" to navigate forward to Profile
    await tester.tap(find.text('Cá nhân'));
    await tester.pump(); // Starts transition

    // Mid-transition check
    await tester.pump(const Duration(milliseconds: 150));
    final switcherForward = tester.widget<DirectionalSlideSwitcher>(find.byType(DirectionalSlideSwitcher));
    expect(switcherForward.isForward, isTrue);

    // Footer remains completely fixed in position
    final midNavTop = tester.getTopLeft(find.byType(MobileNavigationBar)).dy;
    final midNavLeft = tester.getTopLeft(find.byType(MobileNavigationBar)).dx;
    expect(midNavTop, equals(initialNavTop));
    expect(midNavLeft, equals(initialNavLeft));

    // Complete transition to Profile
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);

    // Tap top bar back button to navigate backwards to Home
    final backButton = find.byIcon(LucideIcons.chevronLeft);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pump(); // Starts reverse transition

    // Mid-reverse transition check
    await tester.pump(const Duration(milliseconds: 150));
    final switcherBackward = tester.widget<DirectionalSlideSwitcher>(find.byType(DirectionalSlideSwitcher));
    expect(switcherBackward.isForward, isFalse);

    // Footer still remains fixed
    expect(tester.getTopLeft(find.byType(MobileNavigationBar)).dx, equals(initialNavLeft));

    // Complete reverse transition to Home
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Xin chào, Hoai Duc 👋'), findsOneWidget);
    expect(find.text('THÔNG TIN TÀI KHOẢN'), findsNothing);
  });

  testWidgets('HomePage adapts colors properly in dark mode', (tester) async {
    final auth = _HomeAuth(
      _homeUser(UserRole.employee, permissions: {AppPermission.viewDashboard}),
    );
    final backend = _BannerBackend(
      auth.api,
      const AppBanner(
        id: 'b1',
        title: 'Bảo trì',
        subtitle: 'Giảm 25%',
        imagePosition: 'NONE',
      ),
    );

    await tester.pumpWidget(
      createHomeScreen(
        auth: auth,
        backend: backend,
        showBottomNav: true,
        theme: ThemeData.dark(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 'Chức năng' header has dark theme text color
    final chucNangFinder = find.text('Chức năng');
    expect(chucNangFinder, findsOneWidget);
    final chucNangText = tester.widget<Text>(chucNangFinder);
    expect(chucNangText.style?.color, equals(AppColors.textPrimaryDark));

    expect(find.text('Kỹ thuật viên tiêu biểu'), findsNothing);
    // Verify function card (Dashboard) has dark text color
    final dashboardFinder = find.text('Dashboard');
    expect(dashboardFinder, findsOneWidget);
    final dashboardText = tester.widget<Text>(dashboardFinder);
    expect(dashboardText.style?.color, equals(AppColors.textPrimaryDark));

  });
}



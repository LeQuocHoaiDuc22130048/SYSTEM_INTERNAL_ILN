import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
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
import 'package:system_inverter_likenew/widgets/navigation/mobile_dashboard_app_bar.dart';
import 'package:system_inverter_likenew/widgets/navigation/mobile_navigation_bar.dart';
import 'package:system_inverter_likenew/widgets/navigation/app_back_button.dart';

class _Auth extends AuthProvider {
  _Auth(ApiClient api) : super(apiClient: api);
  @override
  bool get isAuthenticated => true;
  @override
  bool can(AppPermission permission) => const {
    AppPermission.useMessages,
    AppPermission.sendMessages,
    AppPermission.uploadMessages,
  }.contains(permission);
}

class _Updates extends UpdateProvider {
  _Updates(ApiClient api) : super(api: api);
  @override
  Future<void> checkForUpdate(
    BuildContext context, {
    bool manual = false,
  }) async {}
}

Future<ChatProvider> _mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(
    baseUrl: 'https://test.api.local',
    client: MockClient((request) async {
      final Object body = request.url.path == '/api/v1/conversations'
          ? [
              {
                'id': 'chat',
                'type': 'DIRECT',
                'name': 'Navigation chat',
                'members': [],
                'unreadCount': 0,
                'createdAt': '2026-01-01T00:00:00Z',
              },
            ]
          : request.url.path.endsWith('/messages')
          ? {'content': []}
          : [];
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  final notifications = NotificationProvider(api: api);
  final chat = ChatProvider(api: api, notificationProvider: notifications);
  final auth = _Auth(api);
  final backend = BackendDataProvider(api: api);
  final updates = _Updates(api);
  final theme = ThemeProvider();
  addTearDown(() {
    chat.dispose();
    notifications.dispose();
    auth.dispose();
    backend.dispose();
    updates.dispose();
    theme.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<BackendDataProvider>.value(value: backend),
        ChangeNotifierProvider<NotificationProvider>.value(
          value: notifications,
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ChangeNotifierProvider<UpdateProvider>.value(value: updates),
        ChangeNotifierProvider<ThemeProvider>.value(value: theme),
      ],
      child: const MaterialApp(
        home: MainScreen(initialIndex: MainTabs.messages),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return chat;
}

void main() {
  testWidgets('mobile conversation hides shell and closing it restores shell', (
    tester,
  ) async {
    final chat = await _mount(tester);
    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byType(MobileNavigationBar), findsOneWidget);
    await tester.tap(find.text('Navigation chat'));
    await tester.pumpAndSettle();
    expect(chat.activeConversationId, 'chat');
    expect(find.byType(DashboardMobileAppBar), findsNothing);
    expect(find.byType(MobileNavigationBar), findsNothing);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(chat.activeConversationId, isNull);
    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byType(MobileNavigationBar), findsOneWidget);
  });

  testWidgets('chat composer uses the keyboard inset once', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Navigation chat'));
    await tester.pumpAndSettle();
    final composer = find.byType(TextField);
    final bottomBefore = tester.getBottomLeft(composer).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(composer).dy, closeTo(bottomBefore - 300, 1));
    expect(find.byType(MobileNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
  });

  testWidgets('system back closes chat before leaving messages for home', (
    tester,
  ) async {
    final chat = await _mount(tester);
    await tester.tap(find.text('Navigation chat'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chat.activeConversationId, isNull);
    expect(find.text('Navigation chat'), findsOneWidget);
    expect(
      tester
          .widget<MobileNavigationBar>(find.byType(MobileNavigationBar))
          .homeSelected,
      isFalse,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MobileNavigationBar>(find.byType(MobileNavigationBar))
          .homeSelected,
      isTrue,
    );
  });

  testWidgets('chat info route pops before the active chat', (tester) async {
    final chat = await _mount(tester);
    await tester.tap(find.text('Navigation chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(chat.activeConversationId, 'chat');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(chat.activeConversationId, isNull);
  });
}

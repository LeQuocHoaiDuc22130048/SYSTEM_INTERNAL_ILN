import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/main.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/backend_data_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';
import 'package:system_internal_likenew/utils/chat_provider.dart';
import 'package:system_internal_likenew/utils/network_provider.dart';
import 'package:system_internal_likenew/utils/pending_sync_provider.dart';

void main() {
  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProxyProvider<AuthProvider, BackendDataProvider>(
            create: (context) =>
                BackendDataProvider(api: context.read<AuthProvider>().api),
            update: (_, auth, previous) =>
                previous ?? BackendDataProvider(api: auth.api),
          ),
          ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
            create: (context) =>
                NotificationProvider(api: context.read<AuthProvider>().api),
            update: (_, auth, previous) {
              final provider = previous ?? NotificationProvider(api: auth.api);
              provider.bindAuth(auth);
              return provider;
            },
          ),
          ChangeNotifierProxyProvider2<AuthProvider, NotificationProvider, ChatProvider>(
            create: (context) => ChatProvider(
              api: context.read<AuthProvider>().api,
              notificationProvider: context.read<NotificationProvider>(),
            ),
            update: (_, auth, notifications, previous) {
              final provider = previous ?? ChatProvider(
                api: auth.api,
                notificationProvider: notifications,
              );
              provider.updateAuthAndNotification(auth, notifications);
              return provider;
            },
          ),
          ChangeNotifierProvider(create: (_) => NetworkProvider()),
          ChangeNotifierProxyProvider<NetworkProvider, PendingSyncProvider>(
            create: (_) => PendingSyncProvider(),
            update: (_, network, pendingSync) {
              final provider = pendingSync ?? PendingSyncProvider();
              provider.bindNetwork(network);
              return provider;
            },
          ),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xin chào, Minh 👋'), findsOneWidget);
    expect(find.text('Tổng đơn hôm nay'), findsOneWidget);
    expect(find.text('Thống kê đơn theo tuần'), findsOneWidget);
  });
}

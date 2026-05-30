import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/main.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
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
    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': []}), 200),
        ),
      ),
    );
    auth.api.accessToken = 'widget-test-token';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => BackendDataProvider(api: auth.api),
          ),
          ChangeNotifierProvider(
            create: (_) => NotificationProvider(api: auth.api),
          ),
          ChangeNotifierProvider(
            create: (context) => ChatProvider(
              api: auth.api,
              notificationProvider: context.read<NotificationProvider>(),
            ),
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
    expect(find.text('Đơn của tôi'), findsOneWidget);
    expect(find.text('Đơn gần đây'), findsOneWidget);
  });
}

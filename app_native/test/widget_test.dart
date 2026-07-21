import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_internal_likenew/app/theme_provider.dart';
import 'package:system_internal_likenew/screens/main_screen.dart';
import 'package:system_internal_likenew/utils/auth_provider.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/backend_data_provider.dart';
import 'package:system_internal_likenew/utils/notification_provider.dart';
import 'package:system_internal_likenew/utils/chat_provider.dart';
import 'package:system_internal_likenew/utils/network_provider.dart';
import 'package:system_internal_likenew/utils/pending_sync_provider.dart';

import 'package:flutter/services.dart';
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

  testWidgets('renders dashboard shell', (WidgetTester tester) async {
    mockSecureStorage.clear();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider(
      apiClient: ApiClient(
        client: MockClient(
          (request) async {
            if (request.url.path == '/api/v1/auth/login') {
              return http.Response(
                jsonEncode({
                  'accessToken': 'widget-test-token',
                  'refreshToken': 'widget-test-refresh-token',
                  'userInfo': {
                    'id': '123',
                    'username': 'minh',
                    'fullName': 'Minh',
                    'role': 'EMPLOYEE',
                    'status': 'ACTIVE',
                  }
                }),
                200,
              );
            }
            if (request.url.path == '/api/v1/employees/me') {
              return http.Response(
                jsonEncode({
                  'id': '123',
                  'username': 'minh',
                  'fullName': 'Minh',
                  'role': 'EMPLOYEE',
                  'status': 'ACTIVE',
                }),
                200,
              );
            }
            return http.Response(jsonEncode({'data': []}), 200);
          },
        ),
      ),
    );
    await auth.login(username: 'minh', password: 'password');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => UpdateProvider(api: auth.api),
          ),
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

    expect(find.text('Xin chào, Minh'), findsOneWidget);
    expect(find.text('Đơn của tôi'), findsOneWidget);
    expect(find.text('Đơn gần đây'), findsOneWidget);
  });
}

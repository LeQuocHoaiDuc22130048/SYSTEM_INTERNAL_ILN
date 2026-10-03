import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/user.dart';
import 'package:system_inverter_likenew/screens/repair_orders_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';

class _AdminAuth extends AuthProvider {
  @override
  UserRole get role => UserRole.admin;
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      fails
          ? 'status update failure keeps dialog open for retry'
          : 'detail action saves status and refreshes the order list',
      (tester) async {
        tester.view.physicalSize = const Size(550, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var status = 'PENDING';
        Map<String, dynamic>? submitted;
        final api = ApiClient(
          baseUrl: 'https://test.local',
          client: MockClient((request) async {
            if (request.method == 'PATCH') {
              expect(request.url.path, '/api/v1/repair-orders/order-1/status');
              submitted = jsonDecode(request.body) as Map<String, dynamic>;
              if (fails) {
                return http.Response('{"message":"Update rejected"}', 403);
              }
              status = submitted!['status'] as String;
              return http.Response('{}', 200);
            }
            return http.Response(
              jsonEncode({
                'content': [
                  {
                    'id': 'order-1',
                    'orderCode': 'RO-001',
                    'deviceName': 'Growatt 8kw',
                    'customerName': 'Customer',
                    'status': status,
                    'createdAt': '2026-09-29T08:00:00Z',
                  },
                ],
              }),
              200,
            );
          }),
        );
        final backend = BackendDataProvider(api: api);
        final auth = _AdminAuth();
        addTearDown(backend.dispose);
        addTearDown(auth.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: auth),
              ChangeNotifierProvider.value(value: backend),
            ],
            child: const MaterialApp(home: Scaffold(body: RepairOrdersPage())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Growatt 8kw'));
        await tester.pumpAndSettle();
        final update = find.widgetWithText(
          OutlinedButton,
          'Cập nhật trạng thái',
        );
        expect(update, findsOneWidget);
        expect(
          tester.getTopLeft(update).dy,
          greaterThan(tester.getTopLeft(find.text('Xóa đơn hàng')).dy),
        );
        await tester.ensureVisible(update);
        await tester.tap(update);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Lưu'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chờ kiểm tra').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '  Ready  ');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
        await tester.pumpAndSettle();
        expect(submitted, {'status': 'WAITING_FOR_CHECK', 'note': 'Ready'});
        if (fails) {
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Lưu'),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(find.byType(AlertDialog), findsNothing);
          expect(backend.repairOrders.single.statusLabel, 'Chờ kiểm tra');
          expect(find.text('Chờ kiểm tra'), findsWidgets);
        }
      },
    );
  }
}

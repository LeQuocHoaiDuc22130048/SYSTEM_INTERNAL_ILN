import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/screens/warehouse_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';

void main() {
  Future<void> openWarehouse(
    WidgetTester tester, {
    List<http.Request>? requests,
    bool noCheckouts = false,
    bool failReturn = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      baseUrl: 'https://test.local',
      client: MockClient((request) async {
        requests?.add(request);
        if (request.method == 'POST' && failReturn) {
          return http.Response(jsonEncode({'message': 'Return failed'}), 500);
        }
        final items = switch (request.url.path) {
          '/api/v1/boards' => [
            {
              'id': 'board-1',
              'name': 'ABC',
              'quantity': 100,
              'minQuantity': 10,
              'status': 'AVAILABLE',
              'location': 'LOCA',
              'serialNumber': 'SERIAL-123',
            },
            {
              'id': 'board-2',
              'name': 'Low board',
              'quantity': 2,
              'minQuantity': 10,
              'status': 'AVAILABLE',
            },
          ],
          '/api/v1/parts' => [
            {
              'id': 'part-1',
              'ipn': 'EMPTY',
              'name': 'Empty part',
              'totalQuantity': 0,
              'minAmount': 10,
              'lots': [],
            },
            {
              'id': 'part-2',
              'ipn': 'LOW',
              'name': 'Low part',
              'totalQuantity': 2,
              'minAmount': 10,
              'lots': [
                {
                  'id': 'lot-2',
                  'storeLocationId': 'loc-1',
                  'storeLocationCode': 'LOCA',
                  'storeLocationName': 'Kệ A',
                  'amount': 2,
                },
              ],
            },
          ],
          '/api/v1/parts/checkouts/history' =>
            noCheckouts
                ? []
                : [
                    {
                      'id': 'checkout-1',
                      'partId': 'part-2',
                      'partName': 'Low part',
                      'partIpn': 'LOW',
                      'locationCode': 'LOCA',
                      'takenByName': 'Technician',
                      'quantity': 5,
                      'returnedQuantity': 2,
                      'checkoutStatus': 'OPEN',
                    },
                  ],
          _ => [],
        };
        return http.Response(
          jsonEncode({'content': items}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final backend = BackendDataProvider(api: api);
    final auth = AuthProvider(apiClient: api);
    addTearDown(backend.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: backend),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(home: WarehousePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stock chips count both item types and low stock excludes zero', (
    tester,
  ) async {
    await openWarehouse(tester);
    final all = find.widgetWithText(FilterChip, 'Tất cả');
    expect(find.descendant(of: all, matching: find.text('4')), findsOneWidget);
    final low = find.widgetWithText(FilterChip, 'Sắp hết');
    expect(find.descendant(of: low, matching: find.text('2')), findsOneWidget);
    await tester.tap(low);
    await tester.pumpAndSettle();
    expect(find.text('Empty part'), findsNothing);
    expect(find.text('Low board'), findsOneWidget);
    expect(find.text('Low part'), findsOneWidget);
  });

  testWidgets(
    'part return uses the selected checkout and rejects excessive quantities',
    (tester) async {
      final requests = <http.Request>[];
      await openWarehouse(tester, requests: requests);
      await tester.enterText(find.byType(TextField).first, 'LOW');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low part'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Trả linh kiện'));
      await tester.tap(find.text('Trả linh kiện'));
      await tester.pumpAndSettle();
      for (final invalid in ['4', '0', '-1', 'NaN', 'Infinity']) {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Số lượng trả *'),
          invalid,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận trả'));
        await tester.pumpAndSettle();
      }
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số lượng trả *'),
        '2',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận trả'));
      await tester.pumpAndSettle();
      final posted = requests.singleWhere((r) => r.method == 'POST');
      expect(posted.url.path, '/api/v1/parts/checkouts/checkout-1/return');
      expect(jsonDecode(posted.body)['returnedQuantity'], 2);
      expect(find.text('Trả linh kiện thành công'), findsOneWidget);
    },
  );

  testWidgets('serial search opens board checkout without a QR scan', (
    tester,
  ) async {
    await openWarehouse(tester);
    await tester.enterText(find.byType(TextField).first, 'serial-123');
    await tester.pumpAndSettle();
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('Low board'), findsNothing);
    await tester.tap(find.text('ABC'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Lấy bo mạch'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Lấy bo mạch'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Trả bo mạch'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('one search finds boards and parts by location or IPN', (
    tester,
  ) async {
    await openWarehouse(tester);
    await tester.enterText(find.byType(TextField).first, 'loca');
    await tester.pumpAndSettle();
    expect(find.text('ABC'), findsOneWidget);
    expect(find.text('Low part'), findsOneWidget);
    expect(find.text('Low board'), findsNothing);
    expect(find.text('Empty part'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'empty');
    await tester.pumpAndSettle();
    expect(find.text('Empty part'), findsOneWidget);
    expect(find.text('ABC'), findsNothing);
  });

  testWidgets(
    'part editor keeps save above keyboard and submits scrolled fields',
    (tester) async {
      final requests = <http.Request>[];
      await openWarehouse(tester, requests: requests);
      await tester.enterText(find.byType(TextField).first, 'LOW');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low part'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final description = find.widgetWithText(TextField, 'Mô tả');
      await tester.ensureVisible(description);
      await tester.enterText(description, 'Edited description');
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'Lưu');
      expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(544));
      await tester.tap(save);
      await tester.pumpAndSettle();
      final request = requests.singleWhere((r) => r.method == 'PUT');
      expect(request.url.path, '/api/v1/parts/part-2');
      expect(jsonDecode(request.body)['description'], 'Edited description');
      expect(find.text('Đã cập nhật linh kiện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('return with no open checkout disables submission', (
    tester,
  ) async {
    await openWarehouse(tester, noCheckouts: true);
    await tester.enterText(find.byType(TextField).first, 'LOW');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low part'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trả linh kiện'));
    await tester.pumpAndSettle();
    expect(find.text('Không có lượt mượn linh kiện đang mở.'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Xác nhận trả'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('failed return preserves form and allows retry', (tester) async {
    await openWarehouse(tester, failReturn: true);
    await tester.enterText(find.byType(TextField).first, 'LOW');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low part'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trả linh kiện'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Xác nhận trả'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trả linh kiện thất bại:'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Xác nhận trả'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.widgetWithText(TextFormField, 'Số lượng trả *'),
      findsOneWidget,
    );
  });

  testWidgets(
    'board editor keeps save visible above keyboard and fields scroll',
    (tester) async {
      await openWarehouse(tester);
      await tester.tap(find.text('ABC'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chỉnh sửa'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester.getBottomLeft(find.widgetWithText(ElevatedButton, 'Lưu')).dy,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

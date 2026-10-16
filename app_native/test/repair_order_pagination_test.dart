import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/screens/repair_orders_page.dart';

Map<String, dynamic> order(String id) => {
  'id': id,
  'orderCode': id,
  'status': 'PENDING',
  'createdAt': '2026-10-16T12:00:00',
};

void main() {
  testWidgets('refresh can fill a filter while an obsolete page is pending', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pending = Completer<http.Response>();
    var nextPageCalls = 0;
    final api = ApiClient(
      baseUrl: 'https://test.local',
      client: MockClient((request) async {
        final second = request.url.queryParameters['page'] == '1';
        if (second && ++nextPageCalls == 1) return pending.future;
        return http.Response(
          jsonEncode({
            'content': second
                ? [
                    {...order('last'), 'deviceName': 'Target device'},
                  ]
                : [for (var i = 0; i < 20; i++) order('order-$i')],
            'totalElements': 21,
            'last': second,
          }),
          200,
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
        child: const MaterialApp(home: RepairOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Target device');
    await tester.pump();
    expect(backend.isLoadingMoreRepairOrders, isTrue);
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final foundBeforeOldPageCompleted = backend.repairOrders.any(
      (o) => o.id == 'last',
    );
    pending.complete(
      http.Response(
        jsonEncode({
          'content': [order('obsolete')],
          'totalElements': 21,
          'last': true,
        }),
        200,
      ),
    );
    await refresh;
    await tester.pumpAndSettle();
    expect(foundBeforeOldPageCompleted, isTrue);
    expect(backend.repairOrders.any((o) => o.id == 'obsolete'), isFalse);
  });

  testWidgets('retry still loads a failed page after clearing a filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var fail = true;
    final api = ApiClient(
      baseUrl: 'https://test.local',
      client: MockClient((request) async {
        final second = request.url.queryParameters['page'] == '1';
        if (second && fail) return http.Response('{"message":"Failed"}', 400);
        return http.Response(
          jsonEncode({
            'content': second
                ? [order('last')]
                : [for (var i = 0; i < 20; i++) order('order-$i')],
            'totalElements': 21,
            'last': second,
          }),
          200,
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
        child: const MaterialApp(home: RepairOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(backend.repairOrdersPageError, isNotNull);
    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    fail = false;
    await tester.scrollUntilVisible(
      find.text('Thử lại'),
      600,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(backend.repairOrdersPageError, isNull);
    expect(backend.repairOrders.length, 21);
  });

  testWidgets('scrolls to the next page and searches beyond 200 orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      baseUrl: 'https://test.local',
      client: MockClient((request) async {
        final page = int.parse(request.url.queryParameters['page']!);
        final size = int.parse(request.url.queryParameters['size']!);
        final start = page * size;
        final end = (start + size).clamp(0, 221);
        return http.Response(
          jsonEncode({
            'content': [
              for (var i = start; i < end; i++)
                {...order('order-$i'), 'deviceName': 'Device $i'},
            ],
            'totalElements': 221,
            'last': end == 221,
          }),
          200,
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
        child: const MaterialApp(home: RepairOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(backend.repairOrders.length, 20);
    expect(find.text('221 đơn tổng cộng'), findsOneWidget);
    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(backend.repairOrders.length, greaterThan(20));
    await tester.enterText(find.byType(TextField).first, 'Device 220');
    await tester.pumpAndSettle();
    expect(backend.repairOrders.length, 221);
    expect(
      find
          .text('Device 220', skipOffstage: true)
          .evaluate()
          .where((element) => element.widget is Text),
      hasLength(1),
    );
    expect(backend.hasMoreRepairOrders, isFalse);
  });

  test(
    'loads beyond the first page without duplicating orders and stops at last page',
    () async {
      final pages = <String>[];
      final provider = BackendDataProvider(
        api: ApiClient(
          baseUrl: 'https://test.local',
          client: MockClient((request) async {
            pages.add(request.url.queryParameters['page'] ?? 'missing');
            final second = request.url.queryParameters['page'] == '1';
            return http.Response(
              jsonEncode({
                'content': second
                    ? [order('b'), order('c')]
                    : [order('a'), order('b')],
                'totalElements': 3,
                'last': second,
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(provider.dispose);
      await provider.loadRepairOrders();
      await provider.loadMoreRepairOrders();
      await provider.loadMoreRepairOrders();
      expect(provider.repairOrders.map((o) => o.id), ['a', 'b', 'c']);
      expect(provider.repairOrdersTotal, 3);
      expect(pages, ['0', '1']);
    },
  );

  test('refresh keeps the page size selected by the order list', () async {
    final sizes = <String?>[];
    final provider = BackendDataProvider(
      api: ApiClient(
        baseUrl: 'https://test.local',
        client: MockClient((request) async {
          sizes.add(request.url.queryParameters['size']);
          return http.Response(
            jsonEncode({
              'content': [order('a')],
              'last': true,
              'totalElements': 1,
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(provider.dispose);
    await provider.loadRepairOrders(pageSize: 20);
    await provider.loadRepairOrders();
    expect(sizes, ['20', '20']);
  });

  test('failed next page retains orders and retries the same page', () async {
    var fail = true;
    final provider = BackendDataProvider(
      api: ApiClient(
        baseUrl: 'https://test.local',
        client: MockClient((request) async {
          final second = request.url.queryParameters['page'] == '1';
          if (second && fail) return http.Response('{"message":"Failed"}', 400);
          return http.Response(
            jsonEncode({
              'content': [order(second ? 'b' : 'a')],
              'totalElements': 2,
              'last': second,
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(provider.dispose);
    await provider.loadRepairOrders();
    await provider.loadMoreRepairOrders();
    expect(provider.repairOrders.map((o) => o.id), ['a']);
    expect(provider.repairOrdersPageError, isNotNull);
    fail = false;
    await provider.loadMoreRepairOrders();
    expect(provider.repairOrders.map((o) => o.id), ['a', 'b']);
    expect(provider.repairOrdersPageError, isNull);
  });

  test('refresh discards an in-flight older page', () async {
    final pending = Completer<http.Response>();
    var refresh = false;
    final provider = BackendDataProvider(
      api: ApiClient(
        baseUrl: 'https://test.local',
        client: MockClient((request) async {
          if (request.url.queryParameters['page'] == '1') return pending.future;
          return http.Response(
            jsonEncode({
              'content': [order(refresh ? 'new' : 'old')],
              'totalElements': 2,
              'last': false,
            }),
            200,
          );
        }),
      ),
    );
    addTearDown(provider.dispose);
    await provider.loadRepairOrders();
    final more = provider.loadMoreRepairOrders();
    refresh = true;
    await provider.loadRepairOrders();
    pending.complete(
      http.Response(
        jsonEncode({
          'content': [order('stale')],
          'totalElements': 2,
          'last': true,
        }),
        200,
      ),
    );
    await more;
    expect(provider.repairOrders.map((o) => o.id), ['new']);
  });
}

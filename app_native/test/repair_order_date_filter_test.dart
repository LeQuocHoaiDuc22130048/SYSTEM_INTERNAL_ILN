import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/screens/repair_orders_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';

void main() {
  testWidgets(
    'Vietnamese date sheet filters inclusive presets, a calendar day, and resets to all orders',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dates = {
        'Today device': today,
        'Yesterday device': DateTime(today.year, today.month, today.day - 1),
        'Six days ago': DateTime(today.year, today.month, today.day - 6),
        'Seven days ago': DateTime(today.year, today.month, today.day - 7),
        'Month start': DateTime(today.year, today.month, 1),
        'Previous month': DateTime(today.year, today.month, 0),
      };
      final api = ApiClient(
        baseUrl: 'https://test.local',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'content': dates.entries.indexed
                  .map(
                    (item) => {
                      'id': 'date-${item.$1}',
                      'orderCode': 'DATE-${item.$1}',
                      'deviceName': item.$2.key,
                      'customerName': 'Customer',
                      'status': 'PENDING',
                      'createdAt': item.$2.value
                          .add(const Duration(hours: 12))
                          .toIso8601String(),
                    },
                  )
                  .toList(),
            }),
            200,
          ),
        ),
      );
      final backend = BackendDataProvider(api: api);
      final auth = AuthProvider(apiClient: api);
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

      Future<void> openFilter() async {
        await tester.tap(
          find.byKey(const ValueKey('repair-order-date-filter-button')),
        );
        await tester.pumpAndSettle();
      }

      Future<void> expectOrders(Set<String> names) async {
        // Scroll the list so every matching card is built, without opening it.
        final list = find.byType(ListView).last;
        expect(
          tester.widget<ListView>(list).childrenDelegate.estimatedChildCount,
          names.length + 1,
        );
        for (final name in names) {
          await tester.scrollUntilVisible(
            find.text(name),
            120,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
          expect(find.text(name), findsOneWidget);
        }
        for (final name in dates.keys.where((name) => !names.contains(name))) {
          expect(find.text(name), findsNothing);
        }
      }

      await openFilter();
      expect(find.text('Lọc theo ngày nhận đơn'), findsOneWidget);
      final calendar = find.byType(CalendarDatePicker);
      expect(
        Localizations.localeOf(tester.element(calendar)),
        const Locale('vi', 'VN'),
      );
      expect(
        MaterialLocalizations.of(
          tester.element(calendar),
        ).formatMonthYear(today).toLowerCase(),
        contains('tháng'),
      );
      for (final name in ['Hôm nay', 'Hôm qua', '7 ngày qua', 'Tháng này']) {
        expect(find.widgetWithText(ActionChip, name), findsOneWidget);
        expect(
          tester.getTopLeft(find.text(name)).dy,
          lessThan(tester.getTopLeft(calendar).dy),
        );
      }
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      await expectOrders({'Today device', if (today.day == 1) 'Month start'});
      await openFilter();
      await tester.tap(find.text('Hôm qua'));
      await tester.pumpAndSettle();
      await expectOrders({
        'Yesterday device',
        if (today.day == 2) 'Month start',
        if (today.day == 1) 'Previous month',
      });
      await openFilter();
      await tester.tap(find.text('7 ngày qua'));
      await tester.pumpAndSettle();
      await expectOrders({
        'Today device',
        'Yesterday device',
        'Six days ago',
        if (today.day <= 7) 'Month start',
        if (today.day <= 6) 'Previous month',
      });
      await openFilter();
      await tester.tap(find.text('Tháng này'));
      await tester.pumpAndSettle();
      await expectOrders({
        'Today device',
        'Month start',
        if (today.day > 1) 'Yesterday device',
        if (today.day > 6) 'Six days ago',
        if (today.day > 7) 'Seven days ago',
      });
      await openFilter();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      picker.onDateChanged(today);
      await tester.pumpAndSettle();
      await expectOrders({'Today device', if (today.day == 1) 'Month start'});
      await openFilter();
      await tester.tap(find.widgetWithText(TextButton, 'Tất cả'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('repair-order-date-clear-button')),
        findsNothing,
      );
      await expectOrders(dates.keys.toSet());
      expect(tester.takeException(), isNull);
    },
  );
}

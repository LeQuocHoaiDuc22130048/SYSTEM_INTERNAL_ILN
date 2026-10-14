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
          ? 'status update failure keeps sheet open for retry'
          : 'status update keeps the same detail sheet and refreshes its status',
      (tester) async {
        tester.view.physicalSize = fails
            ? const Size(320, 700)
            : const Size(550, 900);
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
        final editBtn = find.widgetWithText(ElevatedButton, 'Chỉnh sửa');
        final deleteBtn = find.byTooltip('Xóa đơn hàng');
        expect(update, findsOneWidget);
        final detailTitle = find.text('Chi tiết đơn sửa chữa');
        final detailElement = tester.element(detailTitle);
        expect(editBtn, findsOneWidget);
        expect(deleteBtn, findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Đóng'), findsNothing);
        expect(
          tester.getTopLeft(update).dy,
          greaterThan(tester.getTopLeft(deleteBtn).dy),
        );
        // Verify 2 main action buttons are on the same horizontal row
        expect(
          (tester.getTopLeft(update).dy - tester.getTopLeft(editBtn).dy).abs(),
          lessThan(4.0),
        );
        await tester.ensureVisible(update);
        await tester.tap(update);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.byKey(const ValueKey('order-status-update-sheet')),
          findsOneWidget,
        );
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Lưu thay đổi'),
              )
              .onPressed,
          isNull,
        );
        expect(find.byType(ChoiceChip), findsNWidgets(8));
        final cancel = find.widgetWithText(OutlinedButton, 'Hủy');
        final save = find.widgetWithText(ElevatedButton, 'Lưu thay đổi');
        expect(
          tester.getSize(cancel).width,
          closeTo(tester.getSize(save).width, 0.01),
        );
        if (fails) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(450));
        }
        await tester.tap(
          find.byKey(const ValueKey('update-status-WAITING_FOR_CHECK')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '  Ready  ');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu thay đổi'));
        await tester.pumpAndSettle();
        expect(submitted, {'status': 'WAITING_FOR_CHECK', 'note': 'Ready'});
        if (fails) {
          expect(
            find.byKey(const ValueKey('order-status-update-sheet')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Lưu thay đổi'),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(find.byType(AlertDialog), findsNothing);
          expect(backend.repairOrders.single.statusLabel, 'Chờ kiểm tra');
          expect(find.text('Chờ kiểm tra'), findsWidgets);
          expect(detailTitle, findsOneWidget);
          expect(tester.element(detailTitle), same(detailElement));
          final detail = find
              .ancestor(of: detailTitle, matching: find.byType(BottomSheet))
              .first;
          expect(
            find.descendant(of: detail, matching: find.text('Chờ kiểm tra')),
            findsOneWidget,
          );
          await tester.tap(
            find.widgetWithText(OutlinedButton, 'Cập nhật trạng thái'),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(
                  find.byKey(const ValueKey('update-status-WAITING_FOR_CHECK')),
                )
                .selected,
            isTrue,
          );
          await tester.tap(find.widgetWithText(OutlinedButton, 'Hủy'));
          await tester.pumpAndSettle();
          expect(detailTitle, findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'mobile list hides duplicate header create button, separates date filter, and groups edit form into 3 sections',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = ApiClient(
        baseUrl: 'https://test.local',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/employees') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'content': [
                    {
                      'id': 'tech-1',
                      'fullName': 'Nguyễn Tấn Phát',
                      'employeeCode': 'NV001',
                      'role': 'TECHNICIAN',
                      'status': 'ACTIVE',
                    },
                    {
                      'id': 'tech-2',
                      'fullName': 'Trần Bá Tường',
                      'employeeCode': 'NV002',
                      'role': 'TECHNICIAN',
                      'status': 'ACTIVE',
                    },
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'content': [
                  {
                    'id': 'order-1',
                    'orderCode': 'RO-20261013',
                    'deviceName': 'Biến tần Luxpower SNA 6K',
                    'customerName': 'Anh Hùng',
                    'customerPhone': '0987654321',
                    'serialNumber': 'SN-LUX-9988',
                    'underWarranty': true,
                    'warrantyExpiry': '2027-10-13T00:00:00Z',
                    'status': 'PENDING',
                    'createdAt': '2026-10-13T08:30:00Z',
                    'assigneeNames': ['Nguyễn Văn Kỹ Thuật'],
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
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

      // 1. Duplicate 'Tạo đơn' button in header is hidden on mobile width
      expect(find.text('Tạo đơn'), findsNothing);

      // 2. Date filter button is separated next to search field (above horizontal filter chips)
      final dateFilterBtn = find.byKey(
        const ValueKey('repair-order-date-filter-button'),
      );
      final filterChipsScroll = find.byKey(
        const ValueKey('repair-orders-filter-scroll'),
      );
      expect(dateFilterBtn, findsOneWidget);
      expect(filterChipsScroll, findsOneWidget);
      expect(
        tester.getTopLeft(dateFilterBtn).dy,
        lessThan(tester.getTopLeft(filterChipsScroll).dy),
      );

      // 3. 2-column Order Card displays customer + quick call on left, date + serial on right, and warranty badge
      expect(find.text('Anh Hùng'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('call-customer-order-1')),
        findsOneWidget,
      );
      expect(find.text('SN-LUX-9988'), findsOneWidget);
      expect(find.text('BH • Còn hạn'), findsOneWidget);

      // 4. Open Detail modal -> Open Edit modal and verify 3 grouped section cards & unified technician field
      await tester.tap(find.text('Biến tần Luxpower SNA 6K'));
      await tester.pumpAndSettle();

      expect(find.text('Thông tin khách hàng'), findsOneWidget);
      expect(find.text('Thông tin thiết bị'), findsOneWidget);
      expect(find.text('Phân công & Tiến độ'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Chỉnh sửa'));
      await tester.pumpAndSettle();

      expect(find.text('1. Thông tin khách hàng'), findsOneWidget);
      expect(find.text('2. Thông tin thiết bị'), findsOneWidget);
      expect(find.text('3. Xử lý & Phân công'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('order-technician-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-order-sticky-save-button')),
        findsOneWidget,
      );

      // 5. Open Technician Multi-Select Bottom Sheet -> Search, Toggle All, and verify InputChips
      final techSelector = find.byKey(
        const ValueKey('order-technician-selector'),
      );
      await tester.ensureVisible(techSelector);
      await tester.tap(techSelector);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('technician-picker-search-field')),
        findsOneWidget,
      );
      expect(find.text('Đã chọn (0)'), findsOneWidget);
      expect(find.text('Nguyễn Tấn Phát'), findsOneWidget);
      expect(find.text('Trần Bá Tường'), findsOneWidget);

      // Tap "Chọn tất cả"
      await tester.tap(
        find.byKey(const ValueKey('technician-picker-toggle-all')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn (2)'), findsOneWidget);
      expect(find.text('Bỏ chọn tất cả'), findsOneWidget);

      // Confirm selection -> verify InputChips with delete icon render in the main form
      await tester.tap(
        find.byKey(const ValueKey('technician-picker-confirm-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assigned-tech-chip-tech-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assigned-tech-chip-tech-2')),
        findsOneWidget,
      );

      // 6. Open Order Status Bottom Sheet and select 'Đang sửa'
      final statusSelector = find.byKey(
        const ValueKey('order-status-selector'),
      );
      await tester.ensureVisible(statusSelector);
      await tester.tap(statusSelector);
      await tester.pumpAndSettle();
      expect(find.text('Chọn trạng thái đơn hàng'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('status-option-IN_PROGRESS')));
      await tester.pumpAndSettle();
      expect(find.text('Đang sửa'), findsWidgets);

      // 7. Tap Dashed "+ Thêm ảnh / video" tile and verify Media Action Sheet
      final addMediaTile = find.byKey(const ValueKey('media-picker-add-tile'));
      await tester.ensureVisible(addMediaTile);
      await tester.tap(addMediaTile);
      await tester.pumpAndSettle();
      expect(find.text('Chụp ảnh mới'), findsOneWidget);
      expect(find.text('Chọn từ thư viện'), findsOneWidget);
      expect(find.text('Quay/Chọn video'), findsOneWidget);
    },
  );
}

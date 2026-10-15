import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/customer.dart';
import 'package:system_inverter_likenew/screens/customer_order_link_dialog.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';

class OrderApi extends ApiClient {
  final queries = <Map<String, dynamic>>[];
  Map<String, dynamic>? saved;
  bool failSave = false;
  String? linkedCustomerId;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    queries.add(Map.of(queryParameters ?? {}));
    return {
      'content': [
        {
          'id': 'order-1',
          'orderCode': 'RO-001',
          'deviceName': 'Biến tần',
          'customerName': 'Anh Nam',
          'customerId': linkedCustomerId,
          'status': 'PENDING',
        },
      ],
      'totalPages': 2,
    };
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    if (failSave) throw ApiException(403, 'Không có quyền gán đơn');
    saved = Map<String, dynamic>.from(body as Map);
    return {
      'id': 'order-1',
      'orderCode': 'RO-001',
      'customerId': 'customer-1',
      'customerName': 'Công ty Minh Phát',
      'status': 'PENDING',
    };
  }
}

const customer = Customer(
  id: 'customer-1',
  customerCode: 'KH-001',
  customerName: 'Công ty Minh Phát',
  type: CustomerType.company,
  active: true,
);

class LinkAuth extends AuthProvider {
  @override
  bool can(AppPermission permission) => true;
}

class AssignOnlyAuth extends LinkAuth {
  @override
  bool can(AppPermission permission) =>
      permission == AppPermission.assignOrderCustomer;
}

void main() {
  testWidgets('assignment permission does not expose transfer selection', (
    tester,
  ) async {
    final api = OrderApi()..linkedCustomerId = 'another-customer';
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AssignOnlyAuth(),
        child: MaterialApp(
          home: Scaffold(
            body: CustomerOrderLinkDialog(
              customer: customer,
              backend: BackendDataProvider(api: api),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    expect(tester.widget<ListTile>(find.byType(ListTile).last).onTap, isNull);
    expect(find.text('Xác nhận chuyển đơn'), findsNothing);
  });
  testWidgets(
    'linked orders warn before transfer and cannot be assigned to the same profile',
    (tester) async {
      final api = OrderApi()..linkedCustomerId = 'previous-customer';
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => LinkAuth(),
          child: MaterialApp(
            home: Scaffold(
              body: CustomerOrderLinkDialog(
                customer: customer,
                backend: BackendDataProvider(api: api),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('RO-001 · Biến tần'));
      await tester.pumpAndSettle();
      expect(
        find.text('Đơn sẽ được chuyển khỏi khách hàng hiện tại.'),
        findsOneWidget,
      );
      expect(find.text('Xác nhận chuyển đơn'), findsOneWidget);
      api.linkedCustomerId = customer.id;
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListTile>(find.byType(ListTile).last).enabled,
        false,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận gán đơn'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'requires a reason and confirms replacement of the old customer name',
    (tester) async {
      final api = OrderApi();
      final backend = BackendDataProvider(api: api);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => LinkAuth(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => CustomerOrderLinkDialog(
                      customer: customer,
                      backend: backend,
                    ),
                  ),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(api.queries.single['unlinkedOnly'], true);
      await tester.tap(find.text('RO-001 · Biến tần'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Anh Nam” thành “Công ty Minh Phát'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xác nhận gán đơn'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('link-order-reason')),
        'Xác minh khách hàng',
      );
      await tester.pump();
      await tester.tap(find.text('Xác nhận gán đơn'));
      await tester.pumpAndSettle();
      expect(api.saved, {
        'customerId': 'customer-1',
        'reason': 'Xác minh khách hàng',
      });
      expect(find.byType(CustomerOrderLinkDialog), findsNothing);
    },
  );

  testWidgets(
    'search, unlinked filter and pagination reach the server; denied save stays open',
    (tester) async {
      final api = OrderApi()..failSave = true;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => LinkAuth(),
          child: MaterialApp(
            home: Scaffold(
              body: CustomerOrderLinkDialog(
                customer: customer,
                backend: BackendDataProvider(api: api),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('link-order-search')),
        '090123',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(api.queries.last['keyword'], '090123');
      await tester.ensureVisible(find.text('Sau'));
      await tester.tap(find.text('Sau'));
      await tester.pumpAndSettle();
      expect(api.queries.last['page'], 1);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(api.queries.last['unlinkedOnly'], false);
      expect(api.queries.last['page'], 0);
      await tester.tap(find.text('RO-001 · Biến tần'));
      await tester.ensureVisible(find.byKey(const Key('link-order-reason')));
      await tester.enterText(
        find.byKey(const Key('link-order-reason')),
        'Xác minh',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận gán đơn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không có quyền gán đơn'), findsOneWidget);
      expect(find.byType(CustomerOrderLinkDialog), findsOneWidget);
    },
  );
}

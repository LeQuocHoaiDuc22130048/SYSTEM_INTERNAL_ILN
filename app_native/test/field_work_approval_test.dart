import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/attendance.dart';
import 'package:system_inverter_likenew/models/app_notification.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:system_inverter_likenew/navigation/main_tabs.dart';
import 'package:system_inverter_likenew/navigation/notification_navigation_resolver.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';
import 'package:system_inverter_likenew/utils/notification_provider.dart';
import 'package:system_inverter_likenew/widgets/field_work_requests.dart';

class _Admin extends AuthProvider {
  _Admin(ApiClient api) : super(apiClient: api);
  @override bool get isAdminOrAbove => true;
  @override bool can(AppPermission permission) => true;
}
void main() {
  test('parses approval status and version without treating pending as approved', () {
    final day = FieldWorkDay.fromJson({'id': 'request', 'employeeId': 'employee',
      'workDate': '2026-10-15', 'note': 'ABC', 'status': 'PENDING', 'version': 3});
    expect(day.status, 'PENDING'); expect(day.version, 3);
  });
  test('field work notification opens the dashboard approval list', () {
    final auth = _Admin(ApiClient());
    addTearDown(auth.dispose);
    final target = resolveNotificationNavigation(const AppNotification(
      id: 'n', recipientId: 'admin', type: 'FIELD_WORK_PENDING', refType: 'FIELD_WORK',
      title: 'Pending', body: 'ABC', isRead: false), auth: auth);
    expect(target?.tabIndex, MainTabs.dashboard);
  });
  testWidgets('administrator accepts a pending request using its displayed version', (tester) async {
    var pending = true;
    Map<String, dynamic>? decision;
    final api = ApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      if (request.method == 'PUT') {
        expect(request.url.path, '/api/attendance/field-work/request/review');
        decision = jsonDecode(request.body) as Map<String, dynamic>;
        pending = false;
        return http.Response('{"data":{}}', 200);
      }
      return http.Response(jsonEncode({'data': pending ? [{
        'id': 'request', 'employeeId': 'employee', 'employeeName': 'Employee A',
        'workDate': '2026-10-15', 'note': 'ABC', 'status': 'PENDING', 'version': 3,
      }] : []}), 200, headers: {'content-type': 'application/json'});
    }));
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _Admin(api)),
      ChangeNotifierProvider(create: (_) => BackendDataProvider(api: api)),
      ChangeNotifierProvider(create: (_) => NotificationProvider(api: api)),
    ], child: const MaterialApp(home: Scaffold(body: FieldWorkRequests()))));
    await tester.pumpAndSettle();
    expect(find.text('ABC'), findsOneWidget);
    // Select the accept action, then confirm the decision in the dialog.
    final buttons = find.byType(TextButton);
    await tester.tap(buttons.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(decision, {'approve': true, 'version': 3});
    expect(find.text('ABC'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

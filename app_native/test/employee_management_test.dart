import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/screens/employee_management_page.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/utils/backend_data_provider.dart';

void main() {
  testWidgets('EmployeeManagementPage renders without overflow on phone dimensions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.contains('/employees')) {
          return http.Response(
            '''
            [
              {
                "id": "1",
                "username": "duc",
                "fullName": "Nguyễn Văn Hoàng Nam",
                "role": "TECHNICIAN",
                "status": "ACTIVE",
                "department": "Kỹ thuật sửa chữa biến tần"
              },
              {
                "id": "2",
                "username": "tech_user",
                "fullName": "Trần Thị Thu Thảo",
                "role": "EMPLOYEE",
                "status": "ACTIVE",
                "department": "Kế toán tài chính & nhân sự"
              }
            ]
            ''',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }),
    );

    final auth = AuthProvider(apiClient: api);
    final backend = BackendDataProvider(api: api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: backend),
        ],
        child: const MaterialApp(
          home: EmployeeManagementPage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify no exception was thrown
    expect(tester.takeException(), isNull);
  });

  testWidgets('EmployeeManagementPage renders without overflow on 360x640 with textScaler', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = ApiClient(
      client: MockClient((request) async {
        return http.Response(
          '''
          [
            {
              "id": "1",
              "username": "duc",
              "fullName": "Nguyễn Văn Hoàng Nam",
              "role": "TECHNICIAN",
              "status": "ACTIVE",
              "department": "Kỹ thuật sửa chữa biến tần"
            },
            {
              "id": "2",
              "username": "tech_user",
              "fullName": "Trần Thị Thu Thảo",
              "role": "EMPLOYEE",
              "status": "INACTIVE",
              "department": "Kế toán tài chính & nhân sự"
            }
          ]
          ''',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final auth = AuthProvider(apiClient: api);
    final backend = BackendDataProvider(api: api);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: backend),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.15),
            ),
            child: const EmployeeManagementPage(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nguyễn Văn Hoàng Nam'), findsOneWidget);
    expect(find.text('Trần Thị Thu Thảo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

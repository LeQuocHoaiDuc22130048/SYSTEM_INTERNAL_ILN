import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/widgets/permission_gate.dart';

class ActionAuth extends AuthProvider {
  Set<AppPermission> allowed = {AppPermission.createRepairOrders};
  @override
  bool can(AppPermission permission) => allowed.contains(permission);
  void revoke() {
    allowed = {};
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'create-only account cannot see update and loses the create action after revocation',
    (tester) async {
      final auth = ActionAuth();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  PermissionGate(
                    permission: AppPermission.createRepairOrders,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Tạo đơn'),
                    ),
                  ),
                  PermissionGate(
                    permission: AppPermission.updateRepairOrders,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Sửa đơn'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Tạo đơn'), findsOneWidget);
      expect(find.text('Sửa đơn'), findsNothing);
      auth.revoke();
      await tester.pump();
      expect(find.text('Tạo đơn'), findsNothing);
    },
  );
}

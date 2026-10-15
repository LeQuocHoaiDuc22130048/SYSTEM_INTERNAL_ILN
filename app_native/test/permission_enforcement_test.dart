import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/user.dart';
import 'package:system_inverter_likenew/models/app_permission.dart';

void main() {
  test('empty server permissions do not restore role defaults', () {
    final user = User.fromJson({
      'id': 'u1',
      'username': 'admin',
      'fullName': 'Admin',
      'role': 'ADMIN',
      'permissions': [],
    });
    expect(user.can(AppPermission.manageCustomers), false);
  });
  test('SUPER_ADMIN has immutable system access', () {
    final user = User.fromJson({
      'id': 'u1',
      'username': 'root',
      'fullName': 'Root',
      'role': 'SUPER_ADMIN',
      'permissions': [],
    });
    expect(user.can(AppPermission.manageCustomers), true);
  });
}

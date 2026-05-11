enum UserRole { superAdmin, admin, manager, employee }

enum UserStatus { active, suspended, pending }

class User {
  final String id;
  final String name;
  final String email;
  final String employeeId;
  final UserRole role;
  final UserStatus status;
  final String? avatar;
  final String? department;
  final String? phone;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.role,
    required this.status,
    this.avatar,
    this.department,
    this.phone,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.employee:
        return 'Nhân viên';
    }
  }
}

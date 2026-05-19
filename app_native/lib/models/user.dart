enum UserRole { superAdmin, admin, manager, employee }

enum UserStatus { active, suspended, pending }

class User {
  final String id;
  final String username;
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
    this.username = '',
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

  static UserRole roleFromBackend(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'ADMIN':
        return UserRole.admin;
      case 'MANAGER':
        return UserRole.manager;
      default:
        return UserRole.employee;
    }
  }

  static UserStatus statusFromBackend(String? status) {
    switch (status) {
      case 'ACTIVE':
        return UserStatus.active;
      case 'SUSPENDED':
        return UserStatus.suspended;
      default:
        return UserStatus.pending;
    }
  }

  factory User.fromLoginJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    return User(
      id: json['id']?.toString() ?? '',
      username: username,
      name: json['fullName']?.toString() ?? username,
      email: username,
      employeeId: '',
      role: roleFromBackend(json['role']?.toString()),
      status: statusFromBackend(json['status']?.toString()),
      avatar: json['avatarUrl']?.toString(),
      department: json['department']?.toString(),
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final username = json['username']?.toString() ?? '';
    return User(
      id: json['id']?.toString() ?? '',
      username: username,
      name: json['fullName']?.toString() ?? username,
      email: username,
      employeeId: json['employeeCode']?.toString() ?? '',
      role: roleFromBackend(json['role']?.toString()),
      status: statusFromBackend(json['status']?.toString()),
      avatar: json['avatarUrl']?.toString(),
      department: json['department']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

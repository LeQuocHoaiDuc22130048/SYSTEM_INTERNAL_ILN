import 'app_permission.dart';

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
  final bool faceEnrolled;
  final Set<AppPermission>? permissions;

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
    this.faceEnrolled = false,
    this.permissions,
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
      faceEnrolled: json['faceEnrolled'] == true,
      permissions: permissionsFromBackend(json['permissions']),
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
      faceEnrolled: json['faceEnrolled'] == true,
      permissions: permissionsFromBackend(json['permissions']),
    );
  }

  bool can(AppPermission permission) {
    final serverPermissions = permissions;
    if (serverPermissions != null) {
      return serverPermissions.contains(permission);
    }
    return role.can(permission);
  }

  static Set<AppPermission>? permissionsFromBackend(Object? value) {
    if (value is! List) return null;
    return value
        .map(
          (item) => AppPermissionBackendCode.fromBackendCode(item.toString()),
        )
        .whereType<AppPermission>()
        .toSet();
  }
}

extension UserRolePermissions on UserRole {
  bool get isManagerOrAbove =>
      this == UserRole.manager ||
      this == UserRole.admin ||
      this == UserRole.superAdmin;

  bool get isAdminOrAbove =>
      this == UserRole.admin || this == UserRole.superAdmin;

  bool can(AppPermission permission) => permissions.contains(permission);

  Set<AppPermission> get permissions {
    const employeePermissions = {
      AppPermission.viewRepairOrders,
      AppPermission.manageRepairOrders,
      AppPermission.viewWarehouse,
      AppPermission.manageWarehouse,
      AppPermission.useMessages,
      AppPermission.viewNotifications,
      AppPermission.viewAttendance,
      AppPermission.viewProfile,
      AppPermission.updateOwnProfile,
    };

    const managerPermissions = {
      ...employeePermissions,
      AppPermission.viewDashboard,
      AppPermission.assignRepairOrders,
      AppPermission.manageAttendance,
      AppPermission.manageEmployees,
      AppPermission.approveAccounts,
    };

    const adminPermissions = {
      ...managerPermissions,
      AppPermission.deleteWarehouse,
      AppPermission.manageEmployeeSecurity,
    };

    switch (this) {
      case UserRole.superAdmin:
        return AppPermission.values.toSet();
      case UserRole.admin:
        return adminPermissions;
      case UserRole.manager:
        return managerPermissions;
      case UserRole.employee:
        return employeePermissions;
    }
  }
}

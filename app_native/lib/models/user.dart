import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_permission.dart';

// {{START_USER_ROLE_ENUM}}
enum UserRole {
  superAdmin,
  admin,
  manager,
  technician,
  warehouse,
  employee,
  attendance,
  customer,
}
// {{END_USER_ROLE_ENUM}}

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

  // {{START_ROLE_LABEL}}
  String get roleLabel => role.label;
  // {{END_ROLE_LABEL}}

  // {{START_ROLE_FROM_BACKEND}}
  static UserRole roleFromBackend(String? role) {
    switch (role) {
      case 'SUPER_ADMIN':
        return UserRole.superAdmin;
      case 'ADMIN':
        return UserRole.admin;
      case 'MANAGER':
        return UserRole.manager;
      case 'TECHNICIAN':
        return UserRole.technician;
      case 'WAREHOUSE':
        return UserRole.warehouse;
      case 'ATTENDANCE':
        return UserRole.attendance;
      case 'CUSTOMER':
        return UserRole.customer;
      default:
        return UserRole.employee;
    }
  }
  // {{END_ROLE_FROM_BACKEND}}

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
    if (role == UserRole.superAdmin) return true;
    final serverPermissions = permissions;
    if (serverPermissions != null) {
      final aliases = legacyPermissionAliases[permission];
      return aliases == null ? serverPermissions.contains(permission) : aliases.any(serverPermissions.contains);
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

  User copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? employeeId,
    UserRole? role,
    UserStatus? status,
    String? avatar,
    String? department,
    String? phone,
    bool? faceEnrolled,
    Set<AppPermission>? permissions,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      role: role ?? this.role,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      faceEnrolled: faceEnrolled ?? this.faceEnrolled,
      permissions: permissions ?? this.permissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'fullName': name,
      'email': email,
      'employeeCode': employeeId,
      'role': role.backendCode,
      'status': status.name.toUpperCase(),
      'avatarUrl': avatar,
      'department': department,
      'phone': phone,
      'faceEnrolled': faceEnrolled,
      'permissions': permissions?.map((p) => p.backendCode).toList(),
    };
  }
}

extension UserRolePermissions on UserRole {
  // {{START_ROLE_AVATAR_COLOR}}
  Color get avatarColor {
    switch (this) {
      case UserRole.superAdmin:
        return AppColors.purple;
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.manager:
        return const Color(0xFF6366F1);
      case UserRole.technician:
        return const Color(0xFF0D9488);
      case UserRole.warehouse:
        return const Color(0xFFD97706);
      case UserRole.employee:
        return AppColors.success;
      case UserRole.attendance:
        return const Color(0xFF3B82F6);
      case UserRole.customer:
        return const Color(0xFF2563EB);
    }
  }
  // {{END_ROLE_AVATAR_COLOR}}

  // {{START_ROLE_LABEL_GETTER}}
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.technician:
        return 'Kỹ thuật viên';
      case UserRole.warehouse:
        return 'Thủ kho';
      case UserRole.employee:
        return 'Nhân viên';
      case UserRole.attendance:
        return 'Máy chấm công';
      case UserRole.customer:
        return 'Khách hàng';
    }
  }
  // {{END_ROLE_LABEL_GETTER}}

  // {{START_ROLE_BACKEND_CODE}}
  String get backendCode {
    switch (this) {
      case UserRole.superAdmin:
        return 'SUPER_ADMIN';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.manager:
        return 'MANAGER';
      case UserRole.technician:
        return 'TECHNICIAN';
      case UserRole.warehouse:
        return 'WAREHOUSE';
      case UserRole.employee:
        return 'EMPLOYEE';
      case UserRole.attendance:
        return 'ATTENDANCE';
      case UserRole.customer:
        return 'CUSTOMER';
    }
  }
  // {{END_ROLE_BACKEND_CODE}}

  bool get isManagerOrAbove =>
      this == UserRole.manager ||
      this == UserRole.admin ||
      this == UserRole.superAdmin;

  bool get isAdminOrAbove =>
      this == UserRole.admin || this == UserRole.superAdmin;

  bool can(AppPermission permission) => permissions.contains(permission);

  Set<AppPermission> get permissions {
    const basePermissions = {
      AppPermission.viewDevices,
      AppPermission.viewDashboard,
      AppPermission.viewRepairOrders,
      AppPermission.manageRepairOrders,
      AppPermission.updateRepairOrderStatus,
      AppPermission.viewWarehouse,
      AppPermission.manageWarehouse,
      AppPermission.useMessages,
      AppPermission.viewAttendance,
      AppPermission.viewProfile,
      AppPermission.updateOwnProfile,
      AppPermission.viewCustomers,
    };

    const employeePermissions = {
      ...basePermissions,
      AppPermission.manageCustomers,
    };

    const technicianPermissions = {
      AppPermission.viewDevices,
      AppPermission.viewDashboard,
      AppPermission.viewRepairOrders,
      AppPermission.manageRepairOrders,
      AppPermission.updateRepairOrderStatus,
      AppPermission.assignRepairOrders,
      AppPermission.viewCustomers,
      AppPermission.viewProfile,
      AppPermission.updateOwnProfile,
    };

    const warehousePermissions = {
      ...basePermissions,
      AppPermission.viewNotifications,
    };

    const managerPermissions = {
      AppPermission.manageDevices,
      AppPermission.manageBanners,
      AppPermission.deleteRepairOrders,
      ...employeePermissions,
      AppPermission.viewNotifications,
      AppPermission.assignRepairOrders,
      AppPermission.manageAttendance,
      AppPermission.manageEmployees,
      AppPermission.approveAccounts,
    };

    const adminPermissions = {
      AppPermission.manageAppUpdates,
      AppPermission.managePermissions,
      ...managerPermissions,
      AppPermission.deleteWarehouse,
      AppPermission.manageEmployeeSecurity,
    };

    // {{START_ROLE_PERMISSIONS_SWITCH}}
    switch (this) {
      case UserRole.superAdmin:
        return AppPermission.values.toSet();
      case UserRole.admin:
        return _expandRoleDefaults(adminPermissions);
      case UserRole.manager:
        return _expandRoleDefaults(managerPermissions);
      case UserRole.technician:
        return _expandRoleDefaults(technicianPermissions);
      case UserRole.warehouse:
        return _expandRoleDefaults(warehousePermissions);
      case UserRole.employee:
        return _expandRoleDefaults(employeePermissions);
      case UserRole.attendance:
        return const {AppPermission.viewAttendance, AppPermission.useAttendanceKiosk};
      case UserRole.customer:
        return const {};
    }
    // {{END_ROLE_PERMISSIONS_SWITCH}}
  }
}

Set<AppPermission> _expandRoleDefaults(Set<AppPermission> initial) {
  final result = {...initial};
  for (final entry in rolePermissionExpansion.entries) {
    if (initial.contains(entry.key)) result.addAll(entry.value);
  }
  if (initial.contains(AppPermission.assignRepairOrders) || initial.contains(AppPermission.manageAttendance)) {
    result.add(AppPermission.useAttendanceKiosk);
  }
  return result;
}

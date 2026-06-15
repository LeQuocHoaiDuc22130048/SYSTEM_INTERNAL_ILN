enum AppPermission {
  viewDashboard,
  viewRepairOrders,
  manageRepairOrders,
  assignRepairOrders,
  viewWarehouse,
  manageWarehouse,
  deleteWarehouse,
  useMessages,
  viewNotifications,
  viewAttendance,
  manageAttendance,
  manageEmployees,
  approveAccounts,
  manageEmployeeSecurity,
  viewProfile,
  updateOwnProfile,
}

extension AppPermissionBackendCode on AppPermission {
  String get backendCode {
    switch (this) {
      case AppPermission.viewDashboard:
        return 'DASHBOARD_VIEW';
      case AppPermission.viewRepairOrders:
        return 'REPAIR_VIEW';
      case AppPermission.manageRepairOrders:
        return 'REPAIR_MANAGE';
      case AppPermission.assignRepairOrders:
        return 'REPAIR_ASSIGN';
      case AppPermission.viewWarehouse:
        return 'WAREHOUSE_VIEW';
      case AppPermission.manageWarehouse:
        return 'WAREHOUSE_MANAGE';
      case AppPermission.deleteWarehouse:
        return 'WAREHOUSE_DELETE';
      case AppPermission.useMessages:
        return 'MESSAGING_USE';
      case AppPermission.viewNotifications:
        return 'NOTIFICATION_VIEW';
      case AppPermission.viewAttendance:
        return 'ATTENDANCE_VIEW';
      case AppPermission.manageAttendance:
        return 'ATTENDANCE_MANAGE';
      case AppPermission.manageEmployees:
        return 'EMPLOYEE_MANAGE';
      case AppPermission.approveAccounts:
        return 'ACCOUNT_APPROVE';
      case AppPermission.manageEmployeeSecurity:
        return 'EMPLOYEE_SECURITY_MANAGE';
      case AppPermission.viewProfile:
        return 'PROFILE_VIEW';
      case AppPermission.updateOwnProfile:
        return 'PROFILE_UPDATE_SELF';
    }
  }

  static AppPermission? fromBackendCode(String code) {
    for (final permission in AppPermission.values) {
      if (permission.backendCode == code) return permission;
    }
    return null;
  }
}

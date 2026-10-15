enum AppPermission {
  createRepairOrders,
  updateRepairOrders,
  cancelRepairOrders,
  reorderRepairOrders,
  uploadRepairMedia,
  deleteRepairMedia,
  viewRepairTimeline,
  createCustomers,
  updateCustomers,
  updateCustomerStatus,
  assignOrderCustomer,
  transferOrderCustomer,
  viewCustomerOrders,
  createBoards,
  updateBoards,
  deleteBoards,
  checkoutBoards,
  returnBoards,
  viewBoardHistory,
  createParts,
  updateParts,
  deleteParts,
  importParts,
  adjustPartStock,
  checkoutParts,
  returnParts,
  viewPartHistory,
  createLocations,
  updateLocations,
  deleteLocations,
  printWarehouseQr,
  checkOwnAttendance,
  createAttendanceRecords,
  updateAttendanceRecords,
  deleteAttendanceRecords,
  viewAttendanceReports,
  exportAttendance,
  viewSchedules,
  updateSchedules,
  saveFieldWork,
  deleteFieldWork,
  useAttendanceKiosk,
  viewEmployees,
  updateEmployees,
  updateEmployeeStatus,
  enrollEmployeeFace,
  deleteEmployeeFace,
  createDevices,
  updateDevices,
  deleteDevices,
  updateDeviceStatus,
  pingDevices,
  viewBanners,
  createBanners,
  updateBanners,
  updateBannerStatus,
  reorderBanners,
  deleteBanners,
  viewAppUpdates,
  uploadAppUpdates,
  releaseAppUpdates,
  deleteAppUpdates,
  viewPermissions,
  updatePermissions,
  resetPermissions,
  createConversations,
  updateConversations,
  addConversationMembers,
  removeConversationMembers,
  updateConversationMemberRole,
  leaveConversations,
  pinConversations,
  muteConversations,
  markConversationsRead,
  sendMessages,
  uploadMessages,
  updateMessages,
  deleteMessages,
  reactMessages,
  pinMessages,
  markNotificationsRead,

  viewDevices,
  manageDevices,
  manageBanners,
  manageAppUpdates,
  managePermissions,
  deleteRepairOrders,
  viewDashboard,
  viewRepairOrders,
  manageRepairOrders,
  updateRepairOrderStatus,
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
  viewCustomers,
  manageCustomers,
}

extension AppPermissionBackendCode on AppPermission {
  String get backendCode {
    switch (this) {
      case AppPermission.createRepairOrders:
        return 'REPAIR_CREATE';
      case AppPermission.updateRepairOrders:
        return 'REPAIR_UPDATE';
      case AppPermission.cancelRepairOrders:
        return 'REPAIR_CANCEL';
      case AppPermission.reorderRepairOrders:
        return 'REPAIR_REORDER';
      case AppPermission.uploadRepairMedia:
        return 'REPAIR_MEDIA_UPLOAD';
      case AppPermission.deleteRepairMedia:
        return 'REPAIR_MEDIA_DELETE';
      case AppPermission.viewRepairTimeline:
        return 'REPAIR_TIMELINE_VIEW';
      case AppPermission.createCustomers:
        return 'CUSTOMER_CREATE';
      case AppPermission.updateCustomers:
        return 'CUSTOMER_UPDATE';
      case AppPermission.updateCustomerStatus:
        return 'CUSTOMER_STATUS_UPDATE';
      case AppPermission.assignOrderCustomer:
        return 'CUSTOMER_ASSIGN';
      case AppPermission.transferOrderCustomer:
        return 'CUSTOMER_TRANSFER';
      case AppPermission.viewCustomerOrders:
        return 'CUSTOMER_HISTORY_VIEW';
      case AppPermission.createBoards:
        return 'BOARD_CREATE';
      case AppPermission.updateBoards:
        return 'BOARD_UPDATE';
      case AppPermission.deleteBoards:
        return 'BOARD_DELETE';
      case AppPermission.checkoutBoards:
        return 'BOARD_CHECKOUT';
      case AppPermission.returnBoards:
        return 'BOARD_RETURN';
      case AppPermission.viewBoardHistory:
        return 'BOARD_HISTORY_VIEW';
      case AppPermission.createParts:
        return 'PART_CREATE';
      case AppPermission.updateParts:
        return 'PART_UPDATE';
      case AppPermission.deleteParts:
        return 'PART_DELETE';
      case AppPermission.importParts:
        return 'PART_IMPORT';
      case AppPermission.adjustPartStock:
        return 'PART_STOCK_ADJUST';
      case AppPermission.checkoutParts:
        return 'PART_CHECKOUT';
      case AppPermission.returnParts:
        return 'PART_RETURN';
      case AppPermission.viewPartHistory:
        return 'PART_HISTORY_VIEW';
      case AppPermission.createLocations:
        return 'LOCATION_CREATE';
      case AppPermission.updateLocations:
        return 'LOCATION_UPDATE';
      case AppPermission.deleteLocations:
        return 'LOCATION_DELETE';
      case AppPermission.printWarehouseQr:
        return 'WAREHOUSE_QR_PRINT';
      case AppPermission.checkOwnAttendance:
        return 'ATTENDANCE_CHECK_SELF';
      case AppPermission.createAttendanceRecords:
        return 'ATTENDANCE_RECORD_CREATE';
      case AppPermission.updateAttendanceRecords:
        return 'ATTENDANCE_RECORD_UPDATE';
      case AppPermission.deleteAttendanceRecords:
        return 'ATTENDANCE_RECORD_DELETE';
      case AppPermission.viewAttendanceReports:
        return 'ATTENDANCE_REPORT_VIEW';
      case AppPermission.exportAttendance:
        return 'ATTENDANCE_EXPORT';
      case AppPermission.viewSchedules:
        return 'SCHEDULE_VIEW';
      case AppPermission.updateSchedules:
        return 'SCHEDULE_UPDATE';
      case AppPermission.saveFieldWork:
        return 'FIELD_WORK_SAVE';
      case AppPermission.deleteFieldWork:
        return 'FIELD_WORK_DELETE';
      case AppPermission.useAttendanceKiosk:
        return 'ATTENDANCE_KIOSK_USE';
      case AppPermission.viewEmployees:
        return 'EMPLOYEE_VIEW';
      case AppPermission.updateEmployees:
        return 'EMPLOYEE_UPDATE';
      case AppPermission.updateEmployeeStatus:
        return 'EMPLOYEE_STATUS_UPDATE';
      case AppPermission.enrollEmployeeFace:
        return 'EMPLOYEE_FACE_ENROLL';
      case AppPermission.deleteEmployeeFace:
        return 'EMPLOYEE_FACE_DELETE';
      case AppPermission.createDevices:
        return 'DEVICE_CREATE';
      case AppPermission.updateDevices:
        return 'DEVICE_UPDATE';
      case AppPermission.deleteDevices:
        return 'DEVICE_DELETE';
      case AppPermission.updateDeviceStatus:
        return 'DEVICE_STATUS_UPDATE';
      case AppPermission.pingDevices:
        return 'DEVICE_PING';
      case AppPermission.viewBanners:
        return 'BANNER_VIEW';
      case AppPermission.createBanners:
        return 'BANNER_CREATE';
      case AppPermission.updateBanners:
        return 'BANNER_UPDATE';
      case AppPermission.updateBannerStatus:
        return 'BANNER_STATUS_UPDATE';
      case AppPermission.reorderBanners:
        return 'BANNER_REORDER';
      case AppPermission.deleteBanners:
        return 'BANNER_DELETE';
      case AppPermission.viewAppUpdates:
        return 'APP_UPDATE_VIEW';
      case AppPermission.uploadAppUpdates:
        return 'APP_UPDATE_UPLOAD';
      case AppPermission.releaseAppUpdates:
        return 'APP_UPDATE_RELEASE';
      case AppPermission.deleteAppUpdates:
        return 'APP_UPDATE_DELETE';
      case AppPermission.viewPermissions:
        return 'PERMISSION_VIEW';
      case AppPermission.updatePermissions:
        return 'PERMISSION_UPDATE';
      case AppPermission.resetPermissions:
        return 'PERMISSION_RESET';
      case AppPermission.createConversations:
        return 'CONVERSATION_CREATE';
      case AppPermission.updateConversations:
        return 'CONVERSATION_UPDATE';
      case AppPermission.addConversationMembers:
        return 'CONVERSATION_MEMBER_ADD';
      case AppPermission.removeConversationMembers:
        return 'CONVERSATION_MEMBER_REMOVE';
      case AppPermission.updateConversationMemberRole:
        return 'CONVERSATION_MEMBER_ROLE_UPDATE';
      case AppPermission.leaveConversations:
        return 'CONVERSATION_LEAVE';
      case AppPermission.pinConversations:
        return 'CONVERSATION_PIN';
      case AppPermission.muteConversations:
        return 'CONVERSATION_MUTE';
      case AppPermission.markConversationsRead:
        return 'CONVERSATION_READ_MARK';
      case AppPermission.sendMessages:
        return 'MESSAGE_SEND';
      case AppPermission.uploadMessages:
        return 'MESSAGE_UPLOAD';
      case AppPermission.updateMessages:
        return 'MESSAGE_UPDATE';
      case AppPermission.deleteMessages:
        return 'MESSAGE_DELETE';
      case AppPermission.reactMessages:
        return 'MESSAGE_REACT';
      case AppPermission.pinMessages:
        return 'MESSAGE_PIN';
      case AppPermission.markNotificationsRead:
        return 'NOTIFICATION_MARK_READ';

      case AppPermission.viewDevices:
        return 'DEVICE_VIEW';
      case AppPermission.manageDevices:
        return 'DEVICE_MANAGE';
      case AppPermission.manageBanners:
        return 'BANNER_MANAGE';
      case AppPermission.manageAppUpdates:
        return 'APP_UPDATE_MANAGE';
      case AppPermission.managePermissions:
        return 'PERMISSION_MANAGE';
      case AppPermission.deleteRepairOrders:
        return 'REPAIR_DELETE';
      case AppPermission.viewDashboard:
        return 'DASHBOARD_VIEW';
      case AppPermission.viewRepairOrders:
        return 'REPAIR_VIEW';
      case AppPermission.manageRepairOrders:
        return 'REPAIR_MANAGE';
      case AppPermission.updateRepairOrderStatus:
        return 'REPAIR_STATUS_UPDATE';
      case AppPermission.assignRepairOrders:
        return 'REPAIR_ASSIGN';
      case AppPermission.viewCustomers:
        return 'CUSTOMER_VIEW';
      case AppPermission.manageCustomers:
        return 'CUSTOMER_MANAGE';
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

// Generated permission expansion.
const legacyPermissionAliases = <AppPermission, List<AppPermission>>{
  AppPermission.manageRepairOrders: [AppPermission.createRepairOrders, AppPermission.updateRepairOrders, AppPermission.uploadRepairMedia, AppPermission.deleteRepairMedia],
  AppPermission.manageCustomers: [AppPermission.createCustomers, AppPermission.updateCustomers, AppPermission.updateCustomerStatus, AppPermission.assignOrderCustomer, AppPermission.transferOrderCustomer],
  AppPermission.manageWarehouse: [AppPermission.createBoards, AppPermission.updateBoards, AppPermission.checkoutBoards, AppPermission.returnBoards, AppPermission.createParts, AppPermission.updateParts, AppPermission.importParts, AppPermission.adjustPartStock, AppPermission.checkoutParts, AppPermission.returnParts, AppPermission.createLocations, AppPermission.updateLocations],
  AppPermission.deleteWarehouse: [AppPermission.deleteBoards, AppPermission.deleteParts, AppPermission.deleteLocations],
  AppPermission.manageAttendance: [AppPermission.createAttendanceRecords, AppPermission.updateAttendanceRecords, AppPermission.deleteAttendanceRecords, AppPermission.viewAttendanceReports, AppPermission.exportAttendance, AppPermission.viewSchedules, AppPermission.updateSchedules],
  AppPermission.manageEmployees: [AppPermission.viewEmployees, AppPermission.updateEmployees],
  AppPermission.manageEmployeeSecurity: [AppPermission.updateEmployeeStatus, AppPermission.enrollEmployeeFace, AppPermission.deleteEmployeeFace],
  AppPermission.manageDevices: [AppPermission.createDevices, AppPermission.updateDevices, AppPermission.deleteDevices, AppPermission.updateDeviceStatus],
  AppPermission.manageBanners: [AppPermission.viewBanners, AppPermission.createBanners, AppPermission.updateBanners, AppPermission.updateBannerStatus, AppPermission.reorderBanners, AppPermission.deleteBanners],
  AppPermission.manageAppUpdates: [AppPermission.viewAppUpdates, AppPermission.uploadAppUpdates, AppPermission.releaseAppUpdates, AppPermission.deleteAppUpdates],
  AppPermission.managePermissions: [AppPermission.viewPermissions, AppPermission.updatePermissions, AppPermission.resetPermissions],
};
const rolePermissionExpansion = <AppPermission, List<AppPermission>>{
  AppPermission.manageRepairOrders: [AppPermission.createRepairOrders, AppPermission.updateRepairOrders, AppPermission.uploadRepairMedia, AppPermission.deleteRepairMedia],
  AppPermission.updateRepairOrderStatus: [AppPermission.cancelRepairOrders],
  AppPermission.assignRepairOrders: [AppPermission.reorderRepairOrders],
  AppPermission.viewRepairOrders: [AppPermission.viewRepairTimeline],
  AppPermission.manageCustomers: [AppPermission.createCustomers, AppPermission.updateCustomers, AppPermission.updateCustomerStatus, AppPermission.assignOrderCustomer, AppPermission.transferOrderCustomer],
  AppPermission.viewCustomers: [AppPermission.viewCustomerOrders],
  AppPermission.manageWarehouse: [AppPermission.createBoards, AppPermission.updateBoards, AppPermission.checkoutBoards, AppPermission.returnBoards, AppPermission.createParts, AppPermission.updateParts, AppPermission.importParts, AppPermission.adjustPartStock, AppPermission.checkoutParts, AppPermission.returnParts, AppPermission.createLocations, AppPermission.updateLocations],
  AppPermission.deleteWarehouse: [AppPermission.deleteBoards, AppPermission.deleteParts, AppPermission.deleteLocations],
  AppPermission.viewWarehouse: [AppPermission.viewBoardHistory, AppPermission.viewPartHistory, AppPermission.printWarehouseQr],
  AppPermission.viewAttendance: [AppPermission.checkOwnAttendance, AppPermission.saveFieldWork, AppPermission.deleteFieldWork],
  AppPermission.manageAttendance: [AppPermission.createAttendanceRecords, AppPermission.updateAttendanceRecords, AppPermission.deleteAttendanceRecords, AppPermission.viewAttendanceReports, AppPermission.exportAttendance, AppPermission.viewSchedules, AppPermission.updateSchedules],
  AppPermission.manageEmployees: [AppPermission.viewEmployees, AppPermission.updateEmployees],
  AppPermission.manageEmployeeSecurity: [AppPermission.updateEmployeeStatus, AppPermission.enrollEmployeeFace, AppPermission.deleteEmployeeFace],
  AppPermission.manageDevices: [AppPermission.createDevices, AppPermission.updateDevices, AppPermission.deleteDevices, AppPermission.updateDeviceStatus],
  AppPermission.viewDevices: [AppPermission.pingDevices],
  AppPermission.manageBanners: [AppPermission.viewBanners, AppPermission.createBanners, AppPermission.updateBanners, AppPermission.updateBannerStatus, AppPermission.reorderBanners, AppPermission.deleteBanners],
  AppPermission.manageAppUpdates: [AppPermission.viewAppUpdates, AppPermission.uploadAppUpdates, AppPermission.releaseAppUpdates, AppPermission.deleteAppUpdates],
  AppPermission.managePermissions: [AppPermission.viewPermissions, AppPermission.updatePermissions, AppPermission.resetPermissions],
  AppPermission.useMessages: [AppPermission.createConversations, AppPermission.updateConversations, AppPermission.addConversationMembers, AppPermission.removeConversationMembers, AppPermission.updateConversationMemberRole, AppPermission.leaveConversations, AppPermission.pinConversations, AppPermission.muteConversations, AppPermission.markConversationsRead, AppPermission.sendMessages, AppPermission.uploadMessages, AppPermission.updateMessages, AppPermission.deleteMessages, AppPermission.reactMessages, AppPermission.pinMessages],
  AppPermission.viewNotifications: [AppPermission.markNotificationsRead],
};

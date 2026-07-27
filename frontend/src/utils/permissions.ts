import type { UserInfo } from '../mockData';

// ── Role Labels (tiếng Việt) ──────────────────────────────────────────────

export const ROLE_LABELS: Record<string, string> = {
  SUPER_ADMIN: 'Super Admin',
  ADMIN: 'Quản trị viên',
  MANAGER: 'Quản lý',
  TECHNICIAN: 'Kỹ thuật viên',
  WAREHOUSE: 'Kho',
  EMPLOYEE: 'Nhân viên',
  ATTENDANCE: 'Thiết bị chấm công',
};

export const ROLE_COLORS: Record<string, string> = {
  SUPER_ADMIN: '#ef4444',
  ADMIN: '#f97316',
  MANAGER: '#8b5cf6',
  TECHNICIAN: '#3b82f6',
  WAREHOUSE: '#10b981',
  EMPLOYEE: '#6b7280',
  ATTENDANCE: '#0ea5e9',
};

// ── Permission Labels ─────────────────────────────────────────────────────

export const PERMISSION_LABELS: Record<string, string> = {
  DASHBOARD_VIEW: 'Xem dashboard',
  REPAIR_VIEW: 'Xem đơn sửa chữa',
  REPAIR_MANAGE: 'Quản lý đơn sửa chữa',
  REPAIR_STATUS_UPDATE: 'Cập nhật trạng thái đơn',
  REPAIR_ASSIGN: 'Phân công kỹ thuật viên',
  WAREHOUSE_VIEW: 'Xem kho bo mạch',
  WAREHOUSE_MANAGE: 'Quản lý kho bo mạch',
  WAREHOUSE_DELETE: 'Xóa vật tư kho',
  MESSAGING_USE: 'Nhắn tin nội bộ',
  NOTIFICATION_VIEW: 'Xem thông báo',
  ATTENDANCE_VIEW: 'Xem chấm công',
  ATTENDANCE_MANAGE: 'Quản lý chấm công',
  EMPLOYEE_MANAGE: 'Quản lý nhân viên',
  ACCOUNT_APPROVE: 'Duyệt tài khoản',
  EMPLOYEE_SECURITY_MANAGE: 'Quản lý bảo mật nhân viên',
  PROFILE_VIEW: 'Xem hồ sơ',
  PROFILE_UPDATE_SELF: 'Cập nhật hồ sơ cá nhân',
};

// ── Ma trận permissions mặc định theo role ────────────────────────────────

export const ROLE_DEFAULT_PERMISSIONS: Record<string, string[]> = {
  SUPER_ADMIN: Object.keys(PERMISSION_LABELS),
  ADMIN: [
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE', 'WAREHOUSE_DELETE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW', 'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE', 'ACCOUNT_APPROVE', 'EMPLOYEE_SECURITY_MANAGE',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  MANAGER: [
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW', 'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE', 'ACCOUNT_APPROVE',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  TECHNICIAN: [
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  WAREHOUSE: [
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  EMPLOYEE: [
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  ATTENDANCE: ['ATTENDANCE_VIEW'],
};

// ── Helper Functions ──────────────────────────────────────────────────────

/** Kiểm tra user có permission cụ thể không */
export function hasPermission(user: UserInfo | null, permission: string): boolean {
  if (!user) return false;
  if (user.permissions && user.permissions.length > 0) {
    return user.permissions.includes(permission);
  }
  // Fallback: dùng ma trận mặc định nếu API chưa trả về permissions
  const role = user.role?.toUpperCase() ?? '';
  return (ROLE_DEFAULT_PERMISSIONS[role] ?? []).includes(permission);
}

/** Kiểm tra user có role cụ thể không */
export function hasRole(user: UserInfo | null, role: string): boolean {
  if (!user?.role) return false;
  return user.role.toUpperCase() === role.toUpperCase();
}

/** SUPER_ADMIN hoặc ADMIN */
export function isAdminOrAbove(user: UserInfo | null): boolean {
  if (!user?.role) return false;
  const role = user.role.toUpperCase();
  return role === 'SUPER_ADMIN' || role === 'ADMIN';
}

/** SUPER_ADMIN, ADMIN hoặc MANAGER */
export function isManagerOrAbove(user: UserInfo | null): boolean {
  if (!user?.role) return false;
  const role = user.role.toUpperCase();
  return role === 'SUPER_ADMIN' || role === 'ADMIN' || role === 'MANAGER';
}

/** Có thể quản lý tài khoản (xem user list) */
export function canManageAccounts(user: UserInfo | null): boolean {
  return isAdminOrAbove(user);
}

/** Có thể đổi role của người khác (chỉ SUPER_ADMIN) */
export function canChangeRoles(user: UserInfo | null): boolean {
  return hasRole(user, 'SUPER_ADMIN');
}

/** Tên hiển thị của role */
export function getRoleLabel(role?: string): string {
  if (!role) return 'Không xác định';
  return ROLE_LABELS[role.toUpperCase()] ?? role;
}

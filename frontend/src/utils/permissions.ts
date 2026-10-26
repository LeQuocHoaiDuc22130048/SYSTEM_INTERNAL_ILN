import type { UserInfo } from '../mockData';
import { ACTION_PERMISSION_LABELS, LEGACY_PERMISSION_ALIASES, ROLE_PERMISSION_EXPANSION } from './actionPermissions';

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
  ...ACTION_PERMISSION_LABELS,
  DEVICE_VIEW: 'Xem thiết bị',
  REPAIR_DELETE: 'Xóa đơn sửa chữa',
  DASHBOARD_VIEW: 'Xem dashboard',
  REPAIR_VIEW: 'Xem đơn sửa chữa',
  REPAIR_STATUS_UPDATE: 'Cập nhật trạng thái đơn',
  REPAIR_ASSIGN: 'Phân công kỹ thuật viên',
  CUSTOMER_VIEW: 'Xem khách hàng',
  WAREHOUSE_VIEW: 'Xem kho bo mạch',
  MESSAGING_USE: 'Nhắn tin nội bộ',
  NOTIFICATION_VIEW: 'Xem thông báo',
  ATTENDANCE_VIEW: 'Xem chấm công',
  ACCOUNT_APPROVE: 'Duyệt tài khoản',
  PROFILE_VIEW: 'Xem hồ sơ',
  PROFILE_UPDATE_SELF: 'Cập nhật hồ sơ cá nhân',
  SYSTEM_TERMINAL: 'Terminal quản trị hệ thống',
};

// ── Ma trận permissions mặc định theo role ────────────────────────────────

export const ROLE_DEFAULT_PERMISSIONS: Record<string, string[]> = {
  SUPER_ADMIN: Object.keys(PERMISSION_LABELS),
  ADMIN: [
    'DEVICE_VIEW', 'DEVICE_MANAGE', 'BANNER_MANAGE', 'APP_UPDATE_MANAGE', 'PERMISSION_MANAGE', 'REPAIR_DELETE',
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'CUSTOMER_VIEW', 'CUSTOMER_MANAGE',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE', 'WAREHOUSE_DELETE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW', 'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE', 'ACCOUNT_APPROVE', 'EMPLOYEE_SECURITY_MANAGE',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
    'SYSTEM_TERMINAL',
  ],
  MANAGER: [
    'DEVICE_VIEW', 'DEVICE_MANAGE', 'BANNER_MANAGE', 'REPAIR_DELETE',
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'CUSTOMER_VIEW', 'CUSTOMER_MANAGE',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW', 'ATTENDANCE_MANAGE',
    'EMPLOYEE_MANAGE', 'ACCOUNT_APPROVE',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  TECHNICIAN: [
    'DEVICE_VIEW',
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE', 'REPAIR_ASSIGN',
    'CUSTOMER_VIEW',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  WAREHOUSE: [
    'DEVICE_VIEW',
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE',
    'CUSTOMER_VIEW',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  EMPLOYEE: [
    'DEVICE_VIEW',
    'DASHBOARD_VIEW', 'REPAIR_VIEW', 'REPAIR_MANAGE', 'REPAIR_STATUS_UPDATE',
    'CUSTOMER_VIEW', 'CUSTOMER_MANAGE',
    'WAREHOUSE_VIEW', 'WAREHOUSE_MANAGE',
    'MESSAGING_USE', 'NOTIFICATION_VIEW',
    'ATTENDANCE_VIEW',
    'PROFILE_VIEW', 'PROFILE_UPDATE_SELF',
  ],
  ATTENDANCE: ['ATTENDANCE_VIEW'],
};

for (const [role, codes] of Object.entries(ROLE_DEFAULT_PERMISSIONS)) {
  const expanded = new Set(codes);
  for (const [parent, children] of Object.entries(ROLE_PERMISSION_EXPANSION)) {
    if (expanded.has(parent)) children.forEach(code => expanded.add(code));
  }
  if (['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN', 'ATTENDANCE'].includes(role)) expanded.add('ATTENDANCE_KIOSK_USE');
  ROLE_DEFAULT_PERMISSIONS[role] = [...expanded].filter(code => code in PERMISSION_LABELS);
}

// ── Helper Functions ──────────────────────────────────────────────────────

/** Kiểm tra user có permission cụ thể không */
export function hasPermission(user: UserInfo | null, permission: string): boolean {
  if (!user) return false;
  if (user.role?.toUpperCase() === 'SUPER_ADMIN') return true;
  const children = LEGACY_PERMISSION_ALIASES[permission];
  if (children) return children.some(code => hasPermission(user, code));
  if (Array.isArray(user.permissions)) {
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

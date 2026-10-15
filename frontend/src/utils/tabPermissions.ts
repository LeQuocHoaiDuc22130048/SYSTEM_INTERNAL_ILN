import type { UserInfo } from '../mockData';
import { hasPermission } from './permissions';

export function canAccessTab(user: UserInfo | null, tab: string): boolean {
  const permissions: Record<string, string[]> = {
    dashboard: ['DASHBOARD_VIEW'], monthly: ['ATTENDANCE_REPORT_VIEW'], daily: ['ATTENDANCE_REPORT_VIEW'],
    orders: ['REPAIR_VIEW'], customers: ['CUSTOMER_VIEW'], warehouse: ['WAREHOUSE_VIEW'], locations: ['WAREHOUSE_VIEW'],
    devices: ['DEVICE_VIEW'], banners: ['BANNER_VIEW'], updates: ['APP_UPDATE_VIEW'],
    accounts: ['PERMISSION_VIEW', 'EMPLOYEE_STATUS_UPDATE'],
  };
  return (permissions[tab] ?? []).some(permission => hasPermission(user, permission));
}

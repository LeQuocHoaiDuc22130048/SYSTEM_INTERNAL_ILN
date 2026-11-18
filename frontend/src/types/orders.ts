import type { UserInfo } from '../mockData';

export interface RepairMedia {
  id: string;
  imageUrl: string;
  mediaType: 'IMAGE' | 'VIDEO' | 'DOCUMENT' | string;
  caption?: string;
}

export interface RepairDevice {
  id?: string;
  deviceName: string;
  deviceType?: string;
  serialNumber?: string;
  underWarranty: boolean;
  warrantyExpiry?: string;
  description?: string;
  status?: string;
  assignedTo?: {
    id: string;
    fullName: string;
  };
}

export interface RepairOrder {
  id: string;
  orderCode: string;
  deviceName: string;
  customerId?: string | null;
  customerName: string;
  customerPhone?: string;
  serialNumber?: string;
  status: string;
  confirmationStatus?: string | null;
  createdAt: string;
  updatedAt?: string;
  description?: string;
  notes?: string;
  images: RepairMedia[];
  devices: RepairDevice[];
  assignees: { id: string; fullName: string }[];
}

export interface Employee {
  id: string;
  username: string;
  fullName: string;
  role: string;
  employeeCode?: string;
}

export interface TimelineEvent {
  id: string;
  status?: string;
  action?: string;
  note?: string;
  changedByName?: string;
  changedAt?: string;
  createdAt?: string;
  performedBy?: {
    id: string;
    fullName: string;
    employeeCode?: string;
    avatarUrl?: string;
  };
}


export interface OrdersTabProps {
  showToast: (msg: string) => void;
  currentUser?: UserInfo | null;
}

/** Trả về true nếu đơn sửa chữa chưa được khách hàng xác nhận và chưa kết thúc/hủy. */
export function isOrderAwaitingCustomerConfirmation(order: {
  status?: string | null;
  confirmationStatus?: string | null;
}): boolean {
  const status = (order.status || '').trim().toUpperCase();
  if (status === 'DELIVERED' || status === 'CANCELLED') {
    return false;
  }
  const confirmationStatus = (order.confirmationStatus || 'PENDING_CUSTOMER')
    .trim()
    .toUpperCase();
  return confirmationStatus === '' || confirmationStatus === 'PENDING_CUSTOMER';
}

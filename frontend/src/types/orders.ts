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
  customerName: string;
  customerPhone?: string;
  status: string;
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
  status: string;
  note?: string;
  changedByName: string;
  changedAt: string;
}

export interface OrdersTabProps {
  showToast: (msg: string) => void;
  currentUser?: UserInfo | null;
}

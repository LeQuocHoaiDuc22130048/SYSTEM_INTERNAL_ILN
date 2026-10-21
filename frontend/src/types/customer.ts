export type CustomerType = 'INDIVIDUAL' | 'COMPANY';

export interface Customer {
  id: string;
  customerCode: string;
  customerName: string;
  type: CustomerType;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  taxCode?: string | null;
  notes?: string | null;
  active: boolean;
  createdAt?: string | null;
  updatedAt?: string | null;
}

export interface CustomerRequest {
  customerName: string;
  type: CustomerType;
  phone?: string | null;
  email?: string | null;
  address?: string | null;
  taxCode?: string | null;
  notes?: string | null;
}

export interface CustomerPageResponse {
  content: Customer[];
  number: number;
  size: number;
  totalElements: number;
  totalPages: number;
  last: boolean;
}

export interface CustomerFilterParams {
  keyword?: string;
  active?: boolean | null;
  type?: CustomerType | '';
  page?: number;
  size?: number;
}

export interface CustomerAccount {
  id: string;
  userId: string;
  customerId: string;
  username: string;
  contactName: string;
  phone?: string | null;
  email?: string | null;
  active: boolean;
  mustChangePassword: boolean;
  createdAt?: string | null;
}

export interface CreateCustomerAccountRequest {
  username: string;
  password: string;
  contactName: string;
  phone?: string | null;
  email?: string | null;
  mustChangePassword?: boolean;
}

export interface CustomerAccountCreatedResponse {
  account: CustomerAccount;
  plainPassword: string;
  shareableMessage: string;
}

export interface ResetCustomerPasswordRequest {
  newPassword: string;
}

export interface CustomerDeviceResponse {
  id: string;
  deviceName: string;
  model?: string | null;
  serialNumber?: string | null;
  status: string;
  symptom?: string | null;
}

export interface CustomerUpdateResponse {
  id: string;
  title: string;
  content: string;
  message?: string;
  statusAtTime?: string | null;
  statusAtUpdate?: string | null;
  publishedAt: string;
}

export interface CustomerMediaResponse {
  id: string;
  mediaId?: string;
  fileUrl: string;
  mediaUrl?: string;
  caption?: string | null;
  mediaType?: string | null;
  publishedAt: string;
}

export interface CustomerOrderResponse {
  id: string;
  orderCode: string;
  orderTitle: string;
  status: string;
  friendlyStatus: string;
  devicesCount: number;
  receivedDate: string;
  expectedDeliveryDate?: string | null;
  updatedAt: string;
}

export interface CustomerOrderDetailResponse {
  id: string;
  orderCode: string;
  orderTitle: string;
  status: string;
  friendlyStatus: string;
  receivedDate: string;
  expectedDeliveryDate?: string | null;
  updatedAt: string;
  devices: CustomerDeviceResponse[];
  updates: CustomerUpdateResponse[];
  media: CustomerMediaResponse[];
}

export interface PortalTrackRequest {
  orderCode: string;
  phone: string;
}

export interface PublishCustomerUpdateRequest {
  deviceId?: string | null;
  title: string;
  content?: string;
  message?: string;
}

export interface PublishCustomerMediaRequest {
  mediaId: string;
  caption?: string | null;
}

export interface CustomerChangePasswordRequest {
  currentPassword: string;
  newPassword: string;
  confirmPassword: string;
}

export interface CustomerAccountProfileResponse {
  userId: string;
  username: string;
  contactName: string;
  phone?: string | null;
  email?: string | null;
  avatarUrl?: string | null;
  customerId: string;
  customerCode: string;
  customerName: string;
  companyAddress?: string | null;
  companyTaxCode?: string | null;
}

export interface UpdateCustomerAccountProfileRequest {
  contactName: string;
  phone?: string;
  email?: string;
}



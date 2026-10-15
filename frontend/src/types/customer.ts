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

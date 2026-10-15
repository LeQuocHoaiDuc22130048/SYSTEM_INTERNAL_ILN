import { getAuthHeaders, getJsonAuthHeaders } from './auth';
import type { RepairOrder } from '../types/orders';
import type { Customer, CustomerPageResponse, CustomerRequest, CustomerFilterParams } from '../types/customer';

export interface ApiResult<T> {
  success: boolean;
  data?: T;
  message?: string;
  errors?: { field: string; message: string }[];
  statusCode?: number;
}

export async function getCustomerOrderCandidates(keyword: string, page = 0, unlinkedOnly = true): Promise<ApiResult<{ content: RepairOrder[]; totalPages: number }>> {
  const query = new URLSearchParams({ keyword: keyword.trim(), page: String(page), size: '20', unlinkedOnly: String(unlinkedOnly) });
  try {
    const res = await fetch(`/api/v1/repair-orders?${query}`, { headers: getAuthHeaders() });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) return { success: true, data: json.data };
    return { success: false, message: json?.message || 'Không thể tải danh sách đơn hàng' };
  } catch {
    return { success: false, message: 'Không thể kết nối máy chủ' };
  }
}

/**
 * Lấy danh sách khách hàng có phân trang, tìm kiếm, lọc active / type
 */
export async function getCustomers(params: CustomerFilterParams = {}): Promise<ApiResult<CustomerPageResponse>> {
  const query = new URLSearchParams();
  if (params.keyword && params.keyword.trim()) {
    query.append('keyword', params.keyword.trim());
  }
  if (params.active !== undefined && params.active !== null) {
    query.append('active', String(params.active));
  }
  if (params.type) {
    query.append('type', params.type);
  }
  query.append('page', String(params.page ?? 0));
  query.append('size', String(Math.min(params.size ?? 20, 50)));

  try {
    const res = await fetch(`/api/v1/customers?${query.toString()}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || `Lỗi tải danh sách khách hàng (${res.status})`,
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Đọc chi tiết khách hàng theo id (gồm cả inactive)
 */
export async function getCustomerById(id: string): Promise<ApiResult<Customer>> {
  try {
    const res = await fetch(`/api/v1/customers/${id}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || `Lỗi tải thông tin khách hàng (${res.status})`,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Tạo mới hồ sơ khách hàng
 */
export async function createCustomer(req: CustomerRequest): Promise<ApiResult<Customer>> {
  const body = {
    customerName: req.customerName.trim(),
    type: req.type,
    phone: req.phone?.trim() || null,
    email: req.email?.trim() || null,
    address: req.address?.trim() || null,
    taxCode: req.taxCode?.trim() || null,
    notes: req.notes?.trim() || null,
  };

  try {
    const res = await fetch('/api/v1/customers', {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Tạo khách hàng thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || `Không thể tạo khách hàng (${res.status})`,
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Cập nhật thông tin khách hàng (PUT toàn bộ)
 */
export async function updateCustomer(id: string, req: CustomerRequest): Promise<ApiResult<Customer>> {
  const body = {
    customerName: req.customerName.trim(),
    type: req.type,
    phone: req.phone?.trim() || null,
    email: req.email?.trim() || null,
    address: req.address?.trim() || null,
    taxCode: req.taxCode?.trim() || null,
    notes: req.notes?.trim() || null,
  };

  try {
    const res = await fetch(`/api/v1/customers/${id}`, {
      method: 'PUT',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(body),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Cập nhật thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || `Không thể cập nhật khách hàng (${res.status})`,
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Bật/tắt trạng thái hoạt động của khách hàng
 */
export async function updateCustomerStatus(id: string, active: boolean): Promise<ApiResult<Customer>> {
  try {
    const res = await fetch(`/api/v1/customers/${id}/status`, {
      method: 'PATCH',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify({ active }),
    });
    const json = await res.json().catch(() => null);
    if (res.ok) {
      return {
        success: true,
        data: json?.data,
        message: active ? 'Đã kích hoạt lại khách hàng' : 'Đã ngừng hoạt động khách hàng',
        statusCode: res.status,
      };
    }
    return {
      success: false,
      message: json?.message || `Lỗi cập nhật trạng thái (${res.status})`,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Gán hoặc chuyển hồ sơ khách hàng cho đơn sửa chữa
 */
export async function linkRepairOrderCustomer(
  orderId: string,
  customerId: string,
  reason: string
): Promise<ApiResult<any>> {
  try {
    const res = await fetch(`/api/v1/repair-orders/${orderId}/customer`, {
      method: 'PUT',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify({
        customerId,
        reason: reason.trim(),
      }),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Gán hồ sơ thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || `Lỗi khi liên kết khách hàng (${res.status})`,
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy danh sách đơn sửa chữa của khách hàng theo customerId
 */
export async function getCustomerRepairOrders(
  customerId: string,
  page = 0,
  size = 20
): Promise<ApiResult<{ content: any[]; totalElements: number; totalPages: number; number: number; last: boolean }>> {
  try {
    const res = await fetch(`/api/v1/repair-orders?customerId=${customerId}&page=${page}&size=${size}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải đơn hàng của khách',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

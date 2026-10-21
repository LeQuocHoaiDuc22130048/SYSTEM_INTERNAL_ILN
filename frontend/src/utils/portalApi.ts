import { getAuthHeaders, getJsonAuthHeaders } from './auth';
import type { ApiResult } from './customerApi';
import type {
  Customer,
  CustomerOrderResponse,
  CustomerOrderDetailResponse,
  CustomerUpdateResponse,
  CustomerMediaResponse,
  PortalTrackRequest,
  PublishCustomerUpdateRequest,
  PublishCustomerMediaRequest,
  CustomerChangePasswordRequest,
  CustomerAccountProfileResponse,
  UpdateCustomerAccountProfileRequest,
} from '../types/customer';

/**
 * Tra cứu công khai đơn sửa chữa bằng mã đơn và 4 số cuối SĐT
 */
export async function trackPortalOrder(
  req: PortalTrackRequest
): Promise<ApiResult<CustomerOrderDetailResponse>> {
  try {
    const res = await fetch('/api/v1/portal/track', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(req),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không tìm thấy thông tin đơn hàng',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy hồ sơ khách hàng của tài khoản đang đăng nhập
 */
export async function getMyCustomerProfile(): Promise<ApiResult<Customer>> {
  try {
    const res = await fetch('/api/v1/customer/me', {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể lấy thông tin khách hàng',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy danh sách đơn hàng của khách hàng đang đăng nhập
 */
export async function getMyCustomerOrders(params?: {
  page?: number;
  size?: number;
  keyword?: string;
}): Promise<
  ApiResult<{
    content: CustomerOrderResponse[];
    totalElements: number;
    totalPages: number;
    number: number;
    last: boolean;
  }>
> {
  const query = new URLSearchParams();
  if (params?.page !== undefined) query.append('page', String(params.page));
  if (params?.size !== undefined) query.append('size', String(params.size));
  if (params?.keyword && params.keyword.trim()) query.append('keyword', params.keyword.trim());

  try {
    const res = await fetch(`/api/v1/customer/orders?${query.toString()}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể lấy danh sách đơn hàng',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy chi tiết đơn hàng của khách hàng đang đăng nhập
 */
export async function getMyCustomerOrderDetail(
  orderId: string
): Promise<ApiResult<CustomerOrderDetailResponse>> {
  try {
    const res = await fetch(`/api/v1/customer/orders/${orderId}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể lấy chi tiết đơn hàng',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Kỹ thuật viên / Quản lý đăng thông báo tiến độ cho khách xem
 */
export async function publishCustomerUpdate(
  orderId: string,
  req: PublishCustomerUpdateRequest
): Promise<ApiResult<CustomerUpdateResponse>> {
  try {
    const payload = {
      deviceId: req.deviceId || null,
      title: req.title,
      message: req.message || req.content || '',
      content: req.content || req.message || '',
    };
    const res = await fetch(`/api/v1/repair-orders/${orderId}/customer-updates`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(payload),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Đã gửi cập nhật cho khách', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể gửi cập nhật',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy danh sách tiến độ đã xuất bản cho khách
 */
export async function getPublishedCustomerUpdates(
  orderId: string
): Promise<ApiResult<CustomerUpdateResponse[]>> {
  try {
    const res = await fetch(`/api/v1/repair-orders/${orderId}/customer-updates`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải tiến độ đã gửi',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Kỹ thuật viên / Quản lý đăng hình ảnh/video công khai cho khách
 */
export async function publishCustomerMedia(
  orderId: string,
  req: PublishCustomerMediaRequest
): Promise<ApiResult<CustomerMediaResponse>> {
  try {
    const payload = {
      mediaId: req.mediaId,
      caption: req.caption || null,
    };
    const res = await fetch(`/api/v1/repair-orders/${orderId}/customer-media`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(payload),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Đã chia sẻ hình ảnh cho khách', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể chia sẻ hình ảnh',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Khách hàng tự đổi mật khẩu tài khoản
 */
export async function changeCustomerPassword(
  req: CustomerChangePasswordRequest
): Promise<ApiResult<void>> {
  try {
    const res = await fetch('/api/v1/customer/change-password', {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(req),
    });
    const json = await res.json().catch(() => null);
    if (res.ok) {
      return { success: true, message: json?.message || 'Đổi mật khẩu thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể đổi mật khẩu',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy danh sách media đã xuất bản cho khách
 */
export async function getPublishedCustomerMedia(
  orderId: string
): Promise<ApiResult<CustomerMediaResponse[]>> {
  try {
    const res = await fetch(`/api/v1/repair-orders/${orderId}/customer-media`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải hình ảnh đã chia sẻ',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Lấy thông tin tài khoản và avatar của khách hàng
 */
export async function getCustomerAccountProfile(): Promise<ApiResult<CustomerAccountProfileResponse>> {
  try {
    const res = await fetch('/api/v1/customer/account-profile', {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể lấy thông tin tài khoản',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Cập nhật thông tin cá nhân của tài khoản khách hàng
 */
export async function updateCustomerAccountProfile(
  req: UpdateCustomerAccountProfileRequest
): Promise<ApiResult<CustomerAccountProfileResponse>> {
  try {
    const res = await fetch('/api/v1/customer/account-profile', {
      method: 'PUT',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(req),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Cập nhật thông tin thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể cập nhật thông tin',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

/**
 * Tải lên ảnh đại diện (avatar) của khách hàng
 */
export async function uploadCustomerAvatar(
  file: File
): Promise<ApiResult<CustomerAccountProfileResponse>> {
  try {
    const formData = new FormData();
    formData.append('file', file);

    const headers = getAuthHeaders();

    const res = await fetch('/api/v1/customer/avatar', {
      method: 'POST',
      headers,
      body: formData,
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, message: 'Cập nhật ảnh đại diện thành công', statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải lên ảnh đại diện',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}


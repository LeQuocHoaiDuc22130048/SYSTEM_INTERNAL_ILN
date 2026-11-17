import { getAuthHeaders, getJsonAuthHeaders } from './auth';
import type { ApiResult } from './customerApi';
import type {
  CreateQuotationRequest,
  PaymentProofResponse,
  PendingQuotationOrderResponse,
  QuotationResponse,
  QuotationStatus,
  RespondQuotationRequest,
} from '../types/quotation';

export async function getPendingQuotationOrders(
  customerId: string
): Promise<ApiResult<PendingQuotationOrderResponse[]>> {
  try {
    const res = await fetch(
      `/api/v1/repair-quotations/pending-orders?customerId=${encodeURIComponent(customerId)}`,
      { headers: getAuthHeaders() }
    );
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải danh sách đơn chờ báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function getQuotationsByOrder(
  orderId: string
): Promise<ApiResult<QuotationResponse[]>> {
  try {
    const res = await fetch(
      `/api/v1/repair-quotations/by-order/${encodeURIComponent(orderId)}`,
      { headers: getAuthHeaders() }
    );
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải báo giá của đơn',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function searchRepairQuotations(params?: {
  customerId?: string;
  status?: QuotationStatus;
  repairOrderId?: string;
  page?: number;
  size?: number;
}): Promise<
  ApiResult<{
    content: QuotationResponse[];
    totalElements: number;
    totalPages: number;
  }>
> {
  try {
    const query = new URLSearchParams();
    if (params?.customerId) query.append('customerId', params.customerId);
    if (params?.status) query.append('status', params.status);
    if (params?.repairOrderId) query.append('repairOrderId', params.repairOrderId);
    query.append('page', String(params?.page ?? 0));
    query.append('size', String(params?.size ?? 100));

    const res = await fetch(`/api/v1/repair-quotations?${query.toString()}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải danh sách báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function getRepairQuotationById(
  quotationId: string
): Promise<ApiResult<QuotationResponse>> {
  try {
    const res = await fetch(`/api/v1/repair-quotations/${encodeURIComponent(quotationId)}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải chi tiết báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function createRepairQuotation(
  req: CreateQuotationRequest
): Promise<ApiResult<QuotationResponse>> {
  try {
    const res = await fetch('/api/v1/repair-quotations', {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(req),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tạo báo giá',
      errors: json?.errors,
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function sendRepairQuotation(
  quotationId: string
): Promise<ApiResult<QuotationResponse>> {
  try {
    const res = await fetch(`/api/v1/repair-quotations/${quotationId}/send`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể gửi báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function cancelRepairQuotation(
  quotationId: string
): Promise<ApiResult<QuotationResponse>> {
  try {
    const res = await fetch(`/api/v1/repair-quotations/${quotationId}/cancel`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể hủy báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function verifyQuotationPaymentProof(
  proofId: string,
  approved: boolean,
  rejectionReason?: string
): Promise<ApiResult<PaymentProofResponse>> {
  try {
    const res = await fetch(`/api/v1/repair-quotations/payment-proofs/${proofId}/verify`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify({ approved, rejectionReason }),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể đối soát chứng từ',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

// ── Customer Portal Quotation APIs ────────────────────────────────────────

export async function getMyCustomerQuotations(params?: {
  status?: QuotationStatus;
  page?: number;
  size?: number;
}): Promise<
  ApiResult<{
    content: QuotationResponse[];
    totalElements: number;
    totalPages: number;
  }>
> {
  try {
    const query = new URLSearchParams();
    if (params?.status) query.append('status', params.status);
    query.append('page', String(params?.page ?? 0));
    query.append('size', String(params?.size ?? 50));

    const res = await fetch(`/api/v1/customer/quotations?${query.toString()}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải danh sách báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function respondToCustomerQuotation(
  quotationId: string,
  req: RespondQuotationRequest
): Promise<ApiResult<QuotationResponse>> {
  try {
    const res = await fetch(`/api/v1/customer/quotations/${quotationId}/respond`, {
      method: 'POST',
      headers: getJsonAuthHeaders(),
      body: JSON.stringify(req),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể gửi xác nhận báo giá',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}

export async function submitCustomerPaymentProof(
  quotationId: string,
  file: File,
  amount?: number,
  note?: string
): Promise<ApiResult<PaymentProofResponse>> {
  try {
    const formData = new FormData();
    formData.append('file', file);
    if (amount !== undefined && amount > 0) {
      formData.append('amount', String(amount));
    }
    if (note && note.trim()) {
      formData.append('note', note.trim());
    }

    const headers = { ...getAuthHeaders() } as Record<string, string>;
    delete headers['Content-Type'];

    const res = await fetch(`/api/v1/customer/quotations/${quotationId}/payment-proofs`, {
      method: 'POST',
      headers,
      body: formData,
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data) {
      return { success: true, data: json.data, statusCode: res.status };
    }
    return {
      success: false,
      message: json?.message || 'Không thể tải lên chứng từ thanh toán',
      statusCode: res.status,
    };
  } catch (err: any) {
    return { success: false, message: err.message || 'Lỗi kết nối máy chủ' };
  }
}


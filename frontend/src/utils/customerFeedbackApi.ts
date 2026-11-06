import { getAuthHeaders, getJsonAuthHeaders } from './auth';
import type { CustomerFeedback, ReplyFeedbackPayload, FeedbackStatus } from '../types/customerFeedback';

export interface FeedbackFilterParams {
  keyword?: string;
  status?: string;
  type?: string;
  isUrgent?: boolean;
  customerId?: string;
  page?: number;
  size?: number;
}

/**
 * Lấy danh sách phản hồi từ Backend Database (không dùng dữ liệu mẫu)
 */
export async function getCustomerFeedbacks(params: FeedbackFilterParams = {}): Promise<CustomerFeedback[]> {
  const query = new URLSearchParams();
  if (params.keyword?.trim()) query.append('keyword', params.keyword.trim());
  if (params.status && params.status !== 'ALL') query.append('status', params.status);
  if (params.type && params.type !== 'ALL') query.append('type', params.type);
  if (params.isUrgent !== undefined) query.append('isUrgent', String(params.isUrgent));
  if (params.customerId) query.append('customerId', params.customerId);
  query.append('page', String(params.page ?? 0));
  query.append('size', String(params.size ?? 50));

  try {
    const res = await fetch(`/api/v1/customers/feedbacks?${query.toString()}`, {
      headers: getAuthHeaders(),
    });
    const json = await res.json().catch(() => null);
    if (res.ok && json?.data?.content) {
      return (json.data.content as any[]).map(mapBackendFeedback);
    }
    return [];
  } catch (e) {
    console.warn('Không thể kết nối máy chủ để lấy phản hồi:', e);
    return [];
  }
}

/**
 * Admin / Kỹ sư trả lời phản hồi và cập nhật tiến độ vào CSDL
 */
export async function updateFeedbackReply(payload: ReplyFeedbackPayload): Promise<CustomerFeedback> {
  const res = await fetch(`/api/v1/customers/feedbacks/${payload.feedbackId}/reply`, {
    method: 'PUT',
    headers: getJsonAuthHeaders(),
    body: JSON.stringify({
      status: payload.status,
      reply: payload.reply,
      repliedBy: payload.repliedBy,
    }),
  });
  const json = await res.json().catch(() => null);
  if (res.ok && json?.data) {
    return mapBackendFeedback(json.data);
  }
  throw new Error(json?.message || 'Không thể lưu phản hồi vào máy chủ');
}

/**
 * Cập nhật trạng thái xử lý phản hồi trực tiếp vào CSDL
 */
export async function updateFeedbackStatusOnly(feedbackId: string, status: FeedbackStatus): Promise<CustomerFeedback> {
  const res = await fetch(`/api/v1/customers/feedbacks/${feedbackId}/status`, {
    method: 'PATCH',
    headers: getJsonAuthHeaders(),
    body: JSON.stringify({ status }),
  });
  const json = await res.json().catch(() => null);
  if (res.ok && json?.data) {
    return mapBackendFeedback(json.data);
  }
  throw new Error(json?.message || 'Không thể cập nhật trạng thái vào máy chủ');
}

function mapBackendFeedback(raw: any): CustomerFeedback {
  let createdStr = raw.createdAt || '';
  if (createdStr && createdStr.includes('T')) {
    const d = new Date(createdStr);
    if (!isNaN(d.getTime())) {
      createdStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }
  }

  let replyStr = raw.replyAt || '';
  if (replyStr && replyStr.includes('T')) {
    const d = new Date(replyStr);
    if (!isNaN(d.getTime())) {
      replyStr = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }
  }

  return {
    id: raw.id || '',
    orderCode: raw.orderCode || 'Ý kiến chung',
    customerName: raw.customerName || 'Khách hàng',
    customerPhone: raw.customerPhone || undefined,
    customerCode: raw.customerCode || undefined,
    deviceModel: raw.deviceModel || undefined,
    rating: typeof raw.rating === 'number' ? raw.rating : 5,
    type: raw.type || 'SERVICE_QUALITY',
    typeName: raw.typeName || 'Đánh giá chất lượng',
    tags: Array.isArray(raw.tags) ? raw.tags : [],
    content: raw.content || '',
    images: Array.isArray(raw.images) ? raw.images : [],
    status: raw.status || 'PENDING',
    statusName: raw.statusName || 'Chờ tiếp nhận',
    createdAt: createdStr,
    reply: raw.reply || null,
    replyAt: replyStr || null,
    repliedBy: raw.repliedBy || null,
    isUrgent: raw.isUrgent === true || raw.urgent === true,
  };
}

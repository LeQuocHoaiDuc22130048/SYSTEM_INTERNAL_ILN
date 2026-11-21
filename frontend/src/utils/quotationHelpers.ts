import type { QuotationResponse } from '../types/quotation';

export type QuotationPaymentState =
  | 'VERIFIED'
  | 'PENDING_VERIFY'
  | 'UNPAID'
  | 'NOT_APPLICABLE';

export interface QuotationPaymentMeta {
  state: QuotationPaymentState;
  label: string;
  pillClass: string;
}

/** Định dạng số tiền VND thống nhất trên toàn bộ màn hình báo giá. */
export function formatVnd(amount: number | null | undefined): string {
  return `${new Intl.NumberFormat('vi-VN').format(Math.round(amount || 0))} đ`;
}

/** Định dạng thời gian hiển thị theo chuẩn vi-VN. */
export function formatQuoteDateTime(value?: string | null): string {
  if (!value) return '—';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '—';
  return parsed.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Ánh xạ trạng thái báo giá sang CSS class badge. */
export function getQuotationStatusClass(status: string): string {
  switch (status) {
    case 'SENT':
      return 'sent';
    case 'APPROVED':
      return 'approved';
    case 'PARTIAL_APPROVED':
      return 'partial';
    case 'REJECTED':
    case 'CANCELLED':
    case 'EXPIRED':
      return 'rejected';
    default:
      return 'draft';
  }
}

/** Suy luận trạng thái xác nhận thanh toán từ báo giá & danh sách chứng từ. */
export function getQuotationPaymentMeta(quotation: QuotationResponse): QuotationPaymentMeta {
  const proofs = quotation.paymentProofs ?? [];
  if (proofs.some((p) => p.status === 'VERIFIED')) {
    return {
      state: 'VERIFIED',
      label: 'Đã xác nhận TT',
      pillClass: 'approved',
    };
  }
  if (proofs.some((p) => p.status === 'PENDING_VERIFY')) {
    return {
      state: 'PENDING_VERIFY',
      label: 'Chờ đối soát chứng từ',
      pillClass: 'partial',
    };
  }
  const isApprovedOrder =
    quotation.status === 'APPROVED' || quotation.status === 'PARTIAL_APPROVED';
  if (isApprovedOrder && quotation.totalApprovedAmount > 0) {
    return {
      state: 'UNPAID',
      label: 'Chưa xác nhận thanh toán',
      pillClass: 'sent',
    };
  }
  if (quotation.status === 'SENT') {
    return {
      state: 'NOT_APPLICABLE',
      label: 'Chờ khách duyệt & TT',
      pillClass: 'draft',
    };
  }
  return {
    state: 'NOT_APPLICABLE',
    label: 'Chưa phát sinh thanh toán',
    pillClass: 'draft',
  };
}

/** Kiểm tra quyền quản lý/chỉnh sửa báo giá (đồng bộ với RepairQuotationController). */
export function canManageQuotations(canAction: (perm: string) => boolean): boolean {
  return (
    canAction('REPAIR_QUOTATION_MANAGE') ||
    canAction('REPAIR_CUSTOMER_PUBLISH') ||
    canAction('REPAIR_UPDATE')
  );
}


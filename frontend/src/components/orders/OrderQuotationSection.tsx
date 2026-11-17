import React, { useCallback, useEffect, useState } from 'react';
import {
  FileText,
  Plus,
  Send,
  CheckCircle2,
  XCircle,
  ExternalLink,
} from 'lucide-react';
import type { QuotationResponse } from '../../types/quotation';
import {
  cancelRepairQuotation,
  getQuotationsByOrder,
  sendRepairQuotation,
  verifyQuotationPaymentProof,
} from '../../utils/quotationApi';
import { formatVnd, getQuotationStatusClass } from '../../utils/quotationHelpers';
import { CreateQuotationModal } from './CreateQuotationModal';
import './OrderQuotationSection.css';

interface OrderQuotationSectionProps {
  orderId: string;
  orderCode: string;
  deviceName: string;
  serialNumber?: string | null;
  customerId?: string | null;
  customerName?: string | null;
  orderStatus: string;
  canManage: boolean;
  onRefreshOrder?: () => void;
  showToast?: (msg: string) => void;
}

export const OrderQuotationSection: React.FC<OrderQuotationSectionProps> = ({
  orderId,
  orderCode,
  deviceName,
  serialNumber,
  customerId,
  customerName,
  orderStatus,
  canManage,
  onRefreshOrder,
  showToast,
}) => {
  const [quotations, setQuotations] = useState<QuotationResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [isCreateOpen, setIsCreateOpen] = useState(false);

  const fetchQuotations = useCallback(async () => {
    if (!orderId) return;
    setLoading(true);
    const res = await getQuotationsByOrder(orderId);
    if (res.success && res.data) {
      setQuotations(res.data);
    }
    setLoading(false);
  }, [orderId]);

  useEffect(() => {
    fetchQuotations();
  }, [fetchQuotations]);

  const hasActiveQuotation = quotations.some(
    (q) => q.status === 'DRAFT' || q.status === 'SENT'
  );
  const canCreateQuotation =
    canManage &&
    !!customerId &&
    !hasActiveQuotation &&
    orderStatus !== 'DELIVERED' &&
    orderStatus !== 'CANCELLED';

  const handleSendDraft = async (quoteId: string) => {
    const res = await sendRepairQuotation(quoteId);
    if (res.success) {
      showToast?.('Đã gửi báo giá tới khách hàng');
      fetchQuotations();
      onRefreshOrder?.();
    } else {
      showToast?.(res.message || 'Không thể gửi báo giá');
    }
  };

  const handleCancelQuote = async (quoteId: string) => {
    if (!window.confirm('Bạn có chắc muốn hủy báo giá này?')) return;
    const res = await cancelRepairQuotation(quoteId);
    if (res.success) {
      showToast?.('Đã hủy báo giá');
      fetchQuotations();
      onRefreshOrder?.();
    } else {
      showToast?.(res.message || 'Không thể hủy báo giá');
    }
  };

  const handleVerifyProof = async (proofId: string, approved: boolean) => {
    let reason: string | undefined;
    if (!approved) {
      const input = window.prompt('Nhập lý do từ chối chứng từ thanh toán:');
      if (!input || !input.trim()) return;
      reason = input.trim();
    }
    const res = await verifyQuotationPaymentProof(proofId, approved, reason);
    if (res.success) {
      showToast?.(approved ? 'Đã xác nhận nhận thanh toán' : 'Đã từ chối chứng từ');
      fetchQuotations();
    } else {
      showToast?.(res.message || 'Không thể xử lý chứng từ');
    }
  };

  return (
    <div className="detail-content-section quotation-section">
      <div className="quotation-section-header">
        <h4 className="section-title" style={{ margin: 0 }}>
          <FileText size={16} style={{ display: 'inline', marginRight: 6 }} />
          Báo giá sửa chữa ({quotations.length})
        </h4>
        {canCreateQuotation && (
          <button
            type="button"
            className="quotation-create-btn"
            onClick={() => setIsCreateOpen(true)}
          >
            <Plus size={14} />
            Tạo báo giá
          </button>
        )}
      </div>

      {!customerId && (
        <p style={{ fontSize: '0.82rem', color: '#64748b', margin: '4px 0 8px' }}>
          Gán hồ sơ khách hàng cho đơn này để tạo báo giá trực tuyến (có thể gộp nhiều máy cùng khách hàng).
        </p>
      )}

      {loading ? (
        <p style={{ fontSize: '0.82rem', color: '#64748b' }}>Đang tải báo giá...</p>
      ) : quotations.length === 0 ? (
        <p style={{ fontSize: '0.82rem', color: '#94a3b8' }}>Chưa có phiếu báo giá nào cho đơn này.</p>
      ) : (
        quotations.map((quote) => (
          <div key={quote.id} className="quotation-card">
            <div className="quotation-card-top">
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span className="quotation-code-pill">{quote.quoteCode}</span>
                {quote.itemCount > 1 && (
                  <span style={{ fontSize: '0.75rem', color: '#25437a', fontWeight: 600 }}>
                    Gộp {quote.itemCount} máy
                  </span>
                )}
              </div>
              <span className={`quotation-status-pill ${getQuotationStatusClass(quote.status)}`}>
                {quote.statusLabel}
              </span>
            </div>

            <div className="quotation-meta-row">
              <span>Dự kiến: <strong>{formatVnd(quote.totalEstimatedAmount)}</strong></span>
              {(quote.status === 'APPROVED' || quote.status === 'PARTIAL_APPROVED') && (
                <span style={{ color: '#15803d' }}>
                  Khách chốt ({quote.approvedItemCount}/{quote.itemCount} máy):{' '}
                  <strong>{formatVnd(quote.totalApprovedAmount)}</strong>
                </span>
              )}
            </div>

            <div className="quotation-items-list">
              {quote.items.map((item) => (
                <div key={item.id} className="quotation-item-row">
                  <div>
                    <div style={{ fontWeight: 600, color: '#0f172a' }}>
                      {item.orderCode} · {item.deviceName}
                    </div>
                    <div style={{ fontSize: '0.74rem', color: '#64748b' }}>
                      Chi phí: {formatVnd(item.baseCost)}
                      {item.selectedWarrantyLabel ? ` • ${item.selectedWarrantyLabel}` : ''}
                      {item.rejectReason ? ` • Lý do: ${item.rejectReason}` : ''}
                    </div>
                  </div>
                  <span
                    className={`quotation-status-pill ${
                      item.decision === 'APPROVED'
                        ? 'approved'
                        : item.decision === 'REJECTED'
                        ? 'rejected'
                        : 'sent'
                    }`}
                  >
                    {item.decisionLabel}
                  </span>
                </div>
              ))}
            </div>

            {canManage && (quote.status === 'DRAFT' || quote.status === 'SENT') && (
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                {quote.status === 'DRAFT' && (
                  <button
                    type="button"
                    className="quotation-btn-sm primary"
                    onClick={() => handleSendDraft(quote.id)}
                  >
                    <Send size={12} style={{ display: 'inline', marginRight: 4 }} />
                    Gửi khách hàng
                  </button>
                )}
                <button
                  type="button"
                  className="quotation-btn-sm danger"
                  onClick={() => handleCancelQuote(quote.id)}
                >
                  Hủy báo giá
                </button>
              </div>
            )}

            {quote.paymentProofs && quote.paymentProofs.length > 0 && (
              <div className="quotation-proof-box">
                <div style={{ fontSize: '0.78rem', fontWeight: 700, color: '#0f172a', marginBottom: 6 }}>
                  Chứng từ chuyển khoản ({quote.paymentProofs.length})
                </div>
                {quote.paymentProofs.map((proof) => (
                  <div
                    key={proof.id}
                    style={{
                      borderTop: '1px solid #f1f5f9',
                      paddingTop: 6,
                      marginTop: 6,
                      fontSize: '0.78rem',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span>
                        <strong>{formatVnd(proof.amount)}</strong> · ND: <code>{proof.transferContent}</code>
                      </span>
                      <span
                        className={`quotation-status-pill ${
                          proof.status === 'VERIFIED'
                            ? 'approved'
                            : proof.status === 'REJECTED'
                            ? 'rejected'
                            : 'sent'
                        }`}
                      >
                        {proof.statusLabel}
                      </span>
                    </div>
                    <div style={{ marginTop: 4, display: 'flex', alignItems: 'center', gap: 10 }}>
                      <a
                        href={proof.proofFileUrl}
                        target="_blank"
                        rel="noreferrer"
                        style={{ color: '#2563eb', display: 'inline-flex', alignItems: 'center', gap: 4 }}
                      >
                        <ExternalLink size={12} />
                        Xem ảnh/file ({proof.proofFileName || 'Chứng từ'})
                      </a>
                    </div>
                    {proof.rejectionReason && (
                      <div style={{ color: '#b91c1c', marginTop: 4 }}>
                        Lý do từ chối: {proof.rejectionReason}
                      </div>
                    )}
                    {canManage && proof.status === 'PENDING_VERIFY' && (
                      <div className="quotation-proof-actions">
                        <button
                          type="button"
                          className="quotation-btn-sm primary"
                          onClick={() => handleVerifyProof(proof.id, true)}
                        >
                          <CheckCircle2 size={12} style={{ display: 'inline', marginRight: 4 }} />
                          Xác nhận đã nhận tiền
                        </button>
                        <button
                          type="button"
                          className="quotation-btn-sm danger"
                          onClick={() => handleVerifyProof(proof.id, false)}
                        >
                          <XCircle size={12} style={{ display: 'inline', marginRight: 4 }} />
                          Từ chối chứng từ
                        </button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ))
      )}

      <CreateQuotationModal
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        initialCustomerId={customerId}
        initialCustomerName={customerName}
        pinnedOrder={{ id: orderId, orderCode, deviceName, serialNumber }}
        onCreated={(created, sentNow) => {
          showToast?.(
            sentNow
              ? `Đã tạo và gửi báo giá ${created.quoteCode} (${created.itemCount} máy) cho khách hàng`
              : `Đã lưu nháp báo giá ${created.quoteCode}`
          );
          setIsCreateOpen(false);
          fetchQuotations();
          onRefreshOrder?.();
        }}
      />
    </div>
  );
};

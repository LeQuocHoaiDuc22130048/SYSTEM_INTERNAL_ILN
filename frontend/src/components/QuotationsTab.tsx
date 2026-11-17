import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  CheckCircle2,
  ExternalLink,
  FileText,
  Landmark,
  Plus,
  RefreshCw,
  Search,
  Send,
  ShieldCheck,
  User,
  XCircle,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import type { QuotationResponse } from '../types/quotation';
import { usePermissionCheck } from '../utils/permissionContext';
import {
  cancelRepairQuotation,
  getRepairQuotationById,
  searchRepairQuotations,
  sendRepairQuotation,
  verifyQuotationPaymentProof,
} from '../utils/quotationApi';
import {
  canManageQuotations,
  formatQuoteDateTime,
  formatVnd,
  getQuotationPaymentMeta,
  getQuotationStatusClass,
} from '../utils/quotationHelpers';
import { CreateQuotationModal } from './orders/CreateQuotationModal';
import './OrdersTab.css';
import './orders/OrderQuotationSection.css';
import './QuotationsTab.css';

type FilterPreset =
  | 'ALL'
  | 'SENT'
  | 'UNPAID'
  | 'PENDING_VERIFY'
  | 'PAID'
  | 'DRAFT'
  | 'CLOSED';

interface QuotationsTabProps {
  showToast?: (message: string) => void;
  currentUser?: UserInfo | null;
  refreshTrigger?: number;
}

export const QuotationsTab: React.FC<QuotationsTabProps> = ({
  showToast,
  refreshTrigger = 0,
}) => {
  const canAction = usePermissionCheck();
  const canManage = useMemo(() => canManageQuotations(canAction), [canAction]);

  const [quotations, setQuotations] = useState<QuotationResponse[]>([]);
  const [totalElements, setTotalElements] = useState<number>(0);
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedId, setSelectedId] = useState<string>('');
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [filterPreset, setFilterPreset] = useState<FilterPreset>('ALL');
  const [isCreateOpen, setIsCreateOpen] = useState<boolean>(false);
  const [createForCustomer, setCreateForCustomer] = useState<{ id: string; name: string } | null>(null);
  const [acting, setActing] = useState<boolean>(false);
  const [rejectingProofId, setRejectingProofId] = useState<string | null>(null);
  const [rejectReasonInput, setRejectReasonInput] = useState<string>('');

  const fetchQuotations = useCallback(async (isSilent = false) => {
    if (!isSilent) setLoading(true);
    const res = await searchRepairQuotations({ page: 0, size: 200 });
    if (res.success && res.data) {
      const list = res.data.content || [];
      setQuotations(list);
      setTotalElements(res.data.totalElements ?? list.length);
      setSelectedId((prev) => {
        if (prev && list.some((q) => q.id === prev)) return prev;
        return list[0]?.id ?? '';
      });
    } else if (!isSilent) {
      showToast?.(res.message || 'Không thể tải danh sách báo giá');
    }
    setLoading(false);
  }, [showToast]);

  useEffect(() => {
    void fetchQuotations();
  }, [fetchQuotations, refreshTrigger]);

  const refreshOne = async (quotationId: string) => {
    const detail = await getRepairQuotationById(quotationId);
    if (detail.success && detail.data) {
      setQuotations((prev) =>
        prev.map((q) => (q.id === quotationId ? detail.data! : q))
      );
    } else {
      await fetchQuotations(true);
    }
  };

  const summary = useMemo(() => {
    let sent = 0;
    let unpaid = 0;
    let pendingVerify = 0;
    let paid = 0;

    for (const q of quotations) {
      if (q.status === 'SENT') sent += 1;
      const payMeta = getQuotationPaymentMeta(q);
      if (payMeta.state === 'PENDING_VERIFY') {
        pendingVerify += 1;
        unpaid += 1;
      } else if (payMeta.state === 'UNPAID') {
        unpaid += 1;
      } else if (payMeta.state === 'VERIFIED') {
        paid += 1;
      }
    }
    return {
      total: quotations.length,
      sent,
      unpaid,
      pendingVerify,
      paid,
    };
  }, [quotations]);

  const filteredQuotations = useMemo(() => {
    const kw = searchTerm.trim().toLowerCase();
    return quotations.filter((q) => {
      const payMeta = getQuotationPaymentMeta(q);
      if (filterPreset === 'SENT' && q.status !== 'SENT') return false;
      if (
        filterPreset === 'UNPAID' &&
        payMeta.state !== 'UNPAID' &&
        payMeta.state !== 'PENDING_VERIFY'
      ) {
        return false;
      }
      if (filterPreset === 'PENDING_VERIFY' && payMeta.state !== 'PENDING_VERIFY') return false;
      if (filterPreset === 'PAID' && payMeta.state !== 'VERIFIED') return false;
      if (filterPreset === 'DRAFT' && q.status !== 'DRAFT') return false;
      if (
        filterPreset === 'CLOSED' &&
        q.status !== 'REJECTED' &&
        q.status !== 'CANCELLED' &&
        q.status !== 'EXPIRED'
      ) {
        return false;
      }

      if (!kw) return true;
      const haystack = [
        q.quoteCode,
        q.customerName,
        q.customerPhone || '',
        q.title || '',
        ...q.items.flatMap((i) => [i.orderCode, i.deviceName, i.serialNumber || '']),
      ]
        .join(' ')
        .toLowerCase();
      return haystack.includes(kw);
    });
  }, [quotations, filterPreset, searchTerm]);

  const selectedQuotation = useMemo(
    () =>
      filteredQuotations.find((q) => q.id === selectedId) ||
      quotations.find((q) => q.id === selectedId) ||
      null,
    [filteredQuotations, quotations, selectedId]
  );

  const handleSendDraft = async (quotation: QuotationResponse) => {
    setActing(true);
    const res = await sendRepairQuotation(quotation.id);
    setActing(false);
    if (res.success) {
      showToast?.(`Đã gửi báo giá ${quotation.quoteCode} tới khách hàng`);
      await refreshOne(quotation.id);
    } else {
      showToast?.(res.message || 'Không thể gửi báo giá');
    }
  };

  const handleCancelQuote = async (quotation: QuotationResponse) => {
    if (!window.confirm(`Bạn có chắc muốn hủy báo giá ${quotation.quoteCode}?`)) return;
    setActing(true);
    const res = await cancelRepairQuotation(quotation.id);
    setActing(false);
    if (res.success) {
      showToast?.(`Đã hủy báo giá ${quotation.quoteCode}`);
      await refreshOne(quotation.id);
    } else {
      showToast?.(res.message || 'Không thể hủy báo giá');
    }
  };

  const handleVerifyProof = async (
    quotationId: string,
    proofId: string,
    approved: boolean,
    reason?: string
  ) => {
    if (!approved && (!reason || !reason.trim())) {
      showToast?.('Vui lòng nhập lý do từ chối chứng từ');
      return;
    }
    setActing(true);
    const res = await verifyQuotationPaymentProof(proofId, approved, reason?.trim());
    setActing(false);
    if (res.success) {
      showToast?.(approved ? 'Đã xác nhận đã nhận thanh toán' : 'Đã từ chối chứng từ thanh toán');
      setRejectingProofId(null);
      setRejectReasonInput('');
      await refreshOne(quotationId);
    } else {
      showToast?.(res.message || 'Không thể xử lý chứng từ');
    }
  };

  return (
    <div className="orders-container">
      <div className="orders-layout">
        {/* Cột trái: Thống kê, tìm kiếm & danh sách báo giá */}
        <div className="orders-list-panel">
          <div className="quotations-summary-bar">
            <button
              type="button"
              className={`quotation-stat-btn ${filterPreset === 'ALL' ? 'active' : ''}`}
              onClick={() => setFilterPreset('ALL')}
            >
              <span className="quotation-stat-val">{summary.total}</span>
              <span className="quotation-stat-lbl">Tổng báo giá</span>
            </button>
            <button
              type="button"
              className={`quotation-stat-btn ${filterPreset === 'SENT' ? 'active' : ''}`}
              onClick={() => setFilterPreset('SENT')}
            >
              <span className="quotation-stat-val" style={{ color: '#b45309' }}>{summary.sent}</span>
              <span className="quotation-stat-lbl">Chờ khách duyệt</span>
            </button>
            <button
              type="button"
              className={`quotation-stat-btn ${filterPreset === 'UNPAID' ? 'active' : ''}`}
              onClick={() => setFilterPreset('UNPAID')}
            >
              <span className="quotation-stat-val" style={{ color: '#c2410c' }}>{summary.unpaid}</span>
              <span className="quotation-stat-lbl">Chưa xác nhận TT</span>
            </button>
            <button
              type="button"
              className={`quotation-stat-btn ${filterPreset === 'PENDING_VERIFY' ? 'active' : ''}`}
              onClick={() => setFilterPreset('PENDING_VERIFY')}
            >
              <span className="quotation-stat-val" style={{ color: '#1d4ed8' }}>{summary.pendingVerify}</span>
              <span className="quotation-stat-lbl">Chờ đối soát</span>
            </button>
            <button
              type="button"
              className={`quotation-stat-btn ${filterPreset === 'PAID' ? 'active' : ''}`}
              onClick={() => setFilterPreset('PAID')}
            >
              <span className="quotation-stat-val" style={{ color: '#15803d' }}>{summary.paid}</span>
              <span className="quotation-stat-lbl">Đã nhận tiền</span>
            </button>
          </div>

          <div className="orders-filter-card">
            <div className="search-box-row">
              <div className="search-input-wrapper">
                <Search size={16} className="search-icon" />
                <input
                  type="text"
                  className="orders-search-input"
                  placeholder="Tìm mã báo giá, tên KH, SĐT, mã đơn RO, tên máy..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                />
              </div>
              {canManage && (
                <button
                  type="button"
                  className="quotation-create-btn"
                  onClick={() => {
                    setCreateForCustomer(null);
                    setIsCreateOpen(true);
                  }}
                >
                  <Plus size={15} />
                  Tạo báo giá
                </button>
              )}
            </div>

            <div className="quotation-toolbar-row">
              <select
                value={filterPreset}
                onChange={(e) => setFilterPreset(e.target.value as FilterPreset)}
                aria-label="Lọc trạng thái báo giá"
              >
                <option value="ALL">Tất cả trạng thái ({totalElements})</option>
                <option value="SENT">Chờ khách duyệt ({summary.sent})</option>
                <option value="UNPAID">Đã duyệt - Chưa xác nhận thanh toán ({summary.unpaid})</option>
                <option value="PENDING_VERIFY">Có chứng từ chờ đối soát ({summary.pendingVerify})</option>
                <option value="PAID">Đã xác nhận thanh toán ({summary.paid})</option>
                <option value="DRAFT">Bản nháp (DRAFT)</option>
                <option value="CLOSED">Từ chối / Đã hủy / Hết hạn</option>
              </select>

              <button
                type="button"
                className="quotation-btn-sm"
                onClick={() => void fetchQuotations()}
                disabled={loading}
                style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}
              >
                <RefreshCw size={13} className={loading ? 'spin' : ''} />
                Tải lại
              </button>
            </div>
          </div>

          <div className="quotations-list-scroll">
            {loading ? (
              <div className="quotation-picker-empty">Đang tải danh sách báo giá...</div>
            ) : filteredQuotations.length === 0 ? (
              <div className="quotation-picker-empty">
                Không có báo giá nào khớp bộ lọc hiện tại.
              </div>
            ) : (
              filteredQuotations.map((q) => {
                const payMeta = getQuotationPaymentMeta(q);
                const isSelected = selectedQuotation?.id === q.id;
                return (
                  <button
                    key={q.id}
                    type="button"
                    className={`quotation-list-card ${isSelected ? 'selected' : ''}`}
                    onClick={() => {
                      setSelectedId(q.id);
                      setRejectingProofId(null);
                      setRejectReasonInput('');
                    }}
                  >
                    <div className="quotation-list-top">
                      <div className="quotation-badges-row">
                        <span className="quotation-code-pill">{q.quoteCode}</span>
                        {q.itemCount > 1 && (
                          <span style={{ fontSize: '0.73rem', fontWeight: 700, color: '#25437a' }}>
                            Gộp {q.itemCount} máy
                          </span>
                        )}
                      </div>
                      <div className="quotation-badges-row">
                        <span className={`quotation-status-pill ${getQuotationStatusClass(q.status)}`}>
                          {q.statusLabel}
                        </span>
                        {payMeta.state !== 'NOT_APPLICABLE' && (
                          <span className={`quotation-status-pill ${payMeta.pillClass}`}>
                            {payMeta.label}
                          </span>
                        )}
                      </div>
                    </div>

                    <div className="quotation-list-customer">{q.customerName}</div>
                    <div className="quotation-list-sub">
                      <span>{q.customerPhone || 'Không có SĐT'}</span>
                      <span>•</span>
                      <span>Tạo lúc {formatQuoteDateTime(q.createdAt)}</span>
                    </div>

                    <div className="quotation-list-orders">
                      {q.items.map((item) => (
                        <span key={item.id} className="quotation-order-tag">
                          {item.orderCode} · {item.deviceName}
                        </span>
                      ))}
                    </div>

                    <div className="quotation-list-footer">
                      <span>
                        Dự kiến: <strong>{formatVnd(q.totalEstimatedAmount)}</strong>
                      </span>
                      {(q.status === 'APPROVED' || q.status === 'PARTIAL_APPROVED') && (
                        <span style={{ color: '#15803d', fontWeight: 600 }}>
                          Khách chốt: {formatVnd(q.totalApprovedAmount)}
                        </span>
                      )}
                    </div>
                  </button>
                );
              })
            )}
          </div>
        </div>

        {/* Cột phải: Chi tiết phiếu báo giá & đối soát chứng từ */}
        <div className="quotation-detail-panel">
          {!selectedQuotation ? (
            <div className="quotation-picker-empty" style={{ margin: 'auto' }}>
              <FileText size={32} style={{ color: '#94a3b8', marginBottom: 8 }} />
              <div>Chọn một phiếu báo giá bên trái để xem chi tiết, thiết bị và đối soát thanh toán.</div>
            </div>
          ) : (
            (() => {
              const payMeta = getQuotationPaymentMeta(selectedQuotation);
              return (
                <>
                  <div className="quotation-detail-header">
                    <div>
                      <div className="quotation-badges-row">
                        <span className="quotation-code-pill">{selectedQuotation.quoteCode}</span>
                        <span className={`quotation-status-pill ${getQuotationStatusClass(selectedQuotation.status)}`}>
                          {selectedQuotation.statusLabel}
                        </span>
                        <span className={`quotation-status-pill ${payMeta.pillClass}`}>
                          {payMeta.label}
                        </span>
                      </div>
                      <h3 style={{ margin: '8px 0 4px', fontSize: '1.05rem', color: '#0f172a' }}>
                        {selectedQuotation.title || `Báo giá sửa chữa (${selectedQuotation.itemCount} thiết bị)`}
                      </h3>
                      <div className="quotation-list-sub">
                        <User size={13} />
                        <strong>{selectedQuotation.customerName}</strong>
                        <span>• {selectedQuotation.customerPhone || 'Chưa có SĐT'}</span>
                      </div>
                      <div className="quotation-list-sub" style={{ marginTop: 4 }}>
                        <span>Tạo: {formatQuoteDateTime(selectedQuotation.createdAt)}</span>
                        {selectedQuotation.sentAt && (
                          <span>• Gửi: {formatQuoteDateTime(selectedQuotation.sentAt)}</span>
                        )}
                        {selectedQuotation.respondedAt && (
                          <span>• Phản hồi: {formatQuoteDateTime(selectedQuotation.respondedAt)}</span>
                        )}
                      </div>
                    </div>

                    {canManage && (
                      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                        {selectedQuotation.status === 'DRAFT' && (
                          <button
                            type="button"
                            className="quotation-btn-sm primary"
                            disabled={acting}
                            onClick={() => void handleSendDraft(selectedQuotation)}
                          >
                            <Send size={13} style={{ display: 'inline', marginRight: 4 }} />
                            Gửi khách hàng
                          </button>
                        )}
                        {(selectedQuotation.status === 'DRAFT' || selectedQuotation.status === 'SENT') && (
                          <button
                            type="button"
                            className="quotation-btn-sm danger"
                            disabled={acting}
                            onClick={() => void handleCancelQuote(selectedQuotation)}
                          >
                            Hủy báo giá
                          </button>
                        )}
                        <button
                          type="button"
                          className="quotation-btn-sm"
                          onClick={() => {
                            setCreateForCustomer({
                              id: selectedQuotation.customerId,
                              name: selectedQuotation.customerName,
                            });
                            setIsCreateOpen(true);
                          }}
                        >
                          + Tạo phiếu mới cho KH này
                        </button>
                      </div>
                    )}
                  </div>

                  {selectedQuotation.note && (
                    <div
                      style={{
                        background: '#f8fafc',
                        border: '1px solid #e2e8f0',
                        borderRadius: 10,
                        padding: '10px 12px',
                        fontSize: '0.82rem',
                        color: '#334155',
                      }}
                    >
                      <strong>Ghi chú gửi khách:</strong> {selectedQuotation.note}
                    </div>
                  )}

                  <div className="quotation-finance-grid">
                    <div className="quotation-finance-card">
                      <div className="quotation-finance-label">Tổng chi phí dự kiến</div>
                      <div className="quotation-finance-value">
                        {formatVnd(selectedQuotation.totalEstimatedAmount)}
                      </div>
                    </div>
                    <div className="quotation-finance-card">
                      <div className="quotation-finance-label">
                        Tổng khách chốt ({selectedQuotation.approvedItemCount}/{selectedQuotation.itemCount} máy)
                      </div>
                      <div className="quotation-finance-value" style={{ color: '#15803d' }}>
                        {formatVnd(selectedQuotation.totalApprovedAmount)}
                      </div>
                    </div>
                    <div className="quotation-finance-card">
                      <div className="quotation-finance-label">Chứng từ thanh toán</div>
                      <div className="quotation-finance-value" style={{ fontSize: '0.9rem' }}>
                        {payMeta.label} ({selectedQuotation.paymentProofs.length})
                      </div>
                    </div>
                  </div>

                  {/* Chi tiết từng thiết bị / đơn sửa chữa */}
                  <div>
                    <h4 style={{ margin: '0 0 10px', fontSize: '0.9rem', color: '#0f172a' }}>
                      Chi tiết thiết bị trong báo giá ({selectedQuotation.items.length})
                    </h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      {selectedQuotation.items.map((item) => (
                        <div key={item.id} className="quotation-device-detail-card">
                          <div className="quotation-device-detail-head">
                            <div>
                              <div style={{ fontWeight: 700, color: '#0f172a', fontSize: '0.9rem' }}>
                                {item.orderCode} · {item.deviceName}
                              </div>
                              <div style={{ fontSize: '0.77rem', color: '#64748b', marginTop: 2 }}>
                                {item.deviceType ? `Loại: ${item.deviceType} • ` : ''}
                                S/N: {item.serialNumber || 'Chưa cập nhật'}
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

                          {item.diagnosedErrors && item.diagnosedErrors.length > 0 && (
                            <div className="quotation-error-chips">
                              {item.diagnosedErrors.map((err, idx) => (
                                <span key={`${err.label}-${idx}`} className="quotation-error-chip">
                                  {err.label}
                                </span>
                              ))}
                            </div>
                          )}

                          <table className="quotation-line-table">
                            <thead>
                              <tr>
                                <th>Hạng mục sửa chữa</th>
                                <th className="num">SL</th>
                                <th className="num">Đơn giá</th>
                                <th className="num">Thành tiền</th>
                              </tr>
                            </thead>
                            <tbody>
                              {item.lineItems.map((line) => (
                                <tr key={line.id}>
                                  <td>{line.description}</td>
                                  <td className="num">{line.quantity}</td>
                                  <td className="num">{formatVnd(line.unitPrice)}</td>
                                  <td className="num">
                                    <strong>{formatVnd(line.amount)}</strong>
                                  </td>
                                </tr>
                              ))}
                            </tbody>
                          </table>

                          <div
                            style={{
                              marginTop: 8,
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              flexWrap: 'wrap',
                              gap: 8,
                              fontSize: '0.8rem',
                              color: '#334155',
                            }}
                          >
                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                              <ShieldCheck size={14} />
                              {item.selectedWarrantyLabel
                                ? `Đã chọn: ${item.selectedWarrantyLabel} (+${formatVnd(item.warrantyFee)})`
                                : `Tùy chọn BH: ${item.warrantyOptions.map((w) => w.label).join(' / ') || 'Tiêu chuẩn'}`}
                            </span>
                            <span>
                              Thành tiền máy: <strong style={{ color: '#25437a' }}>{formatVnd(item.finalAmount)}</strong>
                            </span>
                          </div>

                          {item.rejectReason && (
                            <div style={{ marginTop: 6, fontSize: '0.78rem', color: '#b91c1c' }}>
                              Lý do khách từ chối: {item.rejectReason}
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Thông tin tài khoản nhận thanh toán VietQR */}
                  {selectedQuotation.bankInfo && (
                    <div className="quotation-bank-box">
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 700 }}>
                        <Landmark size={15} />
                        Thông tin chuyển khoản VietQR trên phiếu báo giá
                      </div>
                      <div className="quotation-bank-grid">
                        <div>
                          Ngân hàng: <strong>{selectedQuotation.bankInfo.bankName}</strong> ({selectedQuotation.bankInfo.bankBin})
                        </div>
                        <div>
                          Số TK: <code>{selectedQuotation.bankInfo.bankAccountNumber}</code>
                        </div>
                        <div>
                          Chủ TK: <strong>{selectedQuotation.bankInfo.bankAccountHolder}</strong>
                        </div>
                        <div>
                          Nội dung CK: <code>{selectedQuotation.bankInfo.transferContent}</code>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Chứng từ thanh toán & Đối soát */}
                  <div className="quotation-proof-box" style={{ marginTop: 0 }}>
                    <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#0f172a', marginBottom: 6 }}>
                      Chứng từ thanh toán khách gửi ({selectedQuotation.paymentProofs.length})
                    </div>
                    {selectedQuotation.paymentProofs.length === 0 ? (
                      <div style={{ fontSize: '0.8rem', color: '#64748b' }}>
                        Khách hàng chưa tải lên chứng từ chuyển khoản nào cho báo giá này.
                      </div>
                    ) : (
                      selectedQuotation.paymentProofs.map((proof) => (
                        <div
                          key={proof.id}
                          style={{
                            borderTop: '1px solid #f1f5f9',
                            paddingTop: 10,
                            marginTop: 8,
                            fontSize: '0.8rem',
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
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

                          <div style={{ marginTop: 4, color: '#64748b', fontSize: '0.75rem' }}>
                            Gửi lúc: {formatQuoteDateTime(proof.createdAt)}
                            {proof.verifiedAt ? ` • Đối soát: ${formatQuoteDateTime(proof.verifiedAt)}` : ''}
                            {proof.note ? ` • Ghi chú: ${proof.note}` : ''}
                          </div>

                          <div style={{ marginTop: 6 }}>
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
                            <>
                              <div className="quotation-proof-actions">
                                <button
                                  type="button"
                                  className="quotation-btn-sm primary"
                                  disabled={acting}
                                  onClick={() => void handleVerifyProof(selectedQuotation.id, proof.id, true)}
                                >
                                  <CheckCircle2 size={12} style={{ display: 'inline', marginRight: 4 }} />
                                  Xác nhận đã nhận tiền
                                </button>
                                <button
                                  type="button"
                                  className="quotation-btn-sm danger"
                                  disabled={acting}
                                  onClick={() => {
                                    setRejectingProofId(proof.id);
                                    setRejectReasonInput('');
                                  }}
                                >
                                  <XCircle size={12} style={{ display: 'inline', marginRight: 4 }} />
                                  Từ chối chứng từ
                                </button>
                              </div>

                              {rejectingProofId === proof.id && (
                                <div className="quotation-reject-inline">
                                  <input
                                    type="text"
                                    placeholder="Nhập lý do từ chối chứng từ (VD: Sai số tiền / Chưa nhận được tiền)..."
                                    value={rejectReasonInput}
                                    onChange={(e) => setRejectReasonInput(e.target.value)}
                                  />
                                  <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                                    <button
                                      type="button"
                                      className="quotation-btn-sm"
                                      onClick={() => {
                                        setRejectingProofId(null);
                                        setRejectReasonInput('');
                                      }}
                                    >
                                      Hủy
                                    </button>
                                    <button
                                      type="button"
                                      className="quotation-btn-sm danger"
                                      disabled={acting || !rejectReasonInput.trim()}
                                      onClick={() =>
                                        void handleVerifyProof(
                                          selectedQuotation.id,
                                          proof.id,
                                          false,
                                          rejectReasonInput
                                        )
                                      }
                                    >
                                      Xác nhận từ chối
                                    </button>
                                  </div>
                                </div>
                              )}
                            </>
                          )}
                        </div>
                      ))
                    )}
                  </div>
                </>
              );
            })()
          )}
        </div>
      </div>

      <CreateQuotationModal
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        initialCustomerId={createForCustomer?.id}
        initialCustomerName={createForCustomer?.name}
        onCreated={(created, sentNow) => {
          showToast?.(
            sentNow
              ? `Đã tạo và gửi báo giá ${created.quoteCode} (${created.itemCount} máy) cho khách hàng`
              : `Đã lưu nháp báo giá ${created.quoteCode}`
          );
          setIsCreateOpen(false);
          setSelectedId(created.id);
          void fetchQuotations(true);
        }}
      />
    </div>
  );
};


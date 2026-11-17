import React, { useEffect, useMemo, useRef, useState } from 'react';
import QRCode from 'qrcode';
import {
  AlertTriangle,
  ArrowLeft,
  Check,
  CheckCircle2,
  Copy,
  Cpu,
  CreditCard,
  FileText,
  Phone,
  QrCode,
  Trash2,
  UploadCloud,
  X,
  XCircle,
} from 'lucide-react';
import type {
  QuotationItemDecision,
  QuotationItemResponse,
  QuotationResponse,
} from '../../types/quotation';
import {
  respondToCustomerQuotation,
  submitCustomerPaymentProof,
} from '../../utils/quotationApi';
import './CustomerQuotationModal.css';

interface CustomerQuotationModalProps {
  quotation: QuotationResponse;
  hotlineNumber?: string;
  initialOrderId?: string | null;
  onClose: () => void;
  onUpdated: (updated: QuotationResponse) => void;
}

interface LocalItemChoice {
  decision: QuotationItemDecision;
  selectedWarrantyCode: string;
  rejectReason: string;
}

const formatVnd = (amount: number) =>
  `${new Intl.NumberFormat('vi-VN').format(Math.round(amount || 0))} đ`;

export const CustomerQuotationModal: React.FC<CustomerQuotationModalProps> = ({
  quotation,
  hotlineNumber = '0964 266 771',
  initialOrderId,
  onClose,
  onUpdated,
}) => {
  const isWaitingResponse = quotation.status === 'SENT';
  const canPayNow =
    quotation.status === 'APPROVED' || quotation.status === 'PARTIAL_APPROVED';

  const [step, setStep] = useState<'REVIEW' | 'PAYMENT'>(
    !isWaitingResponse && canPayNow ? 'PAYMENT' : 'REVIEW'
  );

  const [activeIndex, setActiveIndex] = useState<number>(() => {
    if (!initialOrderId) return 0;
    const found = quotation.items.findIndex((i) => i.repairOrderId === initialOrderId);
    return found >= 0 ? found : 0;
  });

  const [choices, setChoices] = useState<Record<string, LocalItemChoice>>(() => {
    const map: Record<string, LocalItemChoice> = {};
    for (const item of quotation.items) {
      map[item.id] = {
        decision: item.decision,
        selectedWarrantyCode:
          item.selectedWarrantyCode || item.warrantyOptions[0]?.code || 'STANDARD_6M',
        rejectReason: item.rejectReason || '',
      };
    }
    return map;
  });

  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  // Payment proof step states
  const [qrDataUrl, setQrDataUrl] = useState<string>('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploadingProof, setUploadingProof] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const isMultiDevice = quotation.items.length > 1;
  const activeItem: QuotationItemResponse | undefined = quotation.items[activeIndex] || quotation.items[0];

  useEffect(() => {
    const payload = quotation.bankInfo?.vietQrPayload;
    if (!payload) {
      setQrDataUrl('');
      return;
    }
    QRCode.toDataURL(payload, { width: 160, margin: 1 })
      .then(setQrDataUrl)
      .catch(() => setQrDataUrl(''));
  }, [quotation.bankInfo?.vietQrPayload]);

  const handleCopy = (key: string, value: string) => {
    navigator.clipboard?.writeText(value).then(() => {
      setCopiedKey(key);
      setTimeout(() => setCopiedKey(null), 1800);
    });
  };

  const updateChoice = (itemId: string, patch: Partial<LocalItemChoice>) => {
    setChoices((prev) => ({
      ...prev,
      [itemId]: { ...prev[itemId], ...patch },
    }));
  };

  const summary = useMemo(() => {
    let approvedCount = 0;
    let rejectedCount = 0;
    let pendingCount = 0;
    let totalAmount = 0;

    for (const item of quotation.items) {
      const ch = choices[item.id];
      const decision = isWaitingResponse ? ch?.decision || 'PENDING' : item.decision;

      if (decision === 'REJECTED') {
        rejectedCount++;
        continue;
      }
      if (isWaitingResponse && !isMultiDevice && decision === 'PENDING') {
        // 1-machine mode: preview total directly based on selected warranty
        const w = item.warrantyOptions.find((o) => o.code === ch?.selectedWarrantyCode) || item.warrantyOptions[0];
        totalAmount += Number(item.baseCost || 0) + Number(w?.fee || 0);
        pendingCount++;
        continue;
      }
      if (decision === 'APPROVED') {
        approvedCount++;
        if (isWaitingResponse) {
          const w = item.warrantyOptions.find((o) => o.code === ch?.selectedWarrantyCode) || item.warrantyOptions[0];
          totalAmount += Number(item.baseCost || 0) + Number(w?.fee || 0);
        } else {
          totalAmount += Number(item.finalAmount || 0);
        }
      } else {
        pendingCount++;
      }
    }
    return { approvedCount, rejectedCount, pendingCount, totalAmount };
  }, [choices, isMultiDevice, isWaitingResponse, quotation.items]);

  const submitDecisions = async (
    itemsPayload: {
      quotationItemId: string;
      decision: QuotationItemDecision;
      selectedWarrantyCode?: string;
      rejectReason?: string;
    }[]
  ) => {
    setErrorMsg(null);
    setSubmitting(true);
    const res = await respondToCustomerQuotation(quotation.id, { items: itemsPayload });
    setSubmitting(false);

    if (res.success && res.data) {
      onUpdated(res.data);
      if (res.data.approvedItemCount > 0) {
        setStep('PAYMENT');
      } else {
        onClose();
      }
    } else {
      setErrorMsg(res.message || 'Không thể gửi xác nhận báo giá');
    }
  };

  const handleSingleApprove = () => {
    if (!activeItem) return;
    const ch = choices[activeItem.id];
    void submitDecisions([
      {
        quotationItemId: activeItem.id,
        decision: 'APPROVED',
        selectedWarrantyCode: ch?.selectedWarrantyCode,
      },
    ]);
  };

  const handleSingleReject = () => {
    if (!activeItem) return;
    const reason = window.prompt('Nhập lý do từ chối (tùy chọn):') || undefined;
    void submitDecisions([
      {
        quotationItemId: activeItem.id,
        decision: 'REJECTED',
        rejectReason: reason,
      },
    ]);
  };

  const handleMultiSubmit = () => {
    const undecidedIndex = quotation.items.findIndex(
      (i) => !choices[i.id] || choices[i.id].decision === 'PENDING'
    );
    if (undecidedIndex >= 0) {
      setActiveIndex(undecidedIndex);
      setErrorMsg(
        `Vui lòng chọn "Đồng ý sửa" hoặc "Từ chối" cho thiết bị ${quotation.items[undecidedIndex].deviceName} (${quotation.items[undecidedIndex].orderCode}).`
      );
      return;
    }

    const payload = quotation.items.map((item) => {
      const ch = choices[item.id];
      return {
        quotationItemId: item.id,
        decision: ch.decision,
        selectedWarrantyCode: ch.decision === 'APPROVED' ? ch.selectedWarrantyCode : undefined,
        rejectReason: ch.decision === 'REJECTED' ? ch.rejectReason.trim() || undefined : undefined,
      };
    });
    void submitDecisions(payload);
  };

  const handleUploadPaymentProof = async () => {
    if (!selectedFile) {
      setErrorMsg('Vui lòng chọn ảnh hoặc file PDF chứng từ thanh toán');
      return;
    }
    setErrorMsg(null);
    setUploadingProof(true);
    const res = await submitCustomerPaymentProof(
      quotation.id,
      selectedFile,
      quotation.totalApprovedAmount
    );
    setUploadingProof(false);

    if (res.success && res.data) {
      setSelectedFile(null);
      const nextQuotation: QuotationResponse = {
        ...quotation,
        paymentProofs: [res.data, ...(quotation.paymentProofs || [])],
      };
      onUpdated(nextQuotation);
    } else {
      setErrorMsg(res.message || 'Không thể tải lên chứng từ');
    }
  };

  if (!activeItem) return null;
  const activeChoice = choices[activeItem.id];
  const activeWarrantyCode = isWaitingResponse
    ? activeChoice?.selectedWarrantyCode
    : activeItem.selectedWarrantyCode || activeItem.warrantyOptions[0]?.code;
  const activeSelectedWarranty =
    activeItem.warrantyOptions.find((w) => w.code === activeWarrantyCode) ||
    activeItem.warrantyOptions[0];

  return (
    <div className="cq-overlay" onClick={onClose}>
      <div className="cq-modal" onClick={(e) => e.stopPropagation()}>
        <div className="cq-handle" />

        <header className="cq-header">
          <div className="cq-header-left">
            <div className="cq-header-icon">
              {step === 'PAYMENT' ? <CreditCard size={18} /> : <FileText size={18} />}
            </div>
            <div style={{ minWidth: 0 }}>
              <h2 className="cq-title">
                {step === 'PAYMENT'
                  ? 'Xác nhận & Thanh toán đơn hàng'
                  : 'Báo giá & Xác nhận dịch vụ'}
              </h2>
              <p className="cq-subtitle">
                {step === 'PAYMENT'
                  ? 'Chuyển khoản thanh toán và tải lên biên lai (tùy chọn)'
                  : `Mã báo giá: ${quotation.quoteCode}${isMultiDevice ? ` · ${quotation.itemCount} thiết bị` : ''}`}
              </p>
            </div>
          </div>
          <button type="button" className="cq-close-btn" onClick={onClose} aria-label="Đóng">
            <X size={16} />
          </button>
        </header>

        {step === 'REVIEW' && isMultiDevice && (
          <div className="cq-pill-tabs">
            {quotation.items.map((item, idx) => {
              const dec = isWaitingResponse ? choices[item.id]?.decision || 'PENDING' : item.decision;
              const badgeCls =
                dec === 'APPROVED' ? 'approved' : dec === 'REJECTED' ? 'rejected' : 'pending';
              const badgeText = dec === 'APPROVED' ? '✓ Sửa' : dec === 'REJECTED' ? '✕ Từ chối' : 'Chờ chọn';
              return (
                <button
                  key={item.id}
                  type="button"
                  className={`cq-pill-tab ${idx === activeIndex ? 'active' : ''}`}
                  onClick={() => setActiveIndex(idx)}
                >
                  <span>
                    {idx + 1}. {item.deviceName}
                  </span>
                  <span className={`cq-pill-badge ${badgeCls}`}>{badgeText}</span>
                </button>
              );
            })}
          </div>
        )}

        <main className="cq-body">
          {errorMsg && (
            <div
              style={{
                padding: '9px 12px',
                borderRadius: 10,
                background: '#fee2e2',
                color: '#b91c1c',
                fontSize: '0.78rem',
                fontWeight: 600,
              }}
            >
              {errorMsg}
            </div>
          )}

          {step === 'REVIEW' ? (
            <>
              {/* Device summary */}
              <article className="cq-device-card">
                <div className="cq-device-top">
                  <div className="cq-device-main">
                    <div className="cq-device-icon">
                      <Cpu size={19} />
                    </div>
                    <div style={{ minWidth: 0, flex: 1 }}>
                      <h3 className="cq-device-name">
                        {activeItem.deviceName} ({quotation.customerName})
                      </h3>
                      <span className="cq-order-chip">Mã đơn: {activeItem.orderCode}</span>
                    </div>
                  </div>
                  <span className="cq-status-chip">
                    {isWaitingResponse ? 'Chờ khách duyệt' : activeItem.decisionLabel}
                  </span>
                </div>

                {activeItem.serialNumber && (
                  <div className="cq-sn-row">
                    <span>Số Sê-ri (S/N):</span>
                    <div className="cq-sn-box">
                      <span>{activeItem.serialNumber}</span>
                      <button
                        type="button"
                        className="cq-copy-btn"
                        onClick={() => handleCopy(`sn-${activeItem.id}`, activeItem.serialNumber || '')}
                        title="Sao chép S/N"
                      >
                        {copiedKey === `sn-${activeItem.id}` ? <Check size={13} /> : <Copy size={13} />}
                      </button>
                    </div>
                  </div>
                )}
              </article>

              {/* Faults & Cost breakdown */}
              <article className="cq-section-card">
                {activeItem.diagnosedErrors && activeItem.diagnosedErrors.length > 0 && (
                  <>
                    <div className="cq-section-label">
                      <AlertTriangle size={13} color="#ef4444" />
                      Lỗi kỹ thuật chẩn đoán
                    </div>
                    <div className="cq-fault-pills">
                      {activeItem.diagnosedErrors.map((err, i) => (
                        <span
                          key={i}
                          className={`cq-fault-pill ${err.severity === 'MEDIUM' ? 'medium' : ''}`}
                        >
                          {err.label}
                        </span>
                      ))}
                    </div>
                  </>
                )}

                <div className="cq-price-box">
                  {activeItem.lineItems.map((line) => (
                    <div key={line.id} className="cq-price-row">
                      <span>
                        {line.description}
                        {line.quantity > 1 ? ` (x${line.quantity})` : ''}
                      </span>
                      <strong>{formatVnd(line.amount)}</strong>
                    </div>
                  ))}
                  <div className="cq-price-subtotal">
                    <span>Chi phí dự kiến:</span>
                    <span>{formatVnd(activeItem.baseCost)}</span>
                  </div>
                </div>
              </article>

              {/* Warranty selector */}
              {activeItem.warrantyOptions && activeItem.warrantyOptions.length > 0 && (
                <div>
                  <div className="cq-section-label">Chọn gói thời hạn bảo hành:</div>
                  <div className="cq-warranty-grid">
                    {activeItem.warrantyOptions.map((opt) => {
                      const selected = opt.code === activeWarrantyCode;
                      return (
                        <button
                          key={opt.code}
                          type="button"
                          disabled={!isWaitingResponse}
                          className={`cq-warranty-card ${selected ? 'selected' : ''}`}
                          onClick={() =>
                            updateChoice(activeItem.id, { selectedWarrantyCode: opt.code })
                          }
                        >
                          <div>
                            <div className="cq-warranty-top">
                              <span className="cq-warranty-title">{opt.label}</span>
                              <span className="cq-radio-dot">
                                {selected && <span className="cq-radio-dot-inner" />}
                              </span>
                            </div>
                            <div className="cq-warranty-desc">{opt.description || 'Gói bảo hành'}</div>
                          </div>
                          <span className="cq-warranty-fee">
                            {Number(opt.fee) === 0 ? 'Đã bao gồm' : `+${formatVnd(opt.fee)}`}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* Independent decision buttons when multi-device */}
              {isMultiDevice && isWaitingResponse && (
                <div className="cq-section-card" style={{ padding: 12 }}>
                  <div className="cq-section-label">Quyết định cho thiết bị này:</div>
                  <div className="cq-item-decision-row">
                    <button
                      type="button"
                      className={`cq-decision-btn approve ${
                        activeChoice?.decision === 'APPROVED' ? 'active' : ''
                      }`}
                      onClick={() => updateChoice(activeItem.id, { decision: 'APPROVED' })}
                    >
                      <CheckCircle2 size={15} />
                      Đồng ý sửa máy này
                    </button>
                    <button
                      type="button"
                      className={`cq-decision-btn reject ${
                        activeChoice?.decision === 'REJECTED' ? 'active' : ''
                      }`}
                      onClick={() => updateChoice(activeItem.id, { decision: 'REJECTED' })}
                    >
                      <XCircle size={15} />
                      Từ chối máy này
                    </button>
                  </div>
                  {activeChoice?.decision === 'REJECTED' && (
                    <input
                      type="text"
                      placeholder="Nhập lý do từ chối (tùy chọn)..."
                      value={activeChoice.rejectReason}
                      onChange={(e) =>
                        updateChoice(activeItem.id, { rejectReason: e.target.value })
                      }
                      style={{
                        width: '100%',
                        marginTop: 8,
                        padding: '8px 10px',
                        borderRadius: 8,
                        border: '1px solid #cbd5e1',
                        fontSize: '0.78rem',
                      }}
                    />
                  )}
                </div>
              )}

              {/* Total bar */}
              <div className="cq-total-banner">
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: '0.68rem', opacity: 0.85, fontWeight: 600 }}>
                    TỔNG THANH TOÁN BÁO GIÁ
                  </div>
                  <div style={{ fontSize: '0.74rem', opacity: 0.9 }}>
                    {isMultiDevice
                      ? `Đã chọn ${summary.approvedCount}/${quotation.itemCount} thiết bị`
                      : activeSelectedWarranty?.label || 'Gói bảo hành tiêu chuẩn'}
                  </div>
                </div>
                <div className="cq-total-amount">{formatVnd(summary.totalAmount)}</div>
              </div>
            </>
          ) : (
            /* STEP 2: PAYMENT & UPLOAD PROOF */
            <>
              <div className="cq-total-banner" style={{ alignItems: 'flex-start' }}>
                <div style={{ minWidth: 0 }}>
                  <span
                    style={{
                      display: 'inline-block',
                      fontSize: '0.66rem',
                      fontWeight: 700,
                      padding: '2px 8px',
                      borderRadius: 999,
                      background: 'rgba(255,255,255,0.2)',
                      marginBottom: 4,
                    }}
                  >
                    {quotation.statusLabel}
                  </span>
                  <div style={{ fontSize: '0.82rem', fontWeight: 700 }}>
                    {quotation.quoteCode} · {quotation.approvedItemCount}/{quotation.itemCount} thiết bị đã duyệt
                  </div>
                  <div style={{ fontSize: '0.72rem', opacity: 0.85, marginTop: 2 }}>
                    {quotation.items
                      .filter((i) => i.decision === 'APPROVED')
                      .map((i) => i.orderCode)
                      .join(', ')}
                  </div>
                </div>
                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div style={{ fontSize: '0.65rem', opacity: 0.85 }}>SỐ TIỀN THANH TOÁN</div>
                  <div className="cq-total-amount">{formatVnd(quotation.totalApprovedAmount)}</div>
                </div>
              </div>

              {quotation.bankInfo && (
                <article className="cq-section-card">
                  <div className="cq-section-label" style={{ justifyContent: 'space-between' }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                      <QrCode size={14} color="#25437a" />
                      Mã QR & Chuyển khoản ngân hàng
                    </span>
                    <span style={{ color: '#25437a' }}>Napas247</span>
                  </div>

                  <div className="cq-qr-row">
                    <div className="cq-qr-frame">
                      {qrDataUrl ? (
                        <img src={qrDataUrl} alt="VietQR" style={{ width: 120, height: 120 }} />
                      ) : (
                        <div style={{ width: 120, height: 120, display: 'grid', placeItems: 'center', fontSize: '0.72rem', color: '#64748b' }}>
                          VietQR
                        </div>
                      )}
                      <div style={{ fontSize: '0.65rem', fontWeight: 700, color: '#25437a', marginTop: 4 }}>
                        Quét mã VietQR 24/7
                      </div>
                    </div>

                    <div style={{ flex: 1, minWidth: 180, display: 'flex', flexDirection: 'column', gap: 7, fontSize: '0.76rem' }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 6 }}>
                        <span style={{ color: '#64748b' }}>Ngân hàng:</span>
                        <strong>{quotation.bankInfo.bankName}</strong>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 6 }}>
                        <span style={{ color: '#64748b' }}>Số tài khoản:</span>
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                          <strong style={{ color: '#25437a', fontFamily: 'monospace', fontSize: '0.84rem' }}>
                            {quotation.bankInfo.bankAccountNumber}
                          </strong>
                          <button
                            type="button"
                            className="cq-copy-btn"
                            onClick={() => handleCopy('stk', quotation.bankInfo?.bankAccountNumber || '')}
                          >
                            {copiedKey === 'stk' ? <Check size={13} /> : <Copy size={13} />}
                          </button>
                        </span>
                      </div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 6 }}>
                        <span style={{ color: '#64748b' }}>Chủ TK:</span>
                        <strong style={{ textAlign: 'right', fontSize: '0.72rem' }}>
                          {quotation.bankInfo.bankAccountHolder}
                        </strong>
                      </div>
                      <div>
                        <div style={{ fontSize: '0.7rem', color: '#64748b', marginBottom: 3 }}>
                          Nội dung chuyển khoản (Bắt buộc chính xác):
                        </div>
                        <div
                          style={{
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center',
                            background: '#fffbeb',
                            border: '1px solid #fde68a',
                            borderRadius: 8,
                            padding: '6px 10px',
                            fontFamily: 'monospace',
                            fontWeight: 700,
                            color: '#78350f',
                          }}
                        >
                          <span>{quotation.bankInfo.transferContent}</span>
                          <button
                            type="button"
                            className="cq-copy-btn"
                            onClick={() => handleCopy('ndck', quotation.bankInfo?.transferContent || '')}
                          >
                            {copiedKey === 'ndck' ? <Check size={13} /> : <Copy size={13} />}
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </article>
              )}

              <article className="cq-section-card">
                <div className="cq-section-label" style={{ justifyContent: 'space-between' }}>
                  <span>Tải lên ảnh chứng từ thanh toán</span>
                  <span style={{ color: '#64748b', textTransform: 'none' }}>Tùy chọn (có thể gửi sau)</span>
                </div>

                <div className="cq-upload-zone">
                  <UploadCloud size={26} color="#25437a" style={{ margin: '0 auto 6px' }} />
                  <div style={{ fontSize: '0.78rem', fontWeight: 700, color: '#0f172a' }}>
                    Tải lên ảnh chụp màn hình / biên lai chuyển khoản
                  </div>
                  <div style={{ fontSize: '0.7rem', color: '#64748b', marginTop: 2 }}>
                    Hỗ trợ JPG, PNG, PDF (tối đa 10MB)
                  </div>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*,.pdf"
                    style={{ display: 'none' }}
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      if (f) setSelectedFile(f);
                    }}
                  />
                  <button
                    type="button"
                    className="quotation-btn-sm"
                    style={{ marginTop: 10 }}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    Chọn tệp chứng từ
                  </button>
                </div>

                {selectedFile && (
                  <div
                    style={{
                      marginTop: 10,
                      padding: '8px 10px',
                      borderRadius: 10,
                      background: '#f8fafc',
                      border: '1px solid #e2e8f0',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      fontSize: '0.76rem',
                    }}
                  >
                    <span style={{ fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {selectedFile.name}
                    </span>
                    <button
                      type="button"
                      className="cq-copy-btn"
                      onClick={() => setSelectedFile(null)}
                    >
                      <Trash2 size={14} color="#dc2626" />
                    </button>
                  </div>
                )}

                {quotation.paymentProofs && quotation.paymentProofs.length > 0 && (
                  <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
                    <div style={{ fontSize: '0.74rem', fontWeight: 700, color: '#334155' }}>
                      Chứng từ đã gửi:
                    </div>
                    {quotation.paymentProofs.map((proof) => (
                      <div
                        key={proof.id}
                        style={{
                          padding: '8px 10px',
                          borderRadius: 8,
                          background: '#f8fafc',
                          border: '1px solid #e2e8f0',
                          fontSize: '0.75rem',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                        }}
                      >
                        <span>
                          {proof.proofFileName || 'Chứng từ'} · <strong>{formatVnd(proof.amount)}</strong>
                        </span>
                        <span
                          className={`cq-pill-badge ${
                            proof.status === 'VERIFIED'
                              ? 'approved'
                              : proof.status === 'REJECTED'
                              ? 'rejected'
                              : 'pending'
                          }`}
                        >
                          {proof.statusLabel}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </article>
            </>
          )}
        </main>

        <footer className="cq-footer">
          {step === 'REVIEW' ? (
            isWaitingResponse ? (
              isMultiDevice ? (
                <div className="cq-footer-actions">
                  <button
                    type="button"
                    className="cq-btn-reject"
                    disabled={submitting}
                    onClick={onClose}
                  >
                    Để sau
                  </button>
                  <button
                    type="button"
                    className="cq-btn-primary"
                    disabled={submitting}
                    onClick={handleMultiSubmit}
                  >
                    <Check size={16} />
                    {submitting
                      ? 'Đang gửi...'
                      : `Xác nhận phương án (${summary.approvedCount}/${quotation.itemCount} máy)`}
                  </button>
                </div>
              ) : (
                <div className="cq-footer-actions">
                  <button
                    type="button"
                    className="cq-btn-reject"
                    disabled={submitting}
                    onClick={handleSingleReject}
                  >
                    <X size={15} />
                    Từ chối
                  </button>
                  <button
                    type="button"
                    className="cq-btn-primary"
                    disabled={submitting}
                    onClick={handleSingleApprove}
                  >
                    <Check size={16} />
                    {submitting ? 'Đang xử lý...' : 'Đồng ý & Bắt đầu sửa'}
                  </button>
                </div>
              )
            ) : (
              <div className="cq-footer-actions">
                <button type="button" className="cq-btn-back" onClick={onClose}>
                  Đóng
                </button>
                {canPayNow ? (
                  <button
                    type="button"
                    className="cq-btn-primary"
                    onClick={() => setStep('PAYMENT')}
                  >
                    <CreditCard size={16} />
                    Thanh toán & Chứng từ
                  </button>
                ) : (
                  <button type="button" className="cq-btn-primary" onClick={onClose}>
                    Đã hiểu
                  </button>
                )}
              </div>
            )
          ) : (
            <div className="cq-footer-actions">
              <button
                type="button"
                className="cq-btn-back"
                disabled={uploadingProof}
                onClick={() => setStep('REVIEW')}
              >
                <ArrowLeft size={15} />
                Xem báo giá
              </button>
              {selectedFile ? (
                <button
                  type="button"
                  className="cq-btn-primary"
                  disabled={uploadingProof}
                  onClick={handleUploadPaymentProof}
                >
                  <Check size={16} />
                  {uploadingProof ? 'Đang tải lên...' : 'Gửi chứng từ xác nhận'}
                </button>
              ) : (
                <button type="button" className="cq-btn-primary" onClick={onClose}>
                  Thanh toán sau / Đóng
                </button>
              )}
            </div>
          )}

          <div className="cq-hotline">
            <Phone size={12} style={{ display: 'inline', marginRight: 4, verticalAlign: '-2px' }} />
            Cần trao đổi thêm? Hotline Kỹ thuật:{' '}
            <a href={`tel:${hotlineNumber.replace(/\s+/g, '')}`}>{hotlineNumber}</a>
          </div>
        </footer>
      </div>
    </div>
  );
};


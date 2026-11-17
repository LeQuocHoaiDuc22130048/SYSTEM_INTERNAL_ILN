import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { FileText, Layers, Search, ShieldCheck, Trash2, X } from 'lucide-react';
import type { Customer } from '../../types/customer';
import type {
  CreateQuotationItemRequest,
  DiagnosedErrorDto,
  PendingQuotationOrderResponse,
  QuotationResponse,
  WarrantyOptionDto,
} from '../../types/quotation';
import { getCustomers } from '../../utils/customerApi';
import { createRepairQuotation, getPendingQuotationOrders } from '../../utils/quotationApi';
import { formatVnd } from '../../utils/quotationHelpers';

export interface PinnedQuotationOrder {
  id: string;
  orderCode: string;
  deviceName: string;
  serialNumber?: string | null;
}

interface DraftItemForm {
  repairOrderId: string;
  orderCode: string;
  deviceName: string;
  serialNumber?: string | null;
  diagnosedErrors: DiagnosedErrorDto[];
  customErrorInput: string;
  lineItems: { description: string; quantity: number; unitPrice: number }[];
  enableExtendedWarranty: boolean;
  extendedWarrantyFee: number;
}

const PRESET_ERRORS: DiagnosedErrorDto[] = [
  { label: 'Hỏng công suất vào/ra', severity: 'HIGH' },
  { label: 'Cháy relay đóng ngắt', severity: 'MEDIUM' },
  { label: 'Hư hỏng board AC, DC', severity: 'HIGH' },
  { label: 'Lỗi mạch kích IGBT / Driver', severity: 'HIGH' },
  { label: 'Lỗi nguồn xung / Điều khiển DSP', severity: 'MEDIUM' },
];

function makeDefaultDraft(
  id: string,
  code: string,
  devName: string,
  sn?: string | null
): DraftItemForm {
  return {
    repairOrderId: id,
    orderCode: code,
    deviceName: devName,
    serialNumber: sn,
    diagnosedErrors: [],
    customErrorInput: '',
    lineItems: [
      { description: 'Kiểm tra, sửa chữa phần cứng & linh kiện', quantity: 1, unitPrice: 0 },
      { description: 'Công kỹ thuật & Kiểm tra tải xưởng', quantity: 1, unitPrice: 500000 },
    ],
    enableExtendedWarranty: true,
    extendedWarrantyFee: 500000,
  };
}

interface CreateQuotationModalProps {
  isOpen: boolean;
  onClose: () => void;
  onCreated: (quotation: QuotationResponse, sendImmediately: boolean) => void;
  initialCustomerId?: string | null;
  initialCustomerName?: string | null;
  pinnedOrder?: PinnedQuotationOrder;
}

export const CreateQuotationModal: React.FC<CreateQuotationModalProps> = ({
  isOpen,
  onClose,
  onCreated,
  initialCustomerId,
  initialCustomerName,
  pinnedOrder,
}) => {
  const [customerId, setCustomerId] = useState<string>(initialCustomerId || '');
  const [customerName, setCustomerName] = useState<string>(initialCustomerName || '');
  const [customerSearch, setCustomerSearch] = useState('');
  const [customerOptions, setCustomerOptions] = useState<Customer[]>([]);
  const [searchingCustomers, setSearchingCustomers] = useState(false);

  const [pendingOrders, setPendingOrders] = useState<PendingQuotationOrderResponse[]>([]);
  const [loadingPendingOrders, setLoadingPendingOrders] = useState(false);
  const [selectedOrderIds, setSelectedOrderIds] = useState<string[]>([]);
  const [draftForms, setDraftForms] = useState<Record<string, DraftItemForm>>({});
  const [activeDeviceTabId, setActiveDeviceTabId] = useState<string>('');
  const [quoteTitle, setQuoteTitle] = useState('');
  const [quoteNote, setQuoteNote] = useState('');
  const [sendImmediately, setSendImmediately] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  const loadPendingOrdersForCustomer = useCallback(
    async (targetCustomerId: string, pinned?: PinnedQuotationOrder) => {
      setLoadingPendingOrders(true);
      const res = await getPendingQuotationOrders(targetCustomerId);
      setLoadingPendingOrders(false);
      if (res.success && res.data) {
        setPendingOrders(res.data);
        if (!pinned && res.data.length > 0) {
          const first = res.data[0];
          setSelectedOrderIds([first.id]);
          setDraftForms({
            [first.id]: makeDefaultDraft(first.id, first.orderCode, first.deviceName, first.serialNumber),
          });
          setActiveDeviceTabId(first.id);
        }
      } else {
        setPendingOrders([]);
      }
    },
    []
  );

  // Reset form state each time the modal opens
  useEffect(() => {
    if (!isOpen) return;
    setFormError('');
    setQuoteTitle('');
    setQuoteNote('');
    setSendImmediately(true);
    setCustomerSearch('');
    setCustomerId(initialCustomerId || '');
    setCustomerName(initialCustomerName || '');

    if (pinnedOrder) {
      const initialForm = makeDefaultDraft(
        pinnedOrder.id,
        pinnedOrder.orderCode,
        pinnedOrder.deviceName,
        pinnedOrder.serialNumber
      );
      setSelectedOrderIds([pinnedOrder.id]);
      setDraftForms({ [pinnedOrder.id]: initialForm });
      setActiveDeviceTabId(pinnedOrder.id);
      if (initialCustomerId) {
        void loadPendingOrdersForCustomer(initialCustomerId, pinnedOrder);
      }
    } else {
      setSelectedOrderIds([]);
      setDraftForms({});
      setActiveDeviceTabId('');
      setPendingOrders([]);
      if (initialCustomerId) {
        void loadPendingOrdersForCustomer(initialCustomerId);
      }
    }
  }, [isOpen, initialCustomerId, initialCustomerName, pinnedOrder, loadPendingOrdersForCustomer]);

  // Search customers when in standalone picker mode
  useEffect(() => {
    if (!isOpen || pinnedOrder || customerId) return;
    let cancelled = false;
    const timer = window.setTimeout(async () => {
      setSearchingCustomers(true);
      const res = await getCustomers({ keyword: customerSearch, active: true, page: 0, size: 15 });
      if (!cancelled) {
        setSearchingCustomers(false);
        setCustomerOptions(res.success && res.data ? res.data.content : []);
      }
    }, 200);
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [isOpen, pinnedOrder, customerId, customerSearch]);

  const handleSelectCustomer = (customer: Customer) => {
    setCustomerId(customer.id);
    setCustomerName(customer.customerName);
    setSelectedOrderIds([]);
    setDraftForms({});
    setActiveDeviceTabId('');
    void loadPendingOrdersForCustomer(customer.id);
  };

  const handleToggleOrder = (ord: PendingQuotationOrderResponse) => {
    if (pinnedOrder && ord.id === pinnedOrder.id) return;
    setSelectedOrderIds((prev) => {
      if (prev.includes(ord.id)) {
        const next = prev.filter((id) => id !== ord.id);
        if (activeDeviceTabId === ord.id) {
          setActiveDeviceTabId(pinnedOrder?.id || next[0] || '');
        }
        return next;
      }
      setDraftForms((forms) => ({
        ...forms,
        [ord.id]: forms[ord.id] || makeDefaultDraft(ord.id, ord.orderCode, ord.deviceName, ord.serialNumber),
      }));
      if (!activeDeviceTabId) {
        setActiveDeviceTabId(ord.id);
      }
      return [...prev, ord.id];
    });
  };

  const updateActiveDraft = (updater: (draft: DraftItemForm) => DraftItemForm) => {
    setDraftForms((prev) => {
      const current = prev[activeDeviceTabId];
      if (!current) return prev;
      return { ...prev, [activeDeviceTabId]: updater(current) };
    });
  };

  const handleTogglePresetError = (err: DiagnosedErrorDto) => {
    updateActiveDraft((draft) => {
      const exists = draft.diagnosedErrors.some((e) => e.label === err.label);
      return {
        ...draft,
        diagnosedErrors: exists
          ? draft.diagnosedErrors.filter((e) => e.label !== err.label)
          : [...draft.diagnosedErrors, err],
      };
    });
  };

  const handleAddCustomError = () => {
    const active = draftForms[activeDeviceTabId];
    if (!active || !active.customErrorInput.trim()) return;
    const label = active.customErrorInput.trim();
    updateActiveDraft((draft) => ({
      ...draft,
      customErrorInput: '',
      diagnosedErrors: draft.diagnosedErrors.some((e) => e.label === label)
        ? draft.diagnosedErrors
        : [...draft.diagnosedErrors, { label, severity: 'MEDIUM' }],
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError('');

    if (!customerId) {
      setFormError('Vui lòng chọn khách hàng để tạo báo giá.');
      return;
    }
    if (selectedOrderIds.length === 0) {
      setFormError('Vui lòng chọn ít nhất 1 đơn sửa chữa để đưa vào báo giá.');
      return;
    }

    const itemPayloads: CreateQuotationItemRequest[] = [];
    for (const id of selectedOrderIds) {
      const draft = draftForms[id];
      if (!draft) continue;
      const validLines = draft.lineItems.filter((l) => l.description.trim() && l.quantity > 0);
      if (validLines.length === 0) {
        setFormError(`Thiết bị ${draft.deviceName} (${draft.orderCode}) cần ít nhất 1 hạng mục chi phí.`);
        setActiveDeviceTabId(id);
        return;
      }

      const warrantyOptions: WarrantyOptionDto[] = [
        {
          code: 'STANDARD_6M',
          label: 'Bảo hành 6 tháng',
          description: 'Gói tiêu chuẩn',
          months: 6,
          fee: 0,
        },
      ];
      if (draft.enableExtendedWarranty) {
        warrantyOptions.push({
          code: 'EXTENDED_12M',
          label: 'Bảo hành 1 năm',
          description: 'Bảo vệ toàn diện linh kiện',
          months: 12,
          fee: Math.max(0, Number(draft.extendedWarrantyFee) || 0),
        });
      }

      itemPayloads.push({
        repairOrderId: draft.repairOrderId,
        diagnosedErrors: draft.diagnosedErrors,
        lineItems: validLines.map((l) => ({
          description: l.description.trim(),
          quantity: Number(l.quantity) || 1,
          unitPrice: Math.max(0, Number(l.unitPrice) || 0),
        })),
        warrantyOptions,
      });
    }

    setSubmitting(true);
    const res = await createRepairQuotation({
      customerId,
      title: quoteTitle.trim() || undefined,
      note: quoteNote.trim() || undefined,
      sendImmediately,
      items: itemPayloads,
    });
    setSubmitting(false);

    if (res.success && res.data) {
      onCreated(res.data, sendImmediately);
    } else {
      setFormError(res.message || 'Không thể tạo báo giá');
    }
  };

  const activeDraft = draftForms[activeDeviceTabId];
  const mergeableOrders = useMemo(
    () => (pinnedOrder ? pendingOrders.filter((o) => o.id !== pinnedOrder.id) : pendingOrders),
    [pendingOrders, pinnedOrder]
  );

  const grandEstimated = selectedOrderIds.reduce((sum, id) => {
    const d = draftForms[id];
    if (!d) return sum;
    return (
      sum +
      d.lineItems.reduce(
        (s, l) => s + (Number(l.quantity) || 0) * (Number(l.unitPrice) || 0),
        0
      )
    );
  }, 0);

  if (!isOpen) return null;

  return (
    <div className="orders-modal-overlay">
      <div className="orders-modal-card quotation-modal-wide">
        <div className="modal-header">
          <h3>
            <FileText size={18} />
            Tạo báo giá sửa chữa {customerName ? `— ${customerName}` : ''}
          </h3>
          <button
            type="button"
            className="close-modal-btn"
            onClick={() => !submitting && onClose()}
          >
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="modal-form">
          <div className="quotation-modal-scroll">
            {formError && (
              <div
                style={{
                  padding: '8px 12px',
                  background: '#fee2e2',
                  color: '#dc2626',
                  borderRadius: 8,
                  fontSize: '0.82rem',
                  marginBottom: 12,
                }}
              >
                {formError}
              </div>
            )}

            {/* Chọn khách hàng khi mở từ trang Quản lý báo giá tập trung */}
            {!pinnedOrder && (
              <div className="quotation-customer-picker">
                {customerId ? (
                  <div className="quotation-selected-customer">
                    <div>
                      <span className="quotation-picker-label">Khách hàng đã chọn:</span>{' '}
                      <strong>{customerName}</strong>
                    </div>
                    <button
                      type="button"
                      className="quotation-btn-sm"
                      onClick={() => {
                        setCustomerId('');
                        setCustomerName('');
                        setPendingOrders([]);
                        setSelectedOrderIds([]);
                        setDraftForms({});
                        setActiveDeviceTabId('');
                      }}
                    >
                      Đổi khách hàng
                    </button>
                  </div>
                ) : (
                  <div className="form-group" style={{ marginBottom: 12 }}>
                    <label>Chọn khách hàng cần lập báo giá *</label>
                    <div className="quotation-customer-search">
                      <Search size={15} />
                      <input
                        type="text"
                        placeholder="Tìm tên khách hàng, mã KH, số điện thoại..."
                        value={customerSearch}
                        onChange={(e) => setCustomerSearch(e.target.value)}
                      />
                    </div>
                    <div className="quotation-customer-list">
                      {searchingCustomers ? (
                        <div className="quotation-picker-empty">Đang tìm khách hàng...</div>
                      ) : customerOptions.length === 0 ? (
                        <div className="quotation-picker-empty">Không tìm thấy khách hàng phù hợp</div>
                      ) : (
                        customerOptions.map((c) => (
                          <button
                            key={c.id}
                            type="button"
                            className="quotation-customer-option"
                            onClick={() => handleSelectCustomer(c)}
                          >
                            <div>
                              <strong>{c.customerName}</strong>
                              <span className="quotation-customer-code">{c.customerCode}</span>
                            </div>
                            <span>{c.phone || c.email || '—'}</span>
                          </button>
                        ))
                      )}
                    </div>
                  </div>
                )}
              </div>
            )}

            {customerId && loadingPendingOrders && (
              <div className="quotation-picker-empty">Đang tải danh sách đơn chờ báo giá...</div>
            )}

            {customerId && !loadingPendingOrders && !pinnedOrder && mergeableOrders.length === 0 && (
              <div className="quotation-picker-empty">
                Khách hàng này hiện không có đơn sửa chữa ở trạng thái chờ/đã kiểm tra chưa lập báo giá.
              </div>
            )}

            {mergeableOrders.length > 0 && (
              <div className="quotation-merge-box">
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.82rem', fontWeight: 700, color: '#1e3a8a' }}>
                  <Layers size={15} />
                  {pinnedOrder
                    ? `Khách hàng này đang có ${mergeableOrders.length} máy khác chưa lập báo giá — Tick để gộp chung:`
                    : `Chọn các đơn sửa chữa (${mergeableOrders.length} máy chờ báo giá) để gộp vào phiếu:`}
                </div>
                <div className="quotation-merge-list">
                  {mergeableOrders.map((ord) => {
                    const checked = selectedOrderIds.includes(ord.id);
                    return (
                      <label
                        key={ord.id}
                        className={`quotation-merge-chip ${checked ? 'selected' : ''}`}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() => handleToggleOrder(ord)}
                        />
                        <span>
                          <strong>{ord.orderCode}</strong> · {ord.deviceName} ({ord.statusLabel})
                        </span>
                      </label>
                    );
                  })}
                </div>
              </div>
            )}

            {selectedOrderIds.length > 1 && (
              <div className="quotation-device-tabs">
                {selectedOrderIds.map((id, index) => {
                  const d = draftForms[id];
                  if (!d) return null;
                  return (
                    <button
                      key={id}
                      type="button"
                      className={`quotation-device-tab ${activeDeviceTabId === id ? 'active' : ''}`}
                      onClick={() => setActiveDeviceTabId(id)}
                    >
                      {index + 1}. {d.orderCode} ({d.deviceName})
                    </button>
                  );
                })}
              </div>
            )}

            {activeDraft && (
              <div>
                <div style={{ fontSize: '0.84rem', fontWeight: 700, color: '#0f172a', marginBottom: 8 }}>
                  Thiết bị: {activeDraft.deviceName} · Mã đơn: {activeDraft.orderCode}
                  {activeDraft.serialNumber ? ` · S/N: ${activeDraft.serialNumber}` : ''}
                </div>

                <div className="form-group">
                  <label>Lỗi kỹ thuật chẩn đoán</label>
                  <div className="quotation-error-presets">
                    {PRESET_ERRORS.map((err) => {
                      const selected = activeDraft.diagnosedErrors.some((e) => e.label === err.label);
                      return (
                        <button
                          key={err.label}
                          type="button"
                          className={`quotation-preset-btn ${selected ? 'selected' : ''}`}
                          onClick={() => handleTogglePresetError(err)}
                        >
                          {selected ? '✓ ' : '+ '}
                          {err.label}
                        </button>
                      );
                    })}
                  </div>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <input
                      type="text"
                      placeholder="Thêm lỗi chẩn đoán khác..."
                      value={activeDraft.customErrorInput}
                      onChange={(e) =>
                        updateActiveDraft((d) => ({ ...d, customErrorInput: e.target.value }))
                      }
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleAddCustomError();
                        }
                      }}
                    />
                    <button type="button" className="quotation-btn-sm" onClick={handleAddCustomError}>
                      Thêm
                    </button>
                  </div>
                  {activeDraft.diagnosedErrors.length > 0 && (
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 8 }}>
                      {activeDraft.diagnosedErrors.map((err) => (
                        <span
                          key={err.label}
                          style={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 4,
                            padding: '3px 8px',
                            borderRadius: 6,
                            background: '#fee2e2',
                            color: '#991b1b',
                            fontSize: '0.75rem',
                            fontWeight: 600,
                          }}
                        >
                          {err.label}
                          <button
                            type="button"
                            style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#991b1b' }}
                            onClick={() => handleTogglePresetError(err)}
                          >
                            ×
                          </button>
                        </span>
                      ))}
                    </div>
                  )}
                </div>

                <div className="form-group" style={{ marginTop: 12 }}>
                  <label>Chi tiết hạng mục sửa chữa & chi phí *</label>
                  {activeDraft.lineItems.map((line, idx) => (
                    <div key={idx} className="quotation-line-row">
                      <input
                        type="text"
                        placeholder="VD: Thay thế Module Công suất (IGBT x2)"
                        value={line.description}
                        onChange={(e) =>
                          updateActiveDraft((d) => ({
                            ...d,
                            lineItems: d.lineItems.map((l, i) =>
                              i === idx ? { ...l, description: e.target.value } : l
                            ),
                          }))
                        }
                      />
                      <input
                        type="number"
                        min={1}
                        value={line.quantity}
                        onChange={(e) =>
                          updateActiveDraft((d) => ({
                            ...d,
                            lineItems: d.lineItems.map((l, i) =>
                              i === idx ? { ...l, quantity: Number(e.target.value) } : l
                            ),
                          }))
                        }
                      />
                      <input
                        type="number"
                        min={0}
                        step={10000}
                        placeholder="Đơn giá (đ)"
                        value={line.unitPrice}
                        onChange={(e) =>
                          updateActiveDraft((d) => ({
                            ...d,
                            lineItems: d.lineItems.map((l, i) =>
                              i === idx ? { ...l, unitPrice: Number(e.target.value) } : l
                            ),
                          }))
                        }
                      />
                      <button
                        type="button"
                        className="btn-icon-action"
                        disabled={activeDraft.lineItems.length <= 1}
                        onClick={() =>
                          updateActiveDraft((d) => ({
                            ...d,
                            lineItems: d.lineItems.filter((_, i) => i !== idx),
                          }))
                        }
                        title="Xóa dòng"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ))}
                  <button
                    type="button"
                    className="quotation-btn-sm"
                    onClick={() =>
                      updateActiveDraft((d) => ({
                        ...d,
                        lineItems: [...d.lineItems, { description: '', quantity: 1, unitPrice: 0 }],
                      }))
                    }
                  >
                    + Thêm hạng mục
                  </button>
                </div>

                <div
                  style={{
                    marginTop: 12,
                    padding: 10,
                    borderRadius: 8,
                    background: '#f8fafc',
                    border: '1px solid #e2e8f0',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    flexWrap: 'wrap',
                    gap: 10,
                  }}
                >
                  <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.8rem', fontWeight: 600 }}>
                    <ShieldCheck size={15} />
                    <input
                      type="checkbox"
                      checked={activeDraft.enableExtendedWarranty}
                      onChange={(e) =>
                        updateActiveDraft((d) => ({
                          ...d,
                          enableExtendedWarranty: e.target.checked,
                        }))
                      }
                    />
                    Cung cấp thêm gói Bảo hành 1 năm (ngoài gói 6 tháng tiêu chuẩn)
                  </label>
                  {activeDraft.enableExtendedWarranty && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '0.8rem' }}>
                      <span>Phụ phí 1 năm (đ):</span>
                      <input
                        type="number"
                        min={0}
                        step={50000}
                        style={{ width: 130 }}
                        value={activeDraft.extendedWarrantyFee}
                        onChange={(e) =>
                          updateActiveDraft((d) => ({
                            ...d,
                            extendedWarrantyFee: Number(e.target.value),
                          }))
                        }
                      />
                    </div>
                  )}
                </div>
              </div>
            )}

            {selectedOrderIds.length > 0 && (
              <>
                <div className="form-group" style={{ marginTop: 12 }}>
                  <label>Tiêu đề phiếu báo giá (tùy chọn)</label>
                  <input
                    type="text"
                    placeholder="VD: Báo giá sửa chữa cụm biến tần đợt 11/2026"
                    value={quoteTitle}
                    onChange={(e) => setQuoteTitle(e.target.value)}
                  />
                </div>

                <div className="form-group" style={{ marginTop: 10 }}>
                  <label>Ghi chú gửi khách (tùy chọn)</label>
                  <textarea
                    rows={2}
                    placeholder="VD: Giá đã bao gồm công kiểm tra tải xưởng..."
                    value={quoteNote}
                    onChange={(e) => setQuoteNote(e.target.value)}
                  />
                </div>

                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.82rem', marginTop: 8 }}>
                  <input
                    type="checkbox"
                    checked={sendImmediately}
                    onChange={(e) => setSendImmediately(e.target.checked)}
                  />
                  Gửi thông báo & mở duyệt cho khách hàng ngay sau khi tạo
                </label>
              </>
            )}
          </div>

          <div
            className="modal-actions"
            style={{
              marginTop: 14,
              paddingTop: 12,
              borderTop: '1px solid #e2e8f0',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#25437a' }}>
              Tổng dự kiến ({selectedOrderIds.length} máy): {formatVnd(grandEstimated)}
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                type="button"
                className="btn-cancel"
                disabled={submitting}
                onClick={onClose}
              >
                Đóng
              </button>
              <button
                type="submit"
                className="btn-submit"
                disabled={submitting || selectedOrderIds.length === 0}
              >
                {sendImmediately ? 'Tạo & Gửi báo giá' : 'Lưu nháp'}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};


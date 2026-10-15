import { usePermissionCheck } from '../utils/permissionContext';
import { useEffect, useState } from 'react';
import type { Customer } from '../types/customer';
import type { RepairOrder } from '../types/orders';
import { getCustomerOrderCandidates, linkRepairOrderCustomer } from '../utils/customerApi';

interface Props { customer: Customer; onClose: () => void; onLinked: () => void }

export function CustomerOrderLinkModal({ customer, onClose, onLinked }: Props) {
  const canAction = usePermissionCheck();
  const [keyword, setKeyword] = useState('');
  const [unlinkedOnly, setUnlinkedOnly] = useState(canAction('CUSTOMER_ASSIGN'));
  const [page, setPage] = useState(0);
  const [totalPages, setTotalPages] = useState(0);
  const [orders, setOrders] = useState<RepairOrder[]>([]);
  const [selected, setSelected] = useState<RepairOrder | null>(null);
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [loadError, setLoadError] = useState('');
  const [saveError, setSaveError] = useState('');
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let cancelled = false;
    const timer = setTimeout(async () => {
      const result = await getCustomerOrderCandidates(keyword, page, unlinkedOnly);
      if (cancelled) return;
      if (result.success && result.data) {
        setOrders(result.data.content);
        setTotalPages(result.data.totalPages);
        setLoadError('');
      } else {
        setOrders([]);
        setLoadError(result.message || 'Không thể tải danh sách đơn hàng');
      }
      setLoading(false);
    }, 300);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [keyword, page, unlinkedOnly, retry]);

  function resetSelection() {
    setSelected(null); setOrders([]); setLoading(true); setLoadError(''); setSaveError('');
  }

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!selected || !reason.trim() || saving || !customer.active) return;
    setSaving(true); setSaveError('');
    const result = await linkRepairOrderCustomer(selected.id, customer.id, reason);
    if (result.success) onLinked();
    else { setSaveError(result.message || 'Không thể gán đơn hàng'); setSaving(false); }
  }

  return (
    <div className="customer-modal-backdrop" style={{ zIndex: 1200 }}>
      {(canAction('CUSTOMER_ASSIGN') || canAction('CUSTOMER_TRANSFER')) && (<form className="customer-modal-card" role="dialog" aria-modal="true" aria-labelledby="link-order-title" onSubmit={submit}>
        <div className="customer-modal-header"><h3 id="link-order-title">Gán đơn đã có</h3></div>
        <div className="customer-modal-body">
          <p>Khách hàng nhận đơn: <strong>{customer.customerName}</strong> ({customer.customerCode})</p>
          <div className="form-group">
            <label htmlFor="existing-order-search">Tìm đơn hàng</label>
            <input id="existing-order-search" placeholder="Mã đơn, số seri, tên khách hoặc số điện thoại" value={keyword} disabled={saving}
              onChange={e => { resetSelection(); setPage(0); setKeyword(e.target.value); }} />
          </div>
          <label><input type="checkbox" checked={unlinkedOnly} disabled={saving}
            onChange={e => { resetSelection(); setPage(0); setUnlinkedOnly(e.target.checked); }} /> Chỉ hiện đơn chưa gán khách hàng</label>
          <p>Chỉ hiển thị đơn trong phạm vi quyền của bạn.</p>
          {loading ? <p role="status">Đang tải đơn hàng...</p> : loadError ? (
            <div role="alert">{loadError} <button type="button" onClick={() => { resetSelection(); setRetry(n => n + 1); }}>Thử lại</button></div>
          ) : orders.length === 0 ? <p>Không tìm thấy đơn phù hợp.</p> : (
            <div className="customer-order-candidates">
              {orders.map(order => (
                <label key={order.id} className="customer-order-candidate">
                  {canAction(order.customerId ? 'CUSTOMER_TRANSFER' : 'CUSTOMER_ASSIGN') && <input type="radio" name="existing-order" disabled={saving || order.customerId === customer.id}
                    checked={selected?.id === order.id} onChange={() => { setSelected(order); setSaveError(''); }} />}
                  <span><strong>{order.orderCode}</strong> · {order.deviceName}<br />
                    {order.customerName}{order.customerPhone ? ` · ${order.customerPhone}` : ''}<br />
                    <small>{order.customerId === customer.id ? 'Đã thuộc khách hàng này' : order.customerId ? 'Đã gán khách hàng — chọn để chuyển' : 'Chưa gán hồ sơ khách hàng'}</small>
                  </span>
                </label>
              ))}
            </div>
          )}
          <div className="customer-order-pagination">
            <button type="button" className="btn-page" disabled={saving || loading || page === 0} onClick={() => { resetSelection(); setPage(p => p - 1); }}>Trước</button>
            <span>Trang {page + 1} / {Math.max(1, totalPages)}</span>
            <button type="button" className="btn-page" disabled={saving || loading || page + 1 >= totalPages} onClick={() => { resetSelection(); setPage(p => p + 1); }}>Sau</button>
          </div>
          {selected && <p role="status">
            {selected.customerId && <strong>Đơn sẽ được chuyển khỏi khách hàng hiện tại. </strong>}
            Tên khách hàng trên đơn {selected.orderCode} sẽ đổi từ “{selected.customerName}” thành “{customer.customerName}”. Số điện thoại được cập nhật theo hồ sơ nhận đơn.
          </p>}
          <div className="form-group">
            <label htmlFor="existing-order-reason">Lý do gán/chuyển đơn *</label>
            <textarea id="existing-order-reason" value={reason} onChange={e => setReason(e.target.value)} required maxLength={500} disabled={saving} />
          </div>
          {saveError && <p role="alert">{saveError}</p>}
        </div>
        <div className="customer-modal-footer">
          <button type="button" className="btn-cancel" disabled={saving} onClick={onClose}>Hủy</button>
          {canAction(selected?.customerId ? 'CUSTOMER_TRANSFER' : 'CUSTOMER_ASSIGN') && (<button type="submit" className="btn-submit" disabled={saving || loading || !selected || !reason.trim() || !customer.active}>
            {saving ? 'Đang lưu...' : selected?.customerId ? 'Xác nhận chuyển đơn' : 'Xác nhận gán đơn'}
          </button>) }
        </div>
      </form>) }
    </div>
  );
}

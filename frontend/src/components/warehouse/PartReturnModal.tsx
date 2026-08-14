import React, { useState } from 'react';
import { X, ArrowDownLeft } from 'lucide-react';
import { getJsonAuthHeaders } from '../../utils/auth';
import type { PartCheckoutHistoryItem } from '../../types/warehouse';

interface PartReturnModalProps {
  isOpen: boolean;
  onClose: () => void;
  checkoutItem: PartCheckoutHistoryItem | null;
  onSuccess: () => void;
  showToast: (msg: string) => void;
}

export const PartReturnModal: React.FC<PartReturnModalProps> = ({
  isOpen,
  onClose,
  checkoutItem,
  onSuccess,
  showToast,
}) => {
  const [returnedQty, setReturnedQty] = useState<number>(1);
  const [conditionStatus, setConditionStatus] = useState<'GOOD' | 'DAMAGED' | 'REPLACED'>('GOOD');
  const [notes, setNotes] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);

  React.useEffect(() => {
    if (checkoutItem) {
      const remaining = checkoutItem.quantity - (checkoutItem.returnedQuantity || 0);
      setReturnedQty(Math.max(1, remaining));
    }
  }, [checkoutItem]);

  if (!isOpen || !checkoutItem) return null;

  const remainingQty = checkoutItem.quantity - (checkoutItem.returnedQuantity || 0);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (returnedQty <= 0) {
      showToast('Số lượng trả phải lớn hơn 0');
      return;
    }
    if (returnedQty > remainingQty) {
      showToast(`Số lượng trả vượt quá số lượng còn mượn (${remainingQty})`);
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        returnedQuantity: returnedQty,
        conditionStatus,
        notes,
      };

      const res = await fetch(`/api/v1/parts/checkouts/${checkoutItem.id}/return`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(payload),
      });

      const json = await res.json();

      if (res.ok && json.success) {
        showToast(`Đã ghi nhận trả ${returnedQty} linh kiện về kho`);
        onSuccess();
        onClose();
      } else {
        showToast(json.message || 'Trả linh kiện thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi trả linh kiện');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop">
      <div className="modal-container" style={{ maxWidth: '500px' }}>
        <div className="modal-header">
          <div className="modal-title-group">
            <ArrowDownLeft className="text-success" size={20} />
            <h3>Trả Linh Kiện Về Kho</h3>
          </div>
          <button className="modal-close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="modal-form">
          <div style={{ backgroundColor: '#f8fafc', padding: '12px 16px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '16px' }}>
            <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{checkoutItem.partName || 'Linh kiện'}</div>
            <div style={{ fontSize: '0.8rem', color: '#64748b', fontFamily: 'monospace' }}>
              IPN: {checkoutItem.partIpn} · Vị trí: {checkoutItem.locationCode}
            </div>
            <div style={{ fontSize: '0.8rem', color: '#2563eb', marginTop: '4px', fontWeight: 600 }}>
              Đã lấy: {checkoutItem.quantity} · Đã trả: {checkoutItem.returnedQuantity || 0} · Còn giữ: {remainingQty}
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">
              Số Lượng Trả Về (Tối đa: {remainingQty})
            </label>
            <input
              type="number"
              min={1}
              max={remainingQty}
              value={returnedQty}
              onChange={(e) => setReturnedQty(Math.max(1, Number(e.target.value)))}
              className="form-input"
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Tình Trạng Linh Kiện Khi Trả</label>
            <select
              value={conditionStatus}
              onChange={(e) => setConditionStatus(e.target.value as any)}
              className="form-input"
            >
              <option value="GOOD">🟢 Nguyên vẹn / Hoạt động tốt (Hoàn lại kho)</option>
              <option value="DAMAGED">🔴 Đã hỏng / Hỏa hỏng trong quá trình sửa</option>
              <option value="REPLACED">🟡 Đã thay thế cho linh kiện cũ</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label">Ghi Chú Trả Kho</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="VD: Trả lại do không dùng hết, hoặc mô tả lỗi linh kiện hỏng..."
              className="form-input"
              rows={3}
            />
          </div>

          <div className="modal-footer" style={{ marginTop: '20px' }}>
            <button type="button" className="btn-cancel" onClick={onClose}>
              Hủy
            </button>
            <button type="submit" className="btn-submit btn-primary" disabled={submitting}>
              {submitting ? 'Đang xử lý...' : 'Xác Nhận Trả Về Kho'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

import React, { useState } from 'react';
import { X, ArrowUpRight } from 'lucide-react';

import { getJsonAuthHeaders } from '../../utils/auth';
import type { Part, PartLot } from '../../types/warehouse';

interface PartCheckoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  part: Part | null;
  initialLot?: PartLot | null;
  onSuccess: () => void;
  showToast: (msg: string) => void;
}

export const PartCheckoutModal: React.FC<PartCheckoutModalProps> = ({
  isOpen,
  onClose,
  part,
  initialLot,
  onSuccess,
  showToast,
}) => {
  const [selectedLotId, setSelectedLotId] = useState<string>(initialLot?.id || '');
  const [quantity, setQuantity] = useState<number>(1);
  const [purpose, setPurpose] = useState<string>('Sửa chữa thiết bị');
  const [notes, setNotes] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);

  React.useEffect(() => {
    if (initialLot) {
      setSelectedLotId(initialLot.id);
    } else if (part && part.lots && part.lots.length > 0) {
      setSelectedLotId(part.lots[0].id);
    }
  }, [initialLot, part]);

  if (!isOpen || !part) return null;

  const availableLots = part.lots || [];
  const activeLot = availableLots.find((l) => l.id === selectedLotId) || availableLots[0];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeLot || !activeLot.storeLocationId) {
      showToast('Vui lòng chọn vị trí kho linh kiện');
      return;
    }
    if (quantity <= 0) {
      showToast('Số lượng lấy phải lớn hơn 0');
      return;
    }
    if (quantity > activeLot.amount) {
      showToast(`Số lượng tồn tại vị trí này chỉ còn ${activeLot.amount}`);
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        storeLocationId: activeLot.storeLocationId,
        partLotId: activeLot.id,
        quantity,
        purpose,
        notes,
      };

      const res = await fetch(`/api/v1/parts/${part.id}/checkout`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(payload),
      });

      const json = await res.json();

      if (res.ok && json.success) {
        showToast(`Đã lấy ${quantity} linh kiện ${part.name} ra khỏi kho`);
        onSuccess();
        onClose();
      } else {
        showToast(json.message || 'Lấy linh kiện thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi xuất linh kiện');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="modal-backdrop">
      <div className="modal-container" style={{ maxWidth: '500px' }}>
        <div className="modal-header">
          <div className="modal-title-group">
            <ArrowUpRight className="text-warning" size={20} />
            <h3>Lấy Linh Kiện Out Kho</h3>
          </div>
          <button className="modal-close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="modal-form">
          <div style={{ backgroundColor: '#f8fafc', padding: '12px 16px', borderRadius: '8px', border: '1px solid #e2e8f0', marginBottom: '16px' }}>
            <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{part.name}</div>
            <div style={{ fontSize: '0.8rem', color: '#64748b', fontFamily: 'monospace' }}>IPN: {part.ipn}</div>
          </div>

          <div className="form-group">
            <label className="form-label">Chọn Vị Trí Kho Linh Kiện</label>
            <select
              value={selectedLotId}
              onChange={(e) => setSelectedLotId(e.target.value)}
              className="form-input"
              required
            >
              {availableLots.length === 0 ? (
                <option value="">Chưa xếp vị trí kho nào</option>
              ) : (
                availableLots.map((lot) => (
                  <option key={lot.id} value={lot.id}>
                    📍 {lot.storeLocationName} ({lot.storeLocationCode}) — Tồn: {lot.amount}
                  </option>
                ))
              )}
            </select>
          </div>

          <div className="form-group">
            <label className="form-label">
              Số Lượng Lấy (Tối đa: {activeLot ? activeLot.amount : 0})
            </label>
            <input
              type="number"
              min={1}
              max={activeLot ? activeLot.amount : 1}
              value={quantity}
              onChange={(e) => setQuantity(Math.max(1, Number(e.target.value)))}
              className="form-input"
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label">Mục Đích Sử Dụng</label>
            <select
              value={purpose}
              onChange={(e) => setPurpose(e.target.value)}
              className="form-input"
            >
              <option value="Sửa chữa thiết bị">Sửa chữa thiết bị</option>
              <option value="Thay thế linh kiện hỏng">Thay thế linh kiện hỏng</option>
              <option value="Xuất kiểm thử / R&D">Xuất kiểm thử / R&D</option>
              <option value="Xuất dự phòng">Xuất dự phòng</option>
              <option value="Khác">Khác (Ghi rõ bên dưới)</option>
            </select>
          </div>

          <div className="form-group">
            <label className="form-label">Ghi Chú Chi Tiết</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="VD: Sử dụng cho đơn sửa chữa #RO-1024, thay IC nguồn..."
              className="form-input"
              rows={3}
            />
          </div>

          <div className="modal-footer" style={{ marginTop: '20px' }}>
            <button type="button" className="btn-cancel" onClick={onClose}>
              Hủy
            </button>
            <button type="submit" className="btn-submit btn-primary" disabled={submitting}>
              {submitting ? 'Đang xử lý...' : 'Xác Nhận Lấy Out Kho'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

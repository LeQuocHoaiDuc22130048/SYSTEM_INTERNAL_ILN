import React, { useState } from 'react';
import { X, Briefcase, Calendar, FileText, Trash2, CheckCircle2 } from 'lucide-react';
import { getJsonAuthHeaders } from '../utils/auth';

interface FieldWorkModalProps {
  initialDate?: string;
  initialNote?: string;
  isExisting?: boolean;
  onClose: () => void;
  showToast: (message: string) => void;
  onSuccess: () => void;
}

export const FieldWorkModal: React.FC<FieldWorkModalProps> = ({
  initialDate,
  initialNote = '',
  isExisting = false,
  onClose,
  showToast,
  onSuccess,
}) => {
  const todayStr = new Date().toLocaleDateString('en-CA'); // YYYY-MM-DD
  const [workDate, setWorkDate] = useState<string>(initialDate || todayStr);
  const [note, setNote] = useState<string>(initialNote);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [removing, setRemoving] = useState<boolean>(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanNote = note.trim();
    if (!cleanNote) {
      showToast('Vui lòng nhập nội dung hoặc địa điểm đi công trình.');
      return;
    }
    if (cleanNote.length > 2000) {
      showToast('Ghi chú không được vượt quá 2000 ký tự.');
      return;
    }
    if (workDate > todayStr) {
      showToast('Không thể ghi nhận ngày công trình trong tương lai.');
      return;
    }

    setSubmitting(true);
    try {
      const response = await fetch(`/api/attendance/me/field-work/${workDate}`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ note: cleanNote }),
      });

      if (!response.ok) {
        const err = await response.json();
        throw new Error(err.message || 'Lỗi khi ghi nhận ngày đi công trình');
      }

      showToast(`Đã gửi yêu cầu đi công trình, chờ duyệt — ngày ${workDate.split('-').reverse().join('/')} thành công!`);
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Có lỗi xảy ra khi lưu ngày đi công trình.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleRemove = async () => {
    if (!window.confirm(`Bạn có chắc muốn hủy ghi nhận ngày đi công trình ${workDate.split('-').reverse().join('/')}?`)) {
      return;
    }

    setRemoving(true);
    try {
      const response = await fetch(`/api/attendance/me/field-work/${workDate}`, {
        method: 'DELETE',
        headers: getJsonAuthHeaders(),
      });

      if (!response.ok) {
        const err = await response.json();
        throw new Error(err.message || 'Lỗi khi hủy ngày đi công trình');
      }

      showToast(`Đã hủy ghi nhận ngày đi công trình ${workDate.split('-').reverse().join('/')}`);
      onSuccess();
      onClose();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Có lỗi xảy ra khi hủy ngày đi công trình.');
    } finally {
      setRemoving(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '480px' }}>
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{
              width: '36px',
              height: '36px',
              borderRadius: '8px',
              backgroundColor: '#fef3c7',
              color: '#d97706',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              <Briefcase size={20} />
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '17px', fontWeight: 700 }}>
                {isExisting ? 'Chỉnh sửa ngày đi công trình' : 'Ghi nhận ngày đi công trình'}
              </h3>
              <p style={{ margin: 0, fontSize: '12px', color: 'var(--color-text-muted, #64748b)' }}>
                Tự động tính 1 công làm việc (không cần duyệt)
              </p>
            </div>
          </div>
          <button className="modal-close" onClick={onClose} disabled={submitting || removing}>
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit}>
          <div className="modal-body" style={{ padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="form-group">
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 600, marginBottom: '6px' }}>
                <Calendar size={15} />
                Ngày làm việc
              </label>
              <input
                type="date"
                className="form-control"
                max={todayStr}
                value={workDate}
                onChange={(e) => setWorkDate(e.target.value)}
                required
                style={{
                  width: '100%',
                  padding: '9px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--color-border, #cbd5e1)',
                  fontSize: '14px'
                }}
              />
              <span style={{ fontSize: '11px', color: 'var(--color-text-muted, #64748b)', marginTop: '4px', display: 'block' }}>
                * Chỉ được ghi nhận cho hôm nay hoặc các ngày trước đó.
              </span>
            </div>

            <div className="form-group">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', fontWeight: 600 }}>
                  <FileText size={15} />
                  Địa điểm / Nội dung công tác
                </label>
                <span style={{ fontSize: '11px', color: note.length > 2000 ? '#ef4444' : 'var(--color-text-muted, #64748b)' }}>
                  {note.length}/2000
                </span>
              </div>
              <textarea
                className="form-control"
                rows={4}
                placeholder="Ví dụ: Lắp đặt biến tần tại nhà máy ABC, KCN VSIP 1, Bình Dương..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
                maxLength={2000}
                required
                style={{
                  width: '100%',
                  padding: '10px 12px',
                  borderRadius: '8px',
                  border: '1px solid var(--color-border, #cbd5e1)',
                  fontSize: '14px',
                  resize: 'vertical'
                }}
              />
            </div>

            <div style={{
              padding: '10px 12px',
              backgroundColor: '#fffbeb',
              borderRadius: '8px',
              border: '1px solid #fef3c7',
              fontSize: '12px',
              color: '#92400e',
              lineHeight: 1.5
            }}>
              💡 <strong>Lưu ý:</strong> Chỉ sau khi quản trị viên chấp nhận mới tính <strong>1.0 công chuẩn</strong> (kể cả Chủ nhật). Giờ quét thực tế (nếu có) vẫn được giữ nguyên.
            </div>
          </div>

          <div className="modal-footer" style={{ padding: '16px 20px', display: 'flex', justifyContent: isExisting ? 'space-between' : 'flex-end', gap: '10px' }}>
            {isExisting && (
              <button
                type="button"
                className="action-btn-outline danger"
                onClick={handleRemove}
                disabled={submitting || removing}
                style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#ef4444', borderColor: '#fca5a5' }}
              >
                <Trash2 size={15} />
                {removing ? 'Đang hủy...' : 'Hủy công trình'}
              </button>
            )}

            <div style={{ display: 'flex', gap: '10px' }}>
              <button
                type="button"
                className="action-btn-outline"
                onClick={onClose}
                disabled={submitting || removing}
              >
                Đóng
              </button>
              <button
                type="submit"
                className="action-btn-primary"
                disabled={submitting || removing || !note.trim()}
                style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <CheckCircle2 size={15} />
                {submitting ? 'Đang lưu...' : 'Lưu ghi nhận'}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};

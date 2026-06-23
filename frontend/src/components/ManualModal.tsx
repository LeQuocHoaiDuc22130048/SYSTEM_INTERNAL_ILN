import React, { useState } from 'react';
import { X } from 'lucide-react';

interface ManualModalProps {
  employee: any;
  selectedDate: string;
  onClose: () => void;
  showToast: (message: string) => void;
  onSaveSuccess: () => void;
}

export const ManualModal: React.FC<ManualModalProps> = ({
  employee,
  selectedDate,
  onClose,
  showToast,
  onSaveSuccess,
}) => {
  const [manualType, setManualType] = useState<'IN' | 'OUT'>('IN');
  const [manualTime, setManualTime] = useState<string>('08:00');
  const [manualNote, setManualNote] = useState<string>('');
  const [manualSubmitting, setManualSubmitting] = useState<boolean>(false);

  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employee) return;

    setManualSubmitting(true);
    try {
      const token = localStorage.getItem('accessToken');
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const checkTime = `${selectedDate}T${manualTime}:00+07:00`;

      const body = {
        employeeId: employee.id,
        type: manualType,
        checkTime,
        note: manualNote || 'Chấm công thủ công bởi quản trị viên'
      };

      const response = await fetch('/api/v1/attendance/manual', {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Lỗi khi gửi yêu cầu chấm công thủ công');
      }

      showToast(`Đã ghi nhận công tay thành công cho ${employee.name}`);
      onSaveSuccess();
      onClose();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Có lỗi xảy ra khi chấm công thủ công.');
    } finally {
      setManualSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '450px' }}>
        <div className="modal-header">
          <h3 className="modal-title" style={{ fontSize: '18px', fontWeight: 'bold' }}>Chấm công thủ công</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <form onSubmit={handleManualSubmit}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: '#f8fafc', padding: '12px', borderRadius: '8px' }}>
              <div className="avatar-badge">{getAvatarLetters(employee.name)}</div>
              <div>
                <div style={{ fontWeight: 'bold', color: 'var(--color-text-dark)' }}>{employee.name}</div>
                <div style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>{employee.employeeCode}</div>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Ngày chấm công</label>
              <input 
                type="date" 
                value={selectedDate} 
                disabled 
                style={{
                  padding: '8px 12px',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  background: '#f1f5f9',
                  color: 'var(--color-text-light)',
                  cursor: 'not-allowed'
                }}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Loại ghi công</label>
              <div style={{ display: 'flex', gap: '16px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                  <input 
                    type="radio" 
                    name="manualType" 
                    value="IN" 
                    checked={manualType === 'IN'} 
                    onChange={() => setManualType('IN')} 
                  />
                  Vào (CHECK_IN)
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                  <input 
                    type="radio" 
                    name="manualType" 
                    value="OUT" 
                    checked={manualType === 'OUT'} 
                    onChange={() => setManualType('OUT')} 
                  />
                  Ra (CHECK_OUT)
                </label>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Giờ chấm công</label>
              <input 
                type="time" 
                value={manualTime} 
                onChange={(e) => setManualTime(e.target.value)} 
                required
                style={{
                  padding: '8px 12px',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  outline: 'none'
                }}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Ghi chú</label>
              <textarea 
                value={manualNote} 
                onChange={(e) => setManualNote(e.target.value)}
                placeholder="Lý do quên chấm công, đi công tác,..."
                rows={3}
                style={{
                  padding: '8px 12px',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  outline: 'none',
                  fontFamily: 'inherit',
                  resize: 'none'
                }}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', padding: '16px 24px', borderTop: '1px solid #e2e8f0' }}>
            <button 
              type="button" 
              className="action-btn-outline" 
              onClick={onClose}
              disabled={manualSubmitting}
            >
              Hủy
            </button>
            <button 
              type="submit" 
              className="action-btn-primary"
              disabled={manualSubmitting}
            >
              {manualSubmitting ? 'Đang lưu...' : 'Xác nhận'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

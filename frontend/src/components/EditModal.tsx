import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';

interface EditModalProps {
  employee: any;
  date: string;
  dayLog: any;
  onClose: () => void;
  showToast: (message: string) => void;
  onSaveSuccess: () => void;
}

export const EditModal: React.FC<EditModalProps> = ({
  employee,
  date,
  dayLog,
  onClose,
  showToast,
  onSaveSuccess,
}) => {
  const [hasEditCheckIn, setHasEditCheckIn] = useState<boolean>(false);
  const [editCheckInTime, setEditCheckInTime] = useState<string>('08:00');
  const [editCheckInRecordId, setEditCheckInRecordId] = useState<string | null>(null);
  
  const [hasEditCheckOut, setHasEditCheckOut] = useState<boolean>(false);
  const [editCheckOutTime, setEditCheckOutTime] = useState<string>('17:00');
  const [editCheckOutRecordId, setEditCheckOutRecordId] = useState<string | null>(null);
  
  const [editNote, setEditNote] = useState<string>('');
  const [editSubmitting, setEditSubmitting] = useState<boolean>(false);

  useEffect(() => {
    if (!dayLog) return;
    const checkInEvent = dayLog.events?.find((e: any) => e.type === 'CHECK_IN');
    const checkOutEvent = dayLog.events?.find((e: any) => e.type === 'CHECK_OUT');
    
    if (checkInEvent) {
      setHasEditCheckIn(true);
      setEditCheckInTime(checkInEvent.logTime);
      setEditCheckInRecordId(checkInEvent.id || null);
    } else {
      setHasEditCheckIn(false);
      setEditCheckInTime('08:00');
      setEditCheckInRecordId(null);
    }
    
    if (checkOutEvent) {
      setHasEditCheckOut(true);
      setEditCheckOutTime(checkOutEvent.logTime);
      setEditCheckOutRecordId(checkOutEvent.id || null);
    } else {
      setHasEditCheckOut(false);
      setEditCheckOutTime('17:00');
      setEditCheckOutRecordId(null);
    }
    
    setEditNote('');
  }, [dayLog]);

  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employee) return;

    setEditSubmitting(true);
    try {
      const token = localStorage.getItem('accessToken');
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const noteText = editNote || 'Chỉnh sửa bởi quản lý';

      // 1. Process Check-In
      if (hasEditCheckIn) {
        const checkInTimeFull = `${date}T${editCheckInTime}:00+07:00`;
        if (editCheckInRecordId) {
          // Update existing
          const response = await fetch(`/api/v1/attendance/records/${editCheckInRecordId}`, {
            method: 'PUT',
            headers,
            body: JSON.stringify({
              checkTime: checkInTimeFull,
              isValid: true,
              note: noteText,
            }),
          });
          if (!response.ok) throw new Error('Không thể cập nhật giờ check-in');
        } else {
          // Create new manual check-in
          const response = await fetch('/api/v1/attendance/manual', {
            method: 'POST',
            headers,
            body: JSON.stringify({
              employeeId: employee.id,
              type: 'IN',
              checkTime: checkInTimeFull,
              note: noteText,
            }),
          });
          if (!response.ok) throw new Error('Không thể tạo mới giờ check-in');
        }
      } else if (editCheckInRecordId) {
        // Deleted/unchecked: Delete record
        const response = await fetch(`/api/v1/attendance/records/${editCheckInRecordId}`, {
          method: 'DELETE',
          headers,
        });
        if (!response.ok) throw new Error('Không thể xóa giờ check-in');
      }

      // 2. Process Check-Out
      if (hasEditCheckOut) {
        const checkOutTimeFull = `${date}T${editCheckOutTime}:00+07:00`;
        if (editCheckOutRecordId) {
          // Update existing
          const response = await fetch(`/api/v1/attendance/records/${editCheckOutRecordId}`, {
            method: 'PUT',
            headers,
            body: JSON.stringify({
              checkTime: checkOutTimeFull,
              isValid: true,
              note: noteText,
            }),
          });
          if (!response.ok) throw new Error('Không thể cập nhật giờ check-out');
        } else {
          // Create new manual check-out
          const response = await fetch('/api/v1/attendance/manual', {
            method: 'POST',
            headers,
            body: JSON.stringify({
              employeeId: employee.id,
              type: 'OUT',
              checkTime: checkOutTimeFull,
              note: noteText,
            }),
          });
          if (!response.ok) throw new Error('Không thể tạo mới giờ check-out');
        }
      } else if (editCheckOutRecordId) {
        // Deleted/unchecked: Delete record
        const response = await fetch(`/api/v1/attendance/records/${editCheckOutRecordId}`, {
          method: 'DELETE',
          headers,
        });
        if (!response.ok) throw new Error('Không thể xóa giờ check-out');
      }

      showToast(`Đã lưu chỉnh sửa bảng công thành công cho ngày ${date}`);
      onSaveSuccess();
      onClose();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Có lỗi xảy ra khi cập nhật chấm công.');
    } finally {
      setEditSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content" style={{ maxWidth: '450px' }}>
        <div className="modal-header">
          <h3 className="modal-title" style={{ fontSize: '18px', fontWeight: 'bold' }}>Chỉnh sửa bảng công</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <form onSubmit={handleSaveEdit}>
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: '#f8fafc', padding: '12px', borderRadius: '8px' }}>
              <div className="avatar-badge">{getAvatarLetters(employee.name)}</div>
              <div>
                <div style={{ fontWeight: 'bold', color: 'var(--color-text-dark)' }}>{employee.name}</div>
                <div style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>
                  Ngày chỉnh sửa: <strong>{date.split('-').reverse().join('/')}</strong>
                </div>
              </div>
            </div>

            {/* Check-In Edit */}
            <div style={{ border: '1px solid #e2e8f0', borderRadius: '8px', padding: '12px', background: '#f8fafc' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', marginBottom: '8px' }}>
                <input 
                  type="checkbox" 
                  checked={hasEditCheckIn} 
                  onChange={(e) => setHasEditCheckIn(e.target.checked)} 
                />
                Ghi nhận Check-in (Vào)
              </label>
              {hasEditCheckIn && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: '8px' }}>
                  <label style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>Giờ Check-in</label>
                  <input 
                    type="time" 
                    value={editCheckInTime} 
                    onChange={(e) => setEditCheckInTime(e.target.value)} 
                    required
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #cbd5e1',
                      borderRadius: '6px',
                      outline: 'none',
                      fontSize: '14px'
                    }}
                  />
                </div>
              )}
            </div>

            {/* Check-Out Edit */}
            <div style={{ border: '1px solid #e2e8f0', borderRadius: '8px', padding: '12px', background: '#f8fafc' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', marginBottom: '8px' }}>
                <input 
                  type="checkbox" 
                  checked={hasEditCheckOut} 
                  onChange={(e) => setHasEditCheckOut(e.target.checked)} 
                />
                Ghi nhận Check-out (Ra)
              </label>
              {hasEditCheckOut && (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', marginTop: '8px' }}>
                  <label style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>Giờ Check-out</label>
                  <input 
                    type="time" 
                    value={editCheckOutTime} 
                    onChange={(e) => setEditCheckOutTime(e.target.value)} 
                    required
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #cbd5e1',
                      borderRadius: '6px',
                      outline: 'none',
                      fontSize: '14px'
                    }}
                  />
                </div>
              )}
            </div>

            {/* Note Field */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Lý do chỉnh sửa</label>
              <textarea 
                value={editNote} 
                onChange={(e) => setEditNote(e.target.value)} 
                placeholder="Nhập lý do chỉnh sửa (ví dụ: Quên check-in, chấm công muộn...)"
                required
                style={{
                  padding: '8px 12px',
                  border: '1px solid #cbd5e1',
                  borderRadius: '6px',
                  outline: 'none',
                  fontSize: '14px',
                  minHeight: '80px',
                  resize: 'vertical'
                }}
              />
            </div>
          </div>

          <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', padding: '16px 24px', borderTop: '1px solid #e2e8f0' }}>
            <button 
              type="button" 
              className="action-btn-outline" 
              onClick={onClose}
              disabled={editSubmitting}
            >
              Hủy
            </button>
            <button 
              type="submit" 
              className="action-btn-primary"
              disabled={editSubmitting}
            >
              {editSubmitting ? 'Đang lưu...' : 'Lưu thay đổi'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

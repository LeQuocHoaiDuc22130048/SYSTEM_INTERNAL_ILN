import React, { useState } from 'react';
import { X } from 'lucide-react';
import type { AttendanceCheckType } from '../mockData';
import { getAvatarLetters } from '../utils/employee';
import { getJsonAuthHeaders } from '../utils/auth';
import { TimePicker24h } from './TimePicker24h';


interface ManualModalProps {
  employee: { id: string; name: string; employeeCode: string; [key: string]: any };
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
  const [manualType, setManualType] = useState<AttendanceCheckType>('IN');
  const [manualTime, setManualTime] = useState<string>('08:00');
  const [manualNote, setManualNote] = useState<string>('');
  const [manualSubmitting, setManualSubmitting] = useState<boolean>(false);

  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employee) return;

    setManualSubmitting(true);
    try {
      const cleanTime = manualTime.substring(0, 5);
      const body = {
        employeeId: employee.id,
        type: manualType,
        checkTime: `${selectedDate}T${cleanTime}:00+07:00`,
        note: manualNote || 'Chấm công thủ công bởi quản trị viên',
      };

      const response = await fetch('/api/v1/attendance/manual', {
        method: 'POST',
        headers: getJsonAuthHeaders(),
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
      <div className="modal-content modal-content--narrow">
        <div className="modal-header">
          <h3 className="modal-title">Chấm công thủ công</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <form onSubmit={handleManualSubmit}>
          <div className="modal-body modal-body--gap">
            <div className="edit-employee-card">
              <div className="avatar-badge">{getAvatarLetters(employee.name)}</div>
              <div>
                <div className="edit-employee-name">{employee.name}</div>
                <div className="edit-employee-date">{employee.employeeCode}</div>
              </div>
            </div>

            <div className="edit-note-group">
              <label className="edit-note-label">Ngày chấm công</label>
              <input
                type="date"
                className="edit-time-input edit-time-input--disabled"
                value={selectedDate}
                disabled
              />
            </div>

            <div className="edit-note-group">
              <label className="edit-note-label">Loại ghi công</label>
              <div className="manual-type-options">
                {(['IN', 'OUT'] as AttendanceCheckType[]).map((type) => (
                  <label key={type} className="manual-type-label">
                    <input
                      type="radio"
                      name="manualType"
                      value={type}
                      checked={manualType === type}
                      onChange={() => setManualType(type)}
                    />
                    {type === 'IN' ? 'Vào (CHECK_IN)' : 'Ra (CHECK_OUT)'}
                  </label>
                ))}
              </div>
            </div>

            <div className="edit-note-group">
              <label className="edit-note-label">Giờ chấm công</label>
              <TimePicker24h
                value={manualTime}
                onChange={setManualTime}
              />
            </div>

            <div className="edit-note-group">
              <label className="edit-note-label">Ghi chú</label>
              <textarea
                className="edit-note-textarea"
                value={manualNote}
                onChange={(e) => setManualNote(e.target.value)}
                placeholder="Lý do quên chấm công, đi công tác,..."
                rows={3}
              />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="action-btn-outline" onClick={onClose} disabled={manualSubmitting}>
              Hủy
            </button>
            <button type="submit" className="action-btn-primary" disabled={manualSubmitting}>
              {manualSubmitting ? 'Đang lưu...' : 'Xác nhận'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

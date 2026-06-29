import React, { useState, useEffect } from 'react';
import { X } from 'lucide-react';
import { getAvatarLetters } from '../utils/employee';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';

interface EditModalProps {
  employee: { id: string; name: string; [key: string]: any };
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

    setHasEditCheckIn(!!checkInEvent);
    setEditCheckInTime(checkInEvent?.logTime ?? '08:00');
    setEditCheckInRecordId(checkInEvent?.id ?? null);

    setHasEditCheckOut(!!checkOutEvent);
    setEditCheckOutTime(checkOutEvent?.logTime ?? '17:00');
    setEditCheckOutRecordId(checkOutEvent?.id ?? null);

    setEditNote('');
  }, [dayLog]);

  const upsertOrDeleteRecord = async (
    has: boolean,
    recordId: string | null,
    type: 'IN' | 'OUT',
    time: string,
    note: string
  ) => {
    const timeFull = `${date}T${time}:00+07:00`;
    const headers = getJsonAuthHeaders();

    if (has) {
      const url = recordId
        ? `/api/v1/attendance/records/${recordId}`
        : '/api/v1/attendance/manual';
      const method = recordId ? 'PUT' : 'POST';
      const body = recordId
        ? { checkTime: timeFull, isValid: true, note }
        : { employeeId: employee.id, type, checkTime: timeFull, note };

      const response = await fetch(url, { method, headers, body: JSON.stringify(body) });
      if (!response.ok) {
        throw new Error(`Không thể ${recordId ? 'cập nhật' : 'tạo mới'} giờ check-${type.toLowerCase()}`);
      }
    } else if (recordId) {
      const response = await fetch(`/api/v1/attendance/records/${recordId}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      if (!response.ok) throw new Error(`Không thể xóa giờ check-${type.toLowerCase()}`);
    }
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!employee) return;

    setEditSubmitting(true);
    const note = editNote || 'Chỉnh sửa bởi quản lý';
    try {
      await upsertOrDeleteRecord(hasEditCheckIn, editCheckInRecordId, 'IN', editCheckInTime, note);
      await upsertOrDeleteRecord(hasEditCheckOut, editCheckOutRecordId, 'OUT', editCheckOutTime, note);
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
      <div className="modal-content modal-content--narrow">
        <div className="modal-header">
          <h3 className="modal-title">Chỉnh sửa bảng công</h3>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>
        <form onSubmit={handleSaveEdit}>
          <div className="modal-body modal-body--gap">
            <div className="edit-employee-card">
              <div className="avatar-badge">{getAvatarLetters(employee.name)}</div>
              <div>
                <div className="edit-employee-name">{employee.name}</div>
                <div className="edit-employee-date">
                  Ngày chỉnh sửa: <strong>{date.split('-').reverse().join('/')}</strong>
                </div>
              </div>
            </div>

            <div className="edit-record-block">
              <label className="edit-record-label">
                <input
                  type="checkbox"
                  checked={hasEditCheckIn}
                  onChange={(e) => setHasEditCheckIn(e.target.checked)}
                />
                Ghi nhận Check-in (Vào)
              </label>
              {hasEditCheckIn && (
                <div className="edit-time-group">
                  <label className="edit-time-label">Giờ Check-in</label>
                  <input
                    type="time"
                    className="edit-time-input"
                    value={editCheckInTime}
                    onChange={(e) => setEditCheckInTime(e.target.value)}
                    required
                  />
                </div>
              )}
            </div>

            <div className="edit-record-block">
              <label className="edit-record-label">
                <input
                  type="checkbox"
                  checked={hasEditCheckOut}
                  onChange={(e) => setHasEditCheckOut(e.target.checked)}
                />
                Ghi nhận Check-out (Ra)
              </label>
              {hasEditCheckOut && (
                <div className="edit-time-group">
                  <label className="edit-time-label">Giờ Check-out</label>
                  <input
                    type="time"
                    className="edit-time-input"
                    value={editCheckOutTime}
                    onChange={(e) => setEditCheckOutTime(e.target.value)}
                    required
                  />
                </div>
              )}
            </div>

            <div className="edit-note-group">
              <label className="edit-note-label">Lý do chỉnh sửa</label>
              <textarea
                className="edit-note-textarea"
                value={editNote}
                onChange={(e) => setEditNote(e.target.value)}
                placeholder="Nhập lý do chỉnh sửa (ví dụ: Quên check-in, chấm công muộn...)"
                required
              />
            </div>
          </div>

          <div className="modal-footer">
            <button type="button" className="action-btn-outline" onClick={onClose} disabled={editSubmitting}>
              Hủy
            </button>
            <button type="submit" className="action-btn-primary" disabled={editSubmitting}>
              {editSubmitting ? 'Đang lưu...' : 'Lưu thay đổi'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

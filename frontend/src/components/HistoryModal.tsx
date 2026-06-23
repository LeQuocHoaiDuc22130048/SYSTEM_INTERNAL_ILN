import React, { useState, useEffect } from 'react';
import { 
  X, 
  LogIn, 
  LogOut, 
  ChevronDown, 
  ChevronUp 
} from 'lucide-react';
import type { EmployeeHistoryResponse } from '../mockData';

interface HistoryModalProps {
  employee: { id: string; name: string; dept: string };
  currentMonth: number;
  currentYear: number;
  onClose: () => void;
  onOpenEditModal: (dayLog: any, employee: any) => void;
  showToast: (message: string) => void;
}

const normalizeHistoryResponse = (data: any): any => {
  if (!data || !data.days) return data;
  return {
    ...data,
    days: data.days.map((day: any) => ({
      ...day,
      events: day.events.map((evt: any) => ({
        ...evt,
        type: evt.type === 'IN' ? 'CHECK_IN' : evt.type === 'OUT' ? 'CHECK_OUT' : evt.type
      }))
    }))
  };
};

const LATE_GRACE_MINUTES = 15;

export const HistoryModal: React.FC<HistoryModalProps> = ({
  employee,
  currentMonth,
  currentYear,
  onClose,
  onOpenEditModal,
  showToast,
}) => {
  const [historyData, setHistoryData] = useState<EmployeeHistoryResponse | null>(null);
  const [historyFilter, setHistoryFilter] = useState<string>('ALL');
  const [historyLoading, setHistoryLoading] = useState<boolean>(false);
  const [expandedDays, setExpandedDays] = useState<Record<string, boolean>>({});

  // Fetch History Logs
  useEffect(() => {
    const fetchHistoryData = async () => {
      setHistoryLoading(true);
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 8000);
        const token = localStorage.getItem('accessToken');
        const headers: Record<string, string> = {};
        if (token) {
          headers['Authorization'] = `Bearer ${token}`;
        }
        const response = await fetch(`/api/attendance/${employee.id}/logs?year=${currentYear}&month=${currentMonth}`, {
          signal: controller.signal,
          headers,
        });
        clearTimeout(timeoutId);
        if (!response.ok) {
          throw new Error('Không thể tải lịch sử chi tiết từ server');
        }
        const apiData = await response.json();
        if (apiData && apiData.data) {
          setHistoryData(normalizeHistoryResponse(apiData.data));
        } else {
          throw new Error('Dữ liệu không đúng cấu trúc');
        }
      } catch (err) {
        console.error('Lỗi tải lịch sử chi tiết cho:', employee.name);
        setHistoryData(null);
      } finally {
        setHistoryLoading(false);
      }
    };

    fetchHistoryData();
  }, [employee, currentYear, currentMonth]);

  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const toggleDayCollapse = (date: string) => {
    setExpandedDays(prev => ({
      ...prev,
      [date]: !prev[date]
    }));
  };

  const getModalDayStatusBadge = (status: string) => {
    switch (status) {
      case 'PRESENT':
        return <span className="pill-badge present">Đủ công</span>;
      case 'LATE':
        return <span className="pill-badge late">Vào muộn</span>;
      case 'ABSENT':
        return <span className="pill-badge absent">Vắng KP</span>;
      case 'LEAVE':
        return <span className="pill-badge leave">Nghỉ phép</span>;
      case 'HOLIDAY':
        return <span className="pill-badge holiday">Nghỉ lễ/CN</span>;
      case 'FUTURE':
        return null;
      default:
        return <span className="pill-badge holiday">Nghỉ lễ/CN</span>;
    }
  };

  const getEventTimeDiffs = (events: any[], shiftStart: string, shiftEnd: string) => {
    const inEvent = events.find(e => e.type === 'CHECK_IN');
    const outEvent = events.find(e => e.type === 'CHECK_OUT');

    let inMsg = "Vào: --";
    let outMsg = "Ra: --";
    let realMsg = "Thực làm: 0h";

    if (inEvent) {
      const [sh, sm] = shiftStart.split(':').map(Number);
      const [eh, em] = inEvent.logTime.split(':').map(Number);
      const diffMin = (eh * 60 + em) - (sh * 60 + sm);
      if (diffMin > LATE_GRACE_MINUTES) {
        inMsg = `Vào: muộn +${diffMin}p`;
      } else {
        inMsg = "Vào: đúng giờ";
      }
    }

    if (outEvent) {
      const [sh, sm] = shiftEnd.split(':').map(Number);
      const [eh, em] = outEvent.logTime.split(':').map(Number);
      const diffMin = (sh * 60 + sm) - (eh * 60 + em);
      if (diffMin > 5) {
        outMsg = `Ra: sớm -${diffMin}p`;
      } else {
        outMsg = "Ra: đúng giờ";
      }
    }

    if (inEvent && outEvent) {
      const [ih, im] = inEvent.logTime.split(':').map(Number);
      const [oh, om] = outEvent.logTime.split(':').map(Number);
      const diffMin = (oh * 60 + om) - (ih * 60 + im);
      const hrs = Math.floor(diffMin / 60);
      const mins = diffMin % 60;
      realMsg = `Thực làm: ${hrs}h${mins.toString().padStart(2, '0')}m`;
    }

    return { inMsg, outMsg, realMsg };
  };

  const getFilteredHistoryDays = () => {
    if (!historyData) return [];
    
    return historyData.days.filter(day => {
      if (historyFilter === 'ALL') return true;
      
      const outEvent = day.events.find(e => e.type === 'CHECK_OUT');
      const hasManual = day.events.some(e => e.source === 'MANUAL');

      if (historyFilter === 'LATE') {
        return day.status === 'LATE';
      }
      
      if (historyFilter === 'EARLY') {
        if (!outEvent) return false;
        const [sh, sm] = historyData.employee.shiftEnd.split(':').map(Number);
        const [eh, em] = outEvent.logTime.split(':').map(Number);
        const diffMin = (sh * 60 + sm) - (eh * 60 + em);
        return diffMin > 5;
      }

      if (historyFilter === 'MANUAL') {
        return hasManual;
      }

      if (historyFilter === 'HOLIDAY') {
        return day.status === 'HOLIDAY';
      }

      return true;
    });
  };

  return (
    <div className="modal-overlay">
      <div className="modal-content">
        <div className="modal-header">
          <div className="modal-employee-header">
            <div className="modal-avatar">{getAvatarLetters(employee.name)}</div>
            <div className="modal-emp-info">
              <span className="modal-emp-name">{employee.name}</span>
              <span className="modal-emp-meta">
                Phòng ban: <strong>{employee.dept}</strong> &middot; 
                Tháng {currentMonth}/{currentYear} &middot; 
                Ca làm việc: <strong>Ca hành chính (08:00 - 17:00)</strong>
              </span>
            </div>
          </div>
          <button className="modal-close" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className="modal-body">
          {historyLoading ? (
            <div className="loading-overlay">Đang tải lịch sử chi tiết...</div>
          ) : !historyData ? (
            <div className="loading-overlay">Không thể tải dữ liệu. Vui lòng thử lại.</div>
          ) : (
            <>
              {/* Summary horizontal stats cards */}
              <div className="modal-stats-row">
                <div className="modal-stat-card">
                  <span className="modal-stat-label">Ngày làm việc</span>
                  <span className="modal-stat-value">{historyData.summary.workDays} ngày</span>
                </div>
                <div className="modal-stat-card info">
                  <span className="modal-stat-label">Tổng giờ làm</span>
                  <span className="modal-stat-value">{historyData.summary.totalHours}h</span>
                </div>
                <div className="modal-stat-card warning">
                  <span className="modal-stat-label">Vào muộn</span>
                  <span className="modal-stat-value">{historyData.summary.lateCount} lần</span>
                </div>
                <div className="modal-stat-card danger">
                  <span className="modal-stat-label">Vắng KP</span>
                  <span className="modal-stat-value">{historyData.summary.absentDays} ngày</span>
                </div>
                <div className="modal-stat-card info">
                  <span className="modal-stat-label">Tăng ca (OT)</span>
                  <span className="modal-stat-value">{historyData.summary.overtimeHours}h</span>
                </div>
              </div>

              {/* Filter Quick Pills */}
              <div className="filter-pills">
                <button 
                  className={`filter-pill ${historyFilter === 'ALL' ? 'active' : ''}`}
                  onClick={() => setHistoryFilter('ALL')}
                >
                  Tất cả
                </button>
                <button 
                  className={`filter-pill ${historyFilter === 'LATE' ? 'active' : ''}`}
                  onClick={() => setHistoryFilter('LATE')}
                >
                  Đi muộn
                </button>
                <button 
                  className={`filter-pill ${historyFilter === 'EARLY' ? 'active' : ''}`}
                  onClick={() => setHistoryFilter('EARLY')}
                >
                  Về sớm
                </button>
                <button 
                  className={`filter-pill ${historyFilter === 'MANUAL' ? 'active' : ''}`}
                  onClick={() => setHistoryFilter('MANUAL')}
                >
                  Chỉnh thủ công
                </button>
                <button 
                  className={`filter-pill ${historyFilter === 'HOLIDAY' ? 'active' : ''}`}
                  onClick={() => setHistoryFilter('HOLIDAY')}
                >
                  Cuối tuần / lễ
                </button>
              </div>

              {/* Daily Blocks list */}
              <div className="logs-list">
                {getFilteredHistoryDays().map((dayLog) => {
                  const isCollapsed = !expandedDays[dayLog.date];
                  
                  const { inMsg, outMsg, realMsg } = getEventTimeDiffs(
                    dayLog.events, 
                    historyData.employee.shiftStart, 
                    historyData.employee.shiftEnd
                  );

                  const checkInEvent = dayLog.events.find(e => e.type === 'CHECK_IN');
                  const checkOutEvent = dayLog.events.find(e => e.type === 'CHECK_OUT');

                  const hasLate = dayLog.status === 'LATE';
                  const hasManual = dayLog.events.some(e => e.source === 'MANUAL');
                  const hasOT = dayLog.events.some(e => e.note.includes('OT'));

                  return (
                    <div key={dayLog.date} className="day-block">
                      {/* Day summary row */}
                      <div 
                        className="day-header-summary"
                        onClick={() => toggleDayCollapse(dayLog.date)}
                      >
                        <div className="day-title-info">
                          <span className="day-date">{dayLog.date.split('-').reverse().slice(0, 2).join('/')}</span>
                          <span className="day-dow">{dayLog.dayOfWeek}</span>
                          
                          <div className="day-chips">
                            {checkInEvent ? (
                              <span className="chip-io in">
                                <LogIn size={12} />
                                {checkInEvent.logTime}
                              </span>
                            ) : dayLog.status !== 'HOLIDAY' && dayLog.status !== 'LEAVE' && dayLog.status !== 'FUTURE' ? (
                              <span className="chip-io absent">Không check-in</span>
                            ) : null}

                            {checkOutEvent ? (
                              <span className="chip-io out">
                                <LogOut size={12} />
                                {checkOutEvent.logTime}
                              </span>
                            ) : checkInEvent ? (
                              <span className="chip-io absent">Không check-out</span>
                            ) : null}

                            {hasLate && <span className="chip-badge warning">Muộn</span>}
                            {hasOT && <span className="chip-badge info">OT</span>}
                            {hasManual && <span className="chip-badge holiday">Thủ công</span>}
                          </div>
                        </div>

                        <div className="day-right-side">
                          {getModalDayStatusBadge(dayLog.status)}
                          {isCollapsed ? <ChevronDown size={18} /> : <ChevronUp size={18} />}
                        </div>
                      </div>

                      {/* Expanded detailed timeline */}
                      {!isCollapsed && (
                        <div className="day-details">
                          {dayLog.events.length === 0 ? (
                            <div style={{ fontSize: '13px', color: 'var(--color-text-light)', fontStyle: 'italic' }}>
                              Không ghi nhận dữ liệu chấm công.
                            </div>
                          ) : (
                            <div className="timeline">
                              {dayLog.events.map((evt, evtIdx) => (
                                <div key={evtIdx} className="timeline-event">
                                  <div className="event-details">
                                    <div className={`timeline-dot ${evt.type.toLowerCase()} ${evt.source.toLowerCase()}`}></div>
                                    <span className="event-time">{evt.logTime}</span>
                                    <span className="event-label">
                                      {evt.type === 'CHECK_IN' ? 'Check-in thành công' : 'Check-out thành công'}
                                    </span>
                                    <span className={`source-tag ${evt.source.toLowerCase()}`}>
                                      {evt.source === 'FACE' ? `Face ID · ${Math.round(evt.confidence * 100)}%` : 'Thủ công'}
                                    </span>
                                  </div>
                                  
                                  {evt.note && (
                                    <div className="event-note">Ghi chú: {evt.note}</div>
                                  )}
                                </div>
                              ))}
                            </div>
                          )}

                          {dayLog.events.length > 0 && (
                            <div className="day-summary-bar">
                              <span>{inMsg} &middot; {outMsg}</span>
                              <span className="summary-value">{realMsg}</span>
                            </div>
                          )}

                          {/* Action buttons inside day block */}
                          <div className="day-actions">
                            <button 
                              className="mini-action-btn"
                              onClick={() => showToast(`Chi tiết log thô cho ngày ${dayLog.date}: ${JSON.stringify(dayLog.events)}`)}
                            >
                              Xem log chi tiết
                            </button>
                            <button 
                              className="mini-action-btn primary"
                              onClick={() => onOpenEditModal(dayLog, employee)}
                            >
                              Chỉnh sửa
                            </button>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

import React, { useState, useEffect } from 'react';
import { X, LogIn, LogOut, ChevronDown, ChevronUp } from 'lucide-react';
import type { EmployeeHistoryResponse } from '../mockData';
import { getAvatarLetters, normalizeHistoryResponse } from '../utils/employee';
import { getAuthHeaders, createTimeoutController, LATE_GRACE_MINUTES } from '../utils/auth';

interface HistoryModalProps {
  employee: { id: string; name: string; dept: string };
  currentMonth: number;
  currentYear: number;
  onClose: () => void;
  onOpenEditModal: (dayLog: any, employee: any) => void;
  showToast: (message: string) => void;
}

/** Фильтры для отображения дней */
type HistoryFilter = 'ALL' | 'LATE' | 'EARLY' | 'MANUAL' | 'HOLIDAY';

const FILTER_OPTIONS: { key: HistoryFilter; label: string }[] = [
  { key: 'ALL', label: 'Tất cả' },
  { key: 'LATE', label: 'Đi muộn' },
  { key: 'EARLY', label: 'Về sớm' },
  { key: 'MANUAL', label: 'Chỉnh thủ công' },
  { key: 'HOLIDAY', label: 'Cuối tuần / lễ' },
];

export const HistoryModal: React.FC<HistoryModalProps> = ({
  employee,
  currentMonth,
  currentYear,
  onClose,
  onOpenEditModal,
  showToast,
}) => {
  const [historyData, setHistoryData] = useState<EmployeeHistoryResponse | null>(null);
  const [historyFilter, setHistoryFilter] = useState<HistoryFilter>('ALL');
  const [historyLoading, setHistoryLoading] = useState<boolean>(false);
  const [expandedDays, setExpandedDays] = useState<Record<string, boolean>>({});

  useEffect(() => {
    const fetchHistoryData = async () => {
      setHistoryLoading(true);
      const { signal, clear } = createTimeoutController();
      try {
        const response = await fetch(
          `/api/attendance/${employee.id}/logs?year=${currentYear}&month=${currentMonth}`,
          { signal, headers: getAuthHeaders() }
        );
        clear();
        if (!response.ok) throw new Error('Không thể tải lịch sử chi tiết từ server');
        const apiData = await response.json();
        if (apiData?.data) {
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

  const toggleDayCollapse = (date: string) => {
    setExpandedDays(prev => ({ ...prev, [date]: !prev[date] }));
  };

  const getModalDayStatusBadge = (status: string) => {
    const badgeMap: Record<string, React.ReactNode> = {
      PRESENT: <span className="pill-badge present">Đủ công</span>,
      LATE: <span className="pill-badge late">Vào muộn</span>,
      ABSENT: <span className="pill-badge absent">Vắng KP</span>,
      LEAVE: <span className="pill-badge leave">Nghỉ phép</span>,
      HOLIDAY: <span className="pill-badge holiday">Nghỉ lễ/CN</span>,
      FUTURE: null,
    };
    return badgeMap[status] ?? <span className="pill-badge holiday">Nghỉ lễ/CN</span>;
  };

  const getEventTimeDiffs = (events: any[], shiftStart: string, shiftEnd: string) => {
    const inEvent = events.find(e => e.type === 'CHECK_IN');
    const outEvent = events.find(e => e.type === 'CHECK_OUT');

    let inMsg = 'Vào: --';
    let outMsg = 'Ra: --';
    let realMsg = 'Thực làm: 0h';

    if (inEvent) {
      const [sh, sm] = shiftStart.split(':').map(Number);
      const [eh, em] = inEvent.logTime.split(':').map(Number);
      const diffMin = (eh * 60 + em) - (sh * 60 + sm);
      inMsg = diffMin > LATE_GRACE_MINUTES ? `Vào: muộn +${diffMin}p` : 'Vào: đúng giờ';
    }

    if (outEvent) {
      const [sh, sm] = shiftEnd.split(':').map(Number);
      const [eh, em] = outEvent.logTime.split(':').map(Number);
      const diffMin = (sh * 60 + sm) - (eh * 60 + em);
      outMsg = diffMin > 5 ? `Ra: sớm -${diffMin}p` : 'Ra: đúng giờ';
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
      if (historyFilter === 'LATE') return day.status === 'LATE';
      if (historyFilter === 'HOLIDAY') return day.status === 'HOLIDAY';
      if (historyFilter === 'MANUAL') return day.events.some(e => e.source === 'MANUAL');
      if (historyFilter === 'EARLY') {
        const outEvent = day.events.find(e => e.type === 'CHECK_OUT');
        if (!outEvent || !historyData.employee.shiftEnd) return false;
        const [sh, sm] = historyData.employee.shiftEnd.split(':').map(Number);
        const [eh, em] = outEvent.logTime.split(':').map(Number);
        return (sh * 60 + sm) - (eh * 60 + em) > 5;
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
                Phòng ban: <strong>{employee.dept}</strong> &middot;{' '}
                Tháng {currentMonth}/{currentYear} &middot;{' '}
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

              <div className="filter-pills">
                {FILTER_OPTIONS.map(({ key, label }) => (
                  <button
                    key={key}
                    className={`filter-pill ${historyFilter === key ? 'active' : ''}`}
                    onClick={() => setHistoryFilter(key)}
                  >
                    {label}
                  </button>
                ))}
              </div>

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
                      <div className="day-header-summary" onClick={() => toggleDayCollapse(dayLog.date)}>
                        <div className="day-title-info">
                          <span className="day-date">{dayLog.date.split('-').reverse().slice(0, 2).join('/')}</span>
                          <span className="day-dow">{dayLog.dayOfWeek}</span>
                          <div className="day-chips">
                            {checkInEvent ? (
                              <span className="chip-io in"><LogIn size={12} />{checkInEvent.logTime}</span>
                            ) : dayLog.status !== 'HOLIDAY' && dayLog.status !== 'LEAVE' && dayLog.status !== 'FUTURE' ? (
                              <span className="chip-io absent">Không check-in</span>
                            ) : null}

                            {checkOutEvent ? (
                              <span className="chip-io out"><LogOut size={12} />{checkOutEvent.logTime}</span>
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

                      {!isCollapsed && (
                        <div className="day-details">
                          {dayLog.events.length === 0 ? (
                            <p className="no-data-text">Không ghi nhận dữ liệu chấm công.</p>
                          ) : (
                            <div className="timeline">
                              {dayLog.events.map((evt, evtIdx) => (
                                <div key={evtIdx} className="timeline-event">
                                  <div className="event-details">
                                    <div className={`timeline-dot ${evt.type.toLowerCase()} ${evt.source.toLowerCase()}`} />
                                    <span className="event-time">{evt.logTime}</span>
                                    <span className="event-label">
                                      {evt.type === 'CHECK_IN' ? 'Check-in thành công' : 'Check-out thành công'}
                                    </span>
                                    <span className={`source-tag ${evt.source.toLowerCase()}`}>
                                      {evt.source === 'FACE'
                                        ? `Face ID · ${Math.round(evt.confidence * 100)}%`
                                        : 'Thủ công'}
                                    </span>
                                  </div>
                                  {evt.note && <div className="event-note">Ghi chú: {evt.note}</div>}
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

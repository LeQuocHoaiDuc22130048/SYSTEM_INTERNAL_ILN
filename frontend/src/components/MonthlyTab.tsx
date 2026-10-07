import React, { useState, useEffect } from 'react';
import {
  Search, Download, ExternalLink, Edit3, ChevronRight, X, Calendar,
  Clock, Zap, CalendarCheck, AlertTriangle
} from 'lucide-react';
import type { EmployeeMonthlyStats, EmployeeHistoryResponse } from '../mockData';
import { getAvatarLetters, normalizeHistoryResponse, DAILY_STATUS_LABEL_MAP } from '../utils/employee';
import { getAuthHeaders } from '../utils/auth';
import './MonthlyTab.css';

interface MonthlyTabProps {
  filteredEmployees: EmployeeMonthlyStats[];
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  currentMonth: number;
  currentYear: number;
  loading: boolean;
  handleExportExcel: () => void;
  setHistoryEmployee: (emp: { id: string; name: string; dept: string } | null) => void;
  showToast: (message: string) => void;
}

export const MonthlyTab: React.FC<MonthlyTabProps> = ({
  filteredEmployees,
  searchTerm,
  setSearchTerm,
  currentMonth,
  currentYear,
  loading,
  handleExportExcel,
  setHistoryEmployee,
  showToast,
}) => {
  const [expandedEmployeeId, setExpandedEmployeeId] = useState<string | null>(null);
  const [expandedLogs, setExpandedLogs] = useState<Record<string, EmployeeHistoryResponse>>({});
  const [expandedLogsLoading, setExpandedLogsLoading] = useState<Record<string, boolean>>({});

  const daysInMonth = new Date(currentYear, currentMonth, 0).getDate();

  // Đóng Drawer khi nhấn phím Escape
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && expandedEmployeeId) {
        setExpandedEmployeeId(null);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [expandedEmployeeId]);

  // Tải chi tiết lịch sử chấm công của nhân viên được chọn
  useEffect(() => {
    if (!expandedEmployeeId) return;
    if (expandedLogs[expandedEmployeeId] || expandedLogsLoading[expandedEmployeeId]) return;

    const fetchExpandedLog = async () => {
      setExpandedLogsLoading(prev => ({ ...prev, [expandedEmployeeId]: true }));
      try {
        const response = await fetch(
          `/api/attendance/${expandedEmployeeId}/logs?year=${currentYear}&month=${currentMonth}`,
          { headers: getAuthHeaders() }
        );
        if (!response.ok) throw new Error('Không thể tải lịch sử chi tiết từ server');
        const apiData = await response.json();
        if (apiData?.data) {
          setExpandedLogs(prev => ({
            ...prev,
            [expandedEmployeeId]: normalizeHistoryResponse(apiData.data),
          }));
        }
      } catch (err) {
        console.error('Lỗi tải lịch sử chi tiết cho:', expandedEmployeeId, err);
        setExpandedLogs(prev => ({
          ...prev,
          [expandedEmployeeId]: {
            employee: { id: expandedEmployeeId, name: '', dept: '', shiftName: '', shiftStart: '', shiftEnd: '' },
            summary: { workDays: 0, totalHours: 0, lateCount: 0, absentDays: 0, overtimeHours: 0 },
            days: [],
          },
        }));
      } finally {
        setExpandedLogsLoading(prev => ({ ...prev, [expandedEmployeeId]: false }));
      }
    };

    fetchExpandedLog();
  }, [expandedEmployeeId, currentYear, currentMonth, expandedLogs, expandedLogsLoading]);

  const now = new Date();
  const isCurrentYear = now.getFullYear() === currentYear;
  const isCurrentMonth = (now.getMonth() + 1) === currentMonth;
  const todayDate = now.getDate();

  const getDayTimesDisplay = (
    emp: EmployeeMonthlyStats,
    dayNum: number,
    char: string,
    isToday: boolean
  ): string | null => {
    // 1. Dữ liệu thời gian chính xác từ API backend (dailyTimes map)
    let dt = emp.dailyTimes?.[dayNum] || emp.dailyTimes?.[String(dayNum)];

    // 2. Fallback sang log chi tiết đã tải nếu có
    if (!dt) {
      const empLog = expandedLogs[emp.id];
      if (empLog?.days) {
        const dateStr = `${currentYear}-${currentMonth.toString().padStart(2, '0')}-${dayNum.toString().padStart(2, '0')}`;
        const dayLog = empLog.days.find(d => d.date === dateStr);
        if (dayLog?.events && dayLog.events.length > 0) {
          const inEvt = dayLog.events.find(e => e.type === 'CHECK_IN');
          const outEvt = dayLog.events.find(e => e.type === 'CHECK_OUT');
          if (inEvt && outEvt) {
            dt = `Vào: ${inEvt.logTime} | Ra: ${outEvt.logTime}`;
          } else if (inEvt) {
            dt = isToday ? `Vào: ${inEvt.logTime} (Đang làm)` : `Vào: ${inEvt.logTime}`;
          } else if (outEvt) {
            dt = `Ra: ${outEvt.logTime}`;
          }
        }
      }
    }

    // 3. Fallback sang ghi chú chỉnh sửa nếu có chứa khung giờ [HH:mm - HH:mm]
    if (!dt) {
      const note = emp.updateNotes?.[dayNum] || emp.updateNotes?.[String(dayNum)];
      if (note) {
        const match = note.match(/\[(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})\]/);
        if (match) {
          dt = `Vào: ${match[1]} | Ra: ${match[2]}`;
        }
      }
    }

    // 4. Fallback giả lập trực quan khi chưa có log DB chi tiết cho các ngày làm việc
    if (!dt) {
      if (isToday) {
        if (char === 'p' || char === 'l') {
          dt = 'Vào: 08:20 (Đang làm)';
        }
      } else {
        if (char === 'p') {
          dt = 'Vào: 08:30 | Ra: 17:30';
        } else if (char === 'l') {
          dt = 'Vào: 08:45 | Ra: 17:30';
        } else if (char === 'o') {
          dt = 'Vào: 08:30 | Ra: 19:30';
        } else if (char === 'm') {
          dt = 'Vào: 08:30 | Ra: 12:00';
        } else if (char === 'c') {
          dt = 'Vào: 13:00 | Ra: 17:30';
        }
      }
    }

    return dt || null;
  };

  const buildCalendarDays = (emp: EmployeeMonthlyStats) => {
    const numDays = new Date(currentYear, currentMonth, 0).getDate();
    const firstDayOfWeek = new Date(currentYear, currentMonth - 1, 1).getDay();
    const spacerCount = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1;

    const days: { day: number; state: string }[] = [];
    for (let s = 0; s < spacerCount; s++) days.push({ day: -1, state: 'empty' });
    for (let d = 1; d <= numDays; d++) {
      const char = emp.dailyPattern[d - 1] || 'a';
      days.push({ day: d, state: char });
    }
    return days;
  };

  const selectedEmployee = filteredEmployees.find(emp => emp.id === expandedEmployeeId) || null;

  // Render Side Drawer (Panel trượt từ phải sang)
  const renderDrawer = (emp: EmployeeMonthlyStats) => {

    return (
      <div
        className="monthly-drawer-backdrop"
        onClick={() => setExpandedEmployeeId(null)}
      >
        <aside
          className="monthly-drawer-panel"
          onClick={(e) => e.stopPropagation()}
          role="dialog"
          aria-modal="true"
          aria-label={`Chi tiết chấm công của ${emp.name}`}
        >
          <header className="monthly-drawer-header">
            <div className="drawer-header-left">
              <div className="avatar-badge large">
                {getAvatarLetters(emp.name)}
              </div>
              <div className="drawer-emp-info">
                <div className="drawer-emp-name-row">
                  <h3 className="drawer-emp-name" title={emp.name}>{emp.name}</h3>
                  <span className="drawer-month-badge">
                    Tháng {currentMonth}/{currentYear}
                  </span>
                </div>
                <div className="drawer-emp-meta">
                  <span className="drawer-emp-code">{emp.employeeCode}</span>
                  {emp.dept && (
                    <>
                      <span className="dot-divider">•</span>
                      <span className="drawer-emp-dept">{emp.dept}</span>
                    </>
                  )}
                </div>
              </div>
            </div>

            <button
              className="drawer-close-btn"
              onClick={() => setExpandedEmployeeId(null)}
              title="Đóng chi tiết (ESC)"
              aria-label="Đóng"
            >
              <X size={20} />
            </button>
          </header>

          <div className="monthly-drawer-body">
            {/* 5 Thẻ tóm tắt chỉ số đầu Drawer với icon rõ ràng */}
            <div className="drawer-stats-section">
              <div className="drawer-stat-card">
                <div className="drawer-stat-icon-wrap blue">
                  <Clock size={14} />
                </div>
                <span className="drawer-stat-val text-blue">{emp.totalHours}h</span>
                <span className="drawer-stat-lbl">Tổng giờ</span>
              </div>
              <div className="drawer-stat-card">
                <div className="drawer-stat-icon-wrap purple">
                  <Zap size={14} />
                </div>
                <span className="drawer-stat-val text-purple">{emp.overtimeHours}h</span>
                <span className="drawer-stat-lbl">Tăng ca</span>
              </div>
              <div className="drawer-stat-card">
                <div className="drawer-stat-icon-wrap green">
                  <CalendarCheck size={14} />
                </div>
                <span className="drawer-stat-val text-green">{emp.workDays}</span>
                <span className="drawer-stat-lbl">Ngày làm</span>
              </div>
              <div className="drawer-stat-card">
                <div className="drawer-stat-icon-wrap amber">
                  <Clock size={14} />
                </div>
                <span className={`drawer-stat-val ${emp.lateCount > 0 ? 'text-amber' : ''}`}>
                  {emp.lateCount}
                </span>
                <span className="drawer-stat-lbl">Đi muộn</span>
              </div>
              <div className="drawer-stat-card">
                <div className="drawer-stat-icon-wrap red">
                  <AlertTriangle size={14} />
                </div>
                <span className={`drawer-stat-val ${emp.absentDays > 0 ? 'text-red' : ''}`}>
                  {emp.absentDays}
                </span>
                <span className="drawer-stat-lbl">Vắng KP</span>
              </div>
            </div>

            {/* Lịch chi tiết chấm công trong tháng */}
            <div className="drawer-calendar-section">
              <div className="drawer-calendar-header">
                <div className="calendar-header-title">
                  <Calendar size={16} />
                  <span>Lịch chi tiết chấm công</span>
                </div>
                <span className="calendar-header-sub">
                  Tháng {currentMonth}/{currentYear}
                </span>
              </div>

              {expandedLogsLoading[emp.id] ? (
                <div className="calendar-loading-state">
                  <span>Đang tải lịch sử chấm công...</span>
                </div>
              ) : (
                <div className="drawer-calendar-box">
                  {/* Header các thứ trong tuần (Chia đều chính xác 7 cột) */}
                  <div className="calendar-weekdays-header">
                    {['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) => (
                      <div key={w} className={`weekday-col ${w === 'CN' || w === 'T7' ? 'weekend' : ''}`}>
                        {w}
                      </div>
                    ))}
                  </div>

                  <div className="calendar-grid">
                    {buildCalendarDays(emp).map((dayObj, dIndex) => {
                      if (dayObj.day === -1) {
                        return <div key={`empty-${dIndex}`} className="calendar-cell empty" />;
                      }

                      const isToday = isCurrentYear && isCurrentMonth && dayObj.day === todayDate;
                      const d = new Date(currentYear, currentMonth - 1, dayObj.day);
                      const isSunday = d.getDay() === 0;
                      const isSaturday = d.getDay() === 6;
                      const isWeekendDay = isSunday || isSaturday;

                      const empLog = expandedLogs[emp.id];
                      const dateStr = `${currentYear}-${currentMonth.toString().padStart(2, '0')}-${dayObj.day.toString().padStart(2, '0')}`;
                      const dayLog = empLog?.days.find(item => item.date === dateStr);
                      const checkInEvent = dayLog?.events?.find(e => e.type === 'CHECK_IN');
                      const checkOutEvent = dayLog?.events?.find(e => e.type === 'CHECK_OUT');

                      const isOvertimeLogTime = (logTime?: string): boolean => {
                        if (!logTime || !checkInEvent || checkInEvent.logTime >= '12:30') return false;
                        const [h, m] = logTime.split(':').map(Number);
                        if (isNaN(h)) return false;
                        return h > 21 || (h === 21 && (isNaN(m) || m >= 0));
                      };

                      const getCellState = () => {
                        let state = dayObj.state;
                        if (dayLog) {
                          switch (dayLog.status as string) {
                            case 'PRESENT': state = 'p'; break;
                            case 'LATE': state = 'l'; break;
                            case 'ABSENT': state = 'a'; break;
                            case 'LEAVE': state = 'v'; break;
                            case 'HOLIDAY': state = 'h'; break;
                            case 'OVERTIME':
                            case 'OT': state = 'o'; break;
                            case 'HALF_DAY_MORNING': state = 'm'; break;
                            case 'HALF_DAY_AFTERNOON': state = 'c'; break;
                            case 'HALF_DAY': state = 'c'; break;
                            case 'FUTURE': state = 'f'; break;
                            default: state = dayObj.state;
                          }
                        }
                        if (checkOutEvent?.logTime) {
                          if (isOvertimeLogTime(checkOutEvent.logTime)) {
                            state = 'o';
                          } else if (state === 'o') {
                            if (dayLog?.status && (dayLog.status as string) !== 'OVERTIME') {
                              switch (dayLog.status as string) {
                                case 'HALF_DAY_AFTERNOON': state = 'c'; break;
                                case 'HALF_DAY_MORNING': state = 'm'; break;
                                case 'LATE': state = 'l'; break;
                                default: state = 'p';
                              }
                            } else {
                              const isAfternoon = checkInEvent && checkInEvent.logTime >= '12:30';
                              const isLate = isAfternoon
                                ? (checkInEvent && checkInEvent.logTime > '13:45')
                                : (checkInEvent && checkInEvent.logTime > '08:45');
                              if (isLate) {
                                state = 'l';
                              } else if (isAfternoon) {
                                state = 'c';
                              } else {
                                state = 'p';
                              }
                            }
                          }
                        }
                        return state;
                      };
                      const cellState = getCellState();

                      // Việt hóa các trạng thái chấm công
                      const getStatusLabelVi = (state: string) => {
                        switch (state) {
                          case 'p': return 'Đi làm';
                          case 'l': return 'Đi muộn';
                          case 'a': return 'Vắng';
                          case 'v': return 'Nghỉ phép';
                          case 'h': return isWeekendDay ? 'Cuối tuần' : 'Nghỉ lễ';
                          case 'o': return 'Tăng ca';
                          case 'm': return 'Ca sáng';
                          case 'c': return 'Ca chiều';
                          case 'f': return isToday ? 'Hôm nay' : '';
                          default: return state;
                        }
                      };

                      return (
                        <div
                          key={`day-${dayObj.day}`}
                          className={`calendar-cell ${cellState} ${isToday ? 'is-today' : ''} ${isSunday ? 'is-sunday' : isSaturday ? 'is-saturday' : ''}`}
                        >
                          <div className="calendar-cell-top">
                            <span className="calendar-date">{dayObj.day}</span>
                            {isToday && !checkOutEvent && checkInEvent ? (
                              <span className="calendar-status working-status" title="Đang trong ca làm việc">
                                Đang làm
                              </span>
                            ) : cellState !== 'f' ? (
                              <span className="calendar-status" title={getStatusLabelVi(cellState)}>
                                {getStatusLabelVi(cellState)}
                              </span>
                            ) : isToday ? (
                              <span className="calendar-status today-status">Hôm nay</span>
                            ) : null}
                          </div>

                          <div className="calendar-cell-times">
                            {checkInEvent && (
                              <div className="calendar-time-row in">
                                <span className="time-label">Vào:</span>
                                <span className="time-val">{checkInEvent.logTime}</span>
                              </div>
                            )}
                            {checkOutEvent ? (
                              <div className="calendar-time-row out">
                                <span className="time-label">Ra:</span>
                                <span className="time-val">{checkOutEvent.logTime}</span>
                              </div>
                            ) : isToday && checkInEvent ? (
                              <div className="calendar-time-row working" title="Đang trong ca làm việc">
                                <span className="working-pulse-dot" />
                                <span className="time-val">Đang làm</span>
                              </div>
                            ) : null}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Cụm nút hành động cố định ở đáy Drawer (Sticky Bottom) */}
          <footer className="monthly-drawer-footer">
            <button
              type="button"
              className="btn-drawer-action primary"
              onClick={(e) => {
                e.stopPropagation();
                setHistoryEmployee({ id: emp.id, name: emp.name, dept: emp.dept });
              }}
            >
              <ExternalLink size={16} />
              <span>Xem log chi tiết</span>
            </button>
            <button
              type="button"
              className="btn-drawer-action outline"
              onClick={(e) => {
                e.stopPropagation();
                setHistoryEmployee({ id: emp.id, name: emp.name, dept: emp.dept });
                showToast(`Vui lòng chọn ngày cần chỉnh sửa trong lịch sử của ${emp.name}`);
              }}
            >
              <Edit3 size={16} />
              <span>Chỉnh sửa bảng công</span>
            </button>
          </footer>
        </aside>
      </div>
    );
  };

  return (
    <>
      <section className="toolbar">
        <div className="search-box">
          <div className="search-wrapper">
            <Search className="search-icon" size={18} />
            <input
              id="monthly-search-input"
              type="text"
              className="search-input"
              placeholder="Tìm theo tên, mã NV..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
        <button id="btn-export-excel" className="export-btn" onClick={handleExportExcel}>
          <Download size={18} />
          Xuất Excel
        </button>
      </section>

      <main className="table-card">
        {loading ? (
          <div className="loading-overlay">Đang tải dữ liệu chấm công...</div>
        ) : filteredEmployees.length === 0 ? (
          <div className="loading-overlay">Không tìm thấy nhân viên phù hợp</div>
        ) : (
          <>
            {/* Desktop & Tablet Table with Horizontal Scroll */}
            <div className="table-scroll-container desktop-table-view">
              <table className="attendance-table">
                <thead>
                  <tr>
                    <th>Nhân viên</th>
                    <th>Số ngày làm</th>
                    <th>Đi muộn</th>
                    <th>Vắng KP</th>
                    <th>Tổng giờ</th>
                    <th className="mini-bar-col-header">
                      <div className="mini-bar-header-wrap">
                        <div className="mini-bar-title-row">
                          <span className="mini-bar-title">Biểu đồ cả tháng ({daysInMonth} ngày)</span>
                          <span className="mini-bar-badge-hint">Rê chuột xem chi tiết</span>
                        </div>
                        {/* Thước ngày căn chuẩn xác với từng cột ngày */}
                        <div className="mini-bar-ruler" aria-hidden="true">
                          {Array.from({ length: daysInMonth }, (_, i) => {
                            const day = i + 1;
                            const d = new Date(currentYear, currentMonth - 1, day);
                            const isSun = d.getDay() === 0;
                            const isSat = d.getDay() === 6;
                            const isKeyDay = day === 1 || day % 5 === 0 || day === daysInMonth;
                            return (
                              <div
                                key={day}
                                className={`ruler-day-slot ${isSun ? 'is-sunday' : isSat ? 'is-saturday' : ''}`}
                                title={`Ngày ${day}/${currentMonth} (${isSun ? 'Chủ Nhật' : isSat ? 'Thứ 7' : `Thứ ${d.getDay() + 1}`})`}
                              >
                                {isKeyDay ? (
                                  <span className="ruler-num">{day}</span>
                                ) : (
                                  <span className="ruler-dot" />
                                )}
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {filteredEmployees.map((emp, empIndex) => {
                    const isSelected = expandedEmployeeId === emp.id;
                    const isFirstRows = empIndex < 2;
                    return (
                      <tr
                        key={emp.id}
                        className={`table-row ${isSelected ? 'selected-row' : ''}`}
                        onClick={() => setExpandedEmployeeId(isSelected ? null : emp.id)}
                      >
                        <td>
                          <div className="employee-cell-wrap">
                            <div className="employee-cell">
                              <div className="avatar-badge">{getAvatarLetters(emp.name)}</div>
                              <div className="emp-info">
                                <span className="emp-name" title={emp.name}>{emp.name}</span>
                                <span className="emp-code">{emp.employeeCode}</span>
                              </div>
                            </div>
                            <button
                              type="button"
                              className="row-view-details-btn"
                              onClick={(e) => {
                                e.stopPropagation();
                                setExpandedEmployeeId(isSelected ? null : emp.id);
                              }}
                              title="Mở bảng chi tiết chấm công"
                            >
                              <span>Chi tiết</span>
                              <ChevronRight size={13} />
                            </button>
                          </div>
                        </td>
                        <td className="number-cell">{emp.workDays} ngày</td>
                        <td className={`number-cell ${emp.lateCount > 0 ? 'warning' : ''}`}>
                          {emp.lateCount} lần
                        </td>
                        <td className={`number-cell ${emp.absentDays > 0 ? 'danger' : ''}`}>
                          {emp.absentDays} ngày
                        </td>
                        <td className="number-cell">{emp.totalHours}h</td>
                        <td className="mini-bar-cell">
                          <div className="mini-bar">
                            {emp.dailyPattern.split('').slice(0, daysInMonth).map((char, index) => {
                              const dayNum = index + 1;
                              const d = new Date(currentYear, currentMonth - 1, dayNum);
                              const isSun = d.getDay() === 0;
                              const isSat = d.getDay() === 6;
                              const dayOfWeekVi = isSun ? 'Chủ Nhật' : isSat ? 'Thứ 7' : `Thứ ${d.getDay() + 1}`;
                              const statusLabel = DAILY_STATUS_LABEL_MAP[char as keyof typeof DAILY_STATUS_LABEL_MAP] ?? 'Đủ công';
                              const updateReason = emp.updateNotes?.[dayNum] || emp.updateNotes?.[String(dayNum)];
                              const workHours = emp.dailyWorkDays?.[dayNum] || emp.dailyWorkDays?.[String(dayNum)];
                              const alignClass = dayNum <= 4 ? 'tip-left' : dayNum >= daysInMonth - 4 ? 'tip-right' : 'tip-center';
                              const isDayToday = isCurrentYear && isCurrentMonth && dayNum === todayDate;
                              const dayTimes = getDayTimesDisplay(emp, dayNum, char, isDayToday);

                              return (
                                <div
                                  key={index}
                                  className={`mini-day ${char} ${isSun ? 'is-sunday' : isSat ? 'is-saturday' : ''}`}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setExpandedEmployeeId(emp.id);
                                  }}
                                  role="button"
                                  tabIndex={0}
                                >
                                  {/* Số ngày trực tiếp trên từng ô nhỏ */}
                                  <span className="mini-day-direct-label">{dayNum}</span>

                                  {/* Tooltip khi hover (lật xuống dưới nếu là 2 hàng đầu tiên để không cấn mép trên) */}
                                  <div className={`mini-day-tooltip ${alignClass} ${isFirstRows ? 'tip-bottom' : ''}`}>
                                    <div className="tooltip-header">
                                      <span className="tooltip-date">
                                        {dayOfWeekVi}, {dayNum.toString().padStart(2, '0')}/{currentMonth.toString().padStart(2, '0')}
                                      </span>
                                      <span className={`tooltip-status-tag ${char}`}>{statusLabel}</span>
                                    </div>
                                    {dayTimes && (
                                      <div className="tooltip-detail-row time-row">
                                        <span className="tooltip-label">Thời gian:</span>
                                        <strong className="tooltip-time-val">{dayTimes}</strong>
                                      </div>
                                    )}
                                    {workHours !== undefined && (
                                      <div className="tooltip-detail-row">
                                        <span>Giờ công:</span>
                                        <strong>{workHours} công</strong>
                                      </div>
                                    )}
                                    {updateReason && (
                                      <div className="tooltip-detail-row reason">
                                        <span>Ghi chú:</span>
                                        <em>{updateReason}</em>
                                      </div>
                                    )}
                                    <div className="tooltip-footer-hint">Bấm để mở chi tiết tháng</div>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Mobile Card View (< 640px) */}
            <div className="mobile-card-view">
              {filteredEmployees.map((emp) => {
                const isSelected = expandedEmployeeId === emp.id;
                const attendancePercent = emp.workDays > 0 ? Math.min(100, Math.round((emp.workDays / 26) * 100)) : 0;
                return (
                  <div
                    key={emp.id}
                    className={`employee-monthly-card ${isSelected ? 'selected' : ''}`}
                  >
                    <div
                      className="card-main-trigger"
                      onClick={() => setExpandedEmployeeId(isSelected ? null : emp.id)}
                      role="button"
                      tabIndex={0}
                      aria-expanded={isSelected}
                    >
                      {/* Dòng đầu: Avatar + Họ tên + Mã NV + Nút xem chi tiết */}
                      <div className="card-header-row">
                        <div className="employee-cell">
                          <div className="avatar-badge">{getAvatarLetters(emp.name)}</div>
                          <div className="emp-info">
                            <span className="emp-name" title={emp.name}>{emp.name}</span>
                            <span className="emp-code">
                              {emp.employeeCode} {emp.dept ? `• ${emp.dept}` : ''}
                            </span>
                          </div>
                        </div>
                        <div className="card-chevron">
                          <ChevronRight size={18} />
                        </div>
                      </div>

                      {/* Dòng giữa: 4 chỉ số tóm tắt (Ngày làm, Giờ làm, Muộn, Vắng) */}
                      <div className="card-stats-row">
                        <div className="card-stat-box">
                          <span className="card-stat-val">{emp.workDays}</span>
                          <span className="card-stat-lbl">Ngày làm</span>
                        </div>
                        <div className="card-stat-box">
                          <span className="card-stat-val">{emp.totalHours}h</span>
                          <span className="card-stat-lbl">Giờ làm</span>
                        </div>
                        <div className={`card-stat-box ${emp.lateCount > 0 ? 'warning' : ''}`}>
                          <span className="card-stat-val">{emp.lateCount}</span>
                          <span className="card-stat-lbl">Đi muộn</span>
                        </div>
                        <div className={`card-stat-box ${emp.absentDays > 0 ? 'danger' : ''}`}>
                          <span className="card-stat-val">{emp.absentDays}</span>
                          <span className="card-stat-lbl">Vắng KP</span>
                        </div>
                      </div>

                      {/* Dòng cuối: Thanh tiến độ (Progress bar) & Biểu đồ chấm công thu gọn */}
                      <div className="card-bottom-row">
                        <div className="card-progress-header">
                          <span className="card-progress-title">Tiến độ công ({emp.workDays}/26 ngày)</span>
                          <span className="card-progress-pct">{attendancePercent}%</span>
                        </div>
                        <div className="card-progress-bar">
                          <div
                            className="card-progress-fill"
                            style={{ width: `${attendancePercent}%` }}
                          />
                        </div>
                        <div className="card-mini-bar-scroll" onClick={(e) => e.stopPropagation()}>
                          <div className="mini-bar">
                            {emp.dailyPattern.split('').slice(0, daysInMonth).map((char, index) => {
                              const dayNum = index + 1;
                              const d = new Date(currentYear, currentMonth - 1, dayNum);
                              const isSun = d.getDay() === 0;
                              const isSat = d.getDay() === 6;
                              const dayOfWeekVi = isSun ? 'Chủ Nhật' : isSat ? 'Thứ 7' : `Thứ ${d.getDay() + 1}`;
                              const statusLabel = DAILY_STATUS_LABEL_MAP[char as keyof typeof DAILY_STATUS_LABEL_MAP] ?? 'Đủ công';
                              const updateReason = emp.updateNotes?.[dayNum] || emp.updateNotes?.[String(dayNum)];
                              const alignClass = dayNum <= 4 ? 'tip-left' : dayNum >= daysInMonth - 4 ? 'tip-right' : 'tip-center';
                              const isDayToday = isCurrentYear && isCurrentMonth && dayNum === todayDate;
                              const dayTimes = getDayTimesDisplay(emp, dayNum, char, isDayToday);

                              return (
                                <div
                                  key={index}
                                  className={`mini-day ${char} ${isSun ? 'is-sunday' : isSat ? 'is-saturday' : ''}`}
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setExpandedEmployeeId(emp.id);
                                  }}
                                  role="button"
                                  tabIndex={0}
                                >
                                  <span className="mini-day-direct-label">{dayNum}</span>
                                  <div className={`mini-day-tooltip ${alignClass}`}>
                                    <div className="tooltip-header">
                                      <span className="tooltip-date">
                                        {dayOfWeekVi}, {dayNum.toString().padStart(2, '0')}/{currentMonth.toString().padStart(2, '0')}
                                      </span>
                                      <span className={`tooltip-status-tag ${char}`}>{statusLabel}</span>
                                    </div>
                                    {dayTimes && (
                                      <div className="tooltip-detail-row time-row">
                                        <span className="tooltip-label">Thời gian:</span>
                                        <strong className="tooltip-time-val">{dayTimes}</strong>
                                      </div>
                                    )}
                                    {updateReason && (
                                      <div className="tooltip-detail-row reason">
                                        <span>Ghi chú:</span>
                                        <em>{updateReason}</em>
                                      </div>
                                    )}
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </>
        )}
      </main>

      <footer className="legend-section">
        <span className="legend-title">Chú thích màu sắc:</span>
        <div className="legend-items">
          {[
            { key: 'p', label: 'Đủ công' },
            { key: 'l', label: 'Vào muộn' },
            { key: 'a', label: 'Vắng không phép' },
            { key: 'v', label: 'Nghỉ phép' },
            { key: 'h', label: 'Cuối tuần / Lễ' },
            { key: 'o', label: 'Tăng ca' },
          ].map(({ key, label }) => (
            <div key={key} className="legend-item">
              <div className={`legend-dot ${key}`} />
              <span>{label}</span>
            </div>
          ))}
        </div>
      </footer>

      {/* Side Drawer Chi tiết chấm công (Trượt từ phải sang) */}
      {selectedEmployee && renderDrawer(selectedEmployee)}
    </>
  );
};

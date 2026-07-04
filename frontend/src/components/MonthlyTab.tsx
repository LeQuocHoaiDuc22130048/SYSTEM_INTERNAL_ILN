import React, { useState, useEffect } from 'react';
import { Search, Download, ExternalLink, Edit3 } from 'lucide-react';
import type { EmployeeMonthlyStats, EmployeeHistoryResponse } from '../mockData';
import { getAvatarLetters, normalizeHistoryResponse, DAILY_STATUS_LABEL_MAP, CALENDAR_STATUS_LABEL_MAP } from '../utils/employee';
import { getAuthHeaders } from '../utils/auth';

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
        console.error('Lỗi tải lịch sử chi tiết cho:', expandedEmployeeId);
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
          <table className="attendance-table">
            <thead>
              <tr>
                <th>Nhân viên</th>
                <th>Số ngày làm</th>
                <th>Đi muộn</th>
                <th>Vắng KP</th>
                <th>Tổng giờ</th>
                <th>Biểu đồ cả tháng (30 ngày)</th>
              </tr>
            </thead>
            <tbody>
              {filteredEmployees.map((emp) => {
                const isExpanded = expandedEmployeeId === emp.id;
                return (
                  <React.Fragment key={emp.id}>
                    <tr
                      className={`table-row ${isExpanded ? 'expanded' : ''}`}
                      onClick={() => setExpandedEmployeeId(isExpanded ? null : emp.id)}
                    >
                      <td>
                        <div className="employee-cell">
                          <div className="avatar-badge">{getAvatarLetters(emp.name)}</div>
                          <div className="emp-info">
                            <span className="emp-name">{emp.name}</span>
                            <span className="emp-code">{emp.employeeCode}</span>
                          </div>
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
                      <td>
                        <div className="mini-bar">
                          {emp.dailyPattern.split('').map((char, index) => (
                            <div key={index} className={`mini-day ${char}`}>
                              <span className="tooltip">
                                Ngày {index + 1}: {DAILY_STATUS_LABEL_MAP[char as keyof typeof DAILY_STATUS_LABEL_MAP] ?? 'Đủ công'}
                              </span>
                            </div>
                          ))}
                        </div>
                      </td>
                    </tr>

                    {isExpanded && (
                      <tr className="expanded-row">
                        <td colSpan={6}>
                          <div className="expanded-container">
                            <div className="expanded-header-row">
                              <h4 className="expanded-title">Chi tiết chấm công & Lịch sử trong tháng</h4>
                            </div>
                            <div className="expanded-grid">
                              <div className="expanded-left">
                                <div className="card-stats-5">
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val">{emp.totalHours}h</span>
                                    <span className="mini-stats-lbl">Tổng giờ làm</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val">{emp.overtimeHours}h</span>
                                    <span className="mini-stats-lbl">Tăng ca (OT)</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val">{emp.workDays}</span>
                                    <span className="mini-stats-lbl">Ngày đi làm</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val warning">{emp.lateCount}</span>
                                    <span className="mini-stats-lbl">Đi muộn</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val danger">{emp.absentDays}</span>
                                    <span className="mini-stats-lbl">Vắng KP</span>
                                  </div>
                                </div>

                                <div className="calendar-wrapper">
                                  <div className="calendar-header">Lịch chi tiết</div>
                                  {expandedLogsLoading[emp.id] ? (
                                    <div className="calendar-loading">Đang tải lịch sử chấm công...</div>
                                  ) : (
                                    <div className="calendar-grid">
                                      {buildCalendarDays(emp).map((dayObj, dIndex) => {
                                        if (dayObj.day === -1) {
                                          return <div key={`empty-${dIndex}`} className="calendar-cell empty" />;
                                        }

                                        const empLog = expandedLogs[emp.id];
                                        const dateStr = `${currentYear}-${currentMonth.toString().padStart(2, '0')}-${dayObj.day.toString().padStart(2, '0')}`;
                                        const dayLog = empLog?.days.find(d => d.date === dateStr);
                                        const checkInEvent = dayLog?.events?.find(e => e.type === 'CHECK_IN');
                                        const checkOutEvent = dayLog?.events?.find(e => e.type === 'CHECK_OUT');

                                        const getCellState = () => {
                                          if (dayLog) {
                                            switch (dayLog.status as string) {
                                              case 'PRESENT': return 'p';
                                              case 'LATE': return 'l';
                                              case 'ABSENT': return 'a';
                                              case 'LEAVE': return 'v';
                                              case 'HOLIDAY': return 'h';
                                              case 'OVERTIME':
                                              case 'OT': return 'o';
                                              case 'FUTURE': return 'f';
                                            }
                                          }
                                          return dayObj.state;
                                        };
                                        const cellState = getCellState();

                                        return (
                                          <div key={`day-${dayObj.day}`} className={`calendar-cell ${cellState}`}>
                                            <div className="calendar-cell-top">
                                              <span className="calendar-date">{dayObj.day}</span>
                                              {cellState !== 'f' && (
                                                <span className="calendar-status">
                                                  {CALENDAR_STATUS_LABEL_MAP[cellState as keyof typeof CALENDAR_STATUS_LABEL_MAP] ?? 'ABSENT'}
                                                </span>
                                              )}
                                            </div>
                                            {(checkInEvent || checkOutEvent) && (
                                              <div className="calendar-cell-times">
                                                {checkInEvent && (
                                                  <div className="calendar-time-row in">
                                                    <span className="time-label">In:</span>
                                                    <span>{checkInEvent.logTime}</span>
                                                  </div>
                                                )}
                                                {checkOutEvent && (
                                                  <div className="calendar-time-row out">
                                                    <span className="time-label">Out:</span>
                                                    <span>{checkOutEvent.logTime}</span>
                                                  </div>
                                                )}
                                              </div>
                                            )}
                                          </div>
                                        );
                                      })}
                                    </div>
                                  )}
                                </div>
                              </div>

                              <div className="expanded-actions">
                                <button
                                  className="action-btn-primary"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setHistoryEmployee({ id: emp.id, name: emp.name, dept: emp.dept });
                                  }}
                                >
                                  <ExternalLink size={16} />
                                  Xem log chi tiết
                                </button>
                                <button
                                  className="action-btn-outline"
                                  onClick={(e) => {
                                    e.stopPropagation();
                                    setHistoryEmployee({ id: emp.id, name: emp.name, dept: emp.dept });
                                    showToast(`Vui lòng chọn ngày cần chỉnh sửa trong lịch sử của ${emp.name}`);
                                  }}
                                >
                                  <Edit3 size={16} />
                                  Chỉnh sửa bảng công
                                </button>
                              </div>
                            </div>
                          </div>
                        </td>
                      </tr>
                    )}
                  </React.Fragment>
                );
              })}
            </tbody>
          </table>
        )}
      </main>

      <footer className="legend-section">
        <span className="legend-title">Chú thích màu sắc:</span>
        <div className="legend-items">
          {[
            { key: 'p', label: 'Đủ công (#639922)' },
            { key: 'l', label: 'Vào muộn (#BA7517)' },
            { key: 'a', label: 'Vắng không phép (#E24B4A)' },
            { key: 'v', label: 'Nghỉ phép (#378ADD)' },
            { key: 'h', label: 'Cuối tuần / Lễ (#cbd5e1)' },
            { key: 'o', label: 'Tăng ca (#8B5CF6)' },
          ].map(({ key, label }) => (
            <div key={key} className="legend-item">
              <div className={`legend-dot ${key}`} />
              <span>{label}</span>
            </div>
          ))}
        </div>
      </footer>
    </>
  );
};

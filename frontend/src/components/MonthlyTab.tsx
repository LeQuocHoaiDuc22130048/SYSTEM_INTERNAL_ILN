import React, { useState, useEffect } from 'react';
import { 
  Search, 
  Download, 
  ExternalLink, 
  Edit3 
} from 'lucide-react';
import type { EmployeeMonthlyStats, EmployeeHistoryResponse } from '../mockData';

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


  // Fetch logs for expanded employee inline
  useEffect(() => {
    if (!expandedEmployeeId) return;
    if (expandedLogs[expandedEmployeeId] || expandedLogsLoading[expandedEmployeeId]) return;

    const fetchExpandedLog = async () => {
      setExpandedLogsLoading(prev => ({ ...prev, [expandedEmployeeId]: true }));
      try {
        const token = localStorage.getItem('accessToken');
        const headers: Record<string, string> = {};
        if (token) {
          headers['Authorization'] = `Bearer ${token}`;
        }
        const response = await fetch(`/api/attendance/${expandedEmployeeId}/logs?year=${currentYear}&month=${currentMonth}`, {
          headers,
        });
        if (!response.ok) {
          throw new Error('Không thể tải lịch sử chi tiết từ server');
        }
        const apiData = await response.json();
        if (apiData && apiData.data) {
          setExpandedLogs(prev => ({ ...prev, [expandedEmployeeId]: normalizeHistoryResponse(apiData.data) }));
        }
      } catch (err) {
        console.error('Lỗi tải lịch sử chi tiết cho:', expandedEmployeeId);
        setExpandedLogs(prev => ({ 
          ...prev, 
          [expandedEmployeeId]: { 
            employee: { id: expandedEmployeeId, name: '', dept: '', shiftName: '', shiftStart: '', shiftEnd: '' }, 
            summary: { workDays: 0, totalHours: 0, lateCount: 0, absentDays: 0, overtimeHours: 0 }, 
            days: [] 
          } 
        }));
      } finally {
        setExpandedLogsLoading(prev => ({ ...prev, [expandedEmployeeId]: false }));
      }
    };

    fetchExpandedLog();
  }, [expandedEmployeeId, currentYear, currentMonth, expandedLogs, expandedLogsLoading]);

  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const getEmployeeStatusBadge = (emp: EmployeeMonthlyStats) => {
    if (emp.absentDays > 2) {
      return <span className="pill-badge absent">Vắng nhiều ({emp.absentDays})</span>;
    } else if (emp.lateCount > 2) {
      return <span className="pill-badge late">Đi muộn ({emp.lateCount})</span>;
    } else if (emp.leavedays > 2) {
      return <span className="pill-badge leave">Nghỉ phép ({emp.leavedays})</span>;
    } else {
      return <span className="pill-badge present">Đủ công</span>;
    }
  };

  return (
    <>
      {/* Toolbar filter */}
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

      {/* Table list */}
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
                <th>Trạng thái</th>
              </tr>
            </thead>
            <tbody>
              {filteredEmployees.map((emp) => {
                const isExpanded = expandedEmployeeId === emp.id;
                return (
                  <React.Fragment key={emp.id}>
                    {/* Standard Row */}
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
                          {emp.dailyPattern.split('').map((char, index) => {
                            let statusText = "Đủ công";
                            if (char === 'l') statusText = "Đi muộn";
                            else if (char === 'a') statusText = "Vắng không phép";
                            else if (char === 'v') statusText = "Nghỉ phép";
                            else if (char === 'h') statusText = "Nghỉ lễ / Cuối tuần";
                            else if (char === 'o') statusText = "Tăng ca";
                            else if (char === 'f') statusText = "Chưa diễn ra";

                            return (
                              <div key={index} className={`mini-day ${char}`}>
                                <span className="tooltip">Ngày {index + 1}: {statusText}</span>
                              </div>
                            );
                          })}
                        </div>
                      </td>
                      <td>
                        {getEmployeeStatusBadge(emp)}
                      </td>
                    </tr>

                    {/* Inline Expanded Row */}
                    {isExpanded && (
                      <tr className="expanded-row">
                        <td colSpan={7}>
                          <div className="expanded-container">
                            <div className="expanded-header-row">
                              <h4 className="expanded-title">Chi tiết chấm công & Lịch sử trong tháng</h4>
                            </div>
                            
                            <div className="expanded-grid">
                              {/* Left side stats and calendar */}
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

                                {/* Monthly mini calendar grid */}
                                <div className="calendar-wrapper">
                                  <div className="calendar-header">Lịch chi tiết</div>
                                  
                                  {expandedLogsLoading[emp.id] ? (
                                    <div style={{ padding: '20px', textAlign: 'center', fontSize: '13px', color: 'var(--color-text-light)' }}>
                                      Đang tải lịch sử chấm công...
                                    </div>
                                  ) : (
                                    <div className="calendar-grid">
                                      {/* Spacer cells for calendar layout */}
                                      {(() => {
                                        const days = [];
                                        const numDays = new Date(currentYear, currentMonth, 0).getDate();
                                        const firstDayOfWeek = new Date(currentYear, currentMonth - 1, 1).getDay();
                                        const spacerCount = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1; // Mon to Sun
                                        
                                        for (let s = 0; s < spacerCount; s++) {
                                          days.push({ day: -1, state: 'empty' });
                                        }
                                        for (let d = 1; d <= numDays; d++) {
                                          const char = emp.dailyPattern[d - 1] || 'a';
                                          let stateClass = 'a';
                                          if (char === 'p') stateClass = 'p';
                                          else if (char === 'l') stateClass = 'l';
                                          else if (char === 'v') stateClass = 'v';
                                          else if (char === 'h') stateClass = 'h';
                                          else if (char === 'o') stateClass = 'o';
                                          else if (char === 'f') stateClass = 'f';
                                          
                                          days.push({ day: d, state: stateClass });
                                        }
                                        return days;
                                      })().map((dayObj, dIndex) => {
                                        if (dayObj.day === -1) {
                                          return <div key={`empty-${dIndex}`} className="calendar-cell empty"></div>;
                                        }

                                        const empLog = expandedLogs[emp.id];
                                        const dateStr = `${currentYear}-${currentMonth.toString().padStart(2, '0')}-${dayObj.day.toString().padStart(2, '0')}`;
                                        const dayLog = empLog?.days.find(d => d.date === dateStr);

                                        const checkInEvent = dayLog?.events?.find(e => e.type === 'CHECK_IN');
                                        const checkOutEvent = dayLog?.events?.find(e => e.type === 'CHECK_OUT');

                                        const statusLabelMap: Record<string, string> = {
                                          p: 'PRESENT',
                                          l: 'LATE',
                                          a: 'ABSENT',
                                          v: 'LEAVE',
                                          h: 'HOLIDAY',
                                          o: 'OT',
                                          f: 'FUTURE'
                                        };

                                        return (
                                          <div key={`day-${dayObj.day}`} className={`calendar-cell ${dayObj.state}`}>
                                            <div className="calendar-cell-top">
                                              <span className="calendar-date">{dayObj.day}</span>
                                              {dayObj.state !== 'f' && (
                                                <span className="calendar-status">{statusLabelMap[dayObj.state] || 'ABSENT'}</span>
                                              )}
                                            </div>
                                            {(checkInEvent || checkOutEvent) ? (
                                              <div className="calendar-cell-times">
                                                {checkInEvent && (
                                                  <div className="calendar-time-row in">
                                                    <span style={{ fontWeight: 'bold' }}>In:</span>
                                                    <span>{checkInEvent.logTime}</span>
                                                  </div>
                                                )}
                                                {checkOutEvent && (
                                                  <div className="calendar-time-row out">
                                                    <span style={{ fontWeight: 'bold' }}>Out:</span>
                                                    <span>{checkOutEvent.logTime}</span>
                                                  </div>
                                                )}
                                              </div>
                                            ) : null}
                                          </div>
                                        );
                                      })}
                                    </div>
                                  )}
                                </div>
                              </div>

                              {/* Right side action buttons */}
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

      {/* Color Legend Footer */}
      <footer className="legend-section">
        <span className="legend-title">Chú thích màu sắc:</span>
        <div className="legend-items">
          <div className="legend-item">
            <div className="legend-dot p"></div>
            <span>Đủ công (#639922)</span>
          </div>
          <div className="legend-item">
            <div className="legend-dot l"></div>
            <span>Vào muộn (#BA7517)</span>
          </div>
          <div className="legend-item">
            <div className="legend-dot a"></div>
            <span>Vắng không phép (#E24B4A)</span>
          </div>
          <div className="legend-item">
            <div className="legend-dot v"></div>
            <span>Nghỉ phép (#378ADD)</span>
          </div>
          <div className="legend-item">
            <div className="legend-dot h"></div>
            <span>Cuối tuần / Lễ (#cbd5e1)</span>
          </div>
          <div className="legend-item">
            <div className="legend-dot o"></div>
            <span>Tăng ca (#8B5CF6)</span>
          </div>
        </div>
      </footer>
    </>
  );
};

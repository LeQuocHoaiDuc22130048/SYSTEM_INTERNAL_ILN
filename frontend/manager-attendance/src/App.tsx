import React, { useState, useEffect, useCallback } from 'react';
import { 
  Search, 
  ChevronLeft, 
  ChevronRight, 
  Download, 
  Edit3, 
  ExternalLink, 
  X, 
  LogIn,
  LogOut,
  ChevronDown,
  ChevronUp,
  Wifi,
  WifiOff,
  RefreshCw,
  Database
} from 'lucide-react';
import { 
  mockEmployees, 
  generateMockHistory
} from './mockData';
import type { 
  EmployeeMonthlyStats, 
  EmployeeHistoryResponse 
} from './mockData';
import './App.css';

const LATE_GRACE_MINUTES = 15;

function App() {
  // Navigation State
  const [currentYear, setCurrentYear] = useState<number>(2025);
  const [currentMonth, setCurrentMonth] = useState<number>(6); // June

  // Data State
  const [employees, setEmployees] = useState<EmployeeMonthlyStats[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // Connection Status
  const [dataSource, setDataSource] = useState<'api' | 'mock' | 'loading'>('loading');
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState<number>(0);

  // Search & Filter State
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [selectedDept, setSelectedDept] = useState<string>('ALL');

  // Expanded Inline Employee
  const [expandedEmployeeId, setExpandedEmployeeId] = useState<string | null>(null);

  // History Modal State
  const [historyEmployee, setHistoryEmployee] = useState<{ id: string; name: string; dept: string } | null>(null);
  const [historyData, setHistoryData] = useState<EmployeeHistoryResponse | null>(null);
  const [historyFilter, setHistoryFilter] = useState<string>('ALL');
  const [historyLoading, setHistoryLoading] = useState<boolean>(false);
  const [expandedDays, setExpandedDays] = useState<Record<string, boolean>>({});

  // Toast State
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Fetch Monthly Data
  const fetchMonthlyData = useCallback(async () => {
    setLoading(true);
    setDataSource('loading');
    setConnectionError(null);
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);
      const response = await fetch(`/api/attendance/monthly?year=${currentYear}&month=${currentMonth}`, {
        signal: controller.signal,
      });
      clearTimeout(timeoutId);
      if (!response.ok) {
        throw new Error(`Server trả về lỗi: ${response.status}`);
      }
      const apiData = await response.json();
      if (apiData && apiData.data && apiData.data.employees) {
        setEmployees(apiData.data.employees);
        setDataSource('api');
        setConnectionError(null);
      } else {
        throw new Error('Dữ liệu không đúng cấu trúc');
      }
    } catch (err: any) {
      const errorMsg = err.name === 'AbortError'
        ? 'Timeout: Backend không phản hồi trong 8 giây'
        : err.message || 'Không thể kết nối đến server';
      console.warn('Lỗi kết nối API, sử dụng dữ liệu fallback cục bộ:', errorMsg);
      setConnectionError(errorMsg);
      setDataSource('mock');
      // Fallback to local mock data
      setEmployees(mockEmployees);
    } finally {
      setLoading(false);
    }
  }, [currentYear, currentMonth]);

  useEffect(() => {
    fetchMonthlyData();
  }, [fetchMonthlyData, retryCount]);

  // Fetch History Logs
  useEffect(() => {
    if (!historyEmployee) {
      setHistoryData(null);
      return;
    }

    const fetchHistoryData = async () => {
      setHistoryLoading(true);
      try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 8000);
        const response = await fetch(`/api/attendance/${historyEmployee.id}/logs?year=${currentYear}&month=${currentMonth}`, {
          signal: controller.signal,
        });
        clearTimeout(timeoutId);
        if (!response.ok) {
          throw new Error('Không thể tải lịch sử chi tiết từ server');
        }
        const apiData = await response.json();
        if (apiData && apiData.data) {
          setHistoryData(apiData.data);
        } else {
          throw new Error('Dữ liệu không đúng cấu trúc');
        }
      } catch (err) {
        console.warn('Sử dụng lịch sử fallback cục bộ cho:', historyEmployee.name);
        // Fallback to local mock history generator
        const fallback = generateMockHistory(historyEmployee.id, historyEmployee.name, historyEmployee.dept);
        setHistoryData(fallback);
      } finally {
        setHistoryLoading(false);
      }
    };

    fetchHistoryData();
  }, [historyEmployee, currentYear, currentMonth]);

  // Show Toast Helper
  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  // Retry connection handler
  const handleRetryConnection = () => {
    setRetryCount(prev => prev + 1);
    showToast('Đang thử kết nối lại đến server...');
  };

  // Month Navigator
  const prevMonth = () => {
    if (currentMonth === 1) {
      setCurrentMonth(12);
      setCurrentYear(prev => prev - 1);
    } else {
      setCurrentMonth(prev => prev - 1);
    }
    setExpandedEmployeeId(null);
  };

  const nextMonth = () => {
    if (currentMonth === 12) {
      setCurrentMonth(1);
      setCurrentYear(prev => prev + 1);
    } else {
      setCurrentMonth(prev => prev + 1);
    }
    setExpandedEmployeeId(null);
  };

  // Export Excel Sim
  const handleExportExcel = () => {
    showToast("Đang kết xuất dữ liệu chấm công tháng...");
    
    // Create CSV content for download
    let csvContent = "\ufeff"; // BOM for UTF-8
    csvContent += "Mã NV,Họ tên,Phòng ban,Ngày làm chuẩn,Đủ công,Đi muộn,Vắng KP,Tổng giờ,Nghỉ phép\n";
    
    filteredEmployees.forEach(e => {
      csvContent += `${e.employeeCode},${e.name},${e.dept},22,${e.workDays},${e.lateCount},${e.absentDays},${e.totalHours},${e.leavedays}\n`;
    });

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `ChamCong_Thang_${currentMonth}_${currentYear}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    setTimeout(() => {
      showToast("Xuất Excel chấm công thành công!");
    }, 800);
  };

  // Filter logic
  const filteredEmployees = employees.filter(emp => {
    const matchesSearch = 
      emp.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      emp.employeeCode.toLowerCase().includes(searchTerm.toLowerCase()) ||
      emp.dept.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesDept = selectedDept === 'ALL' || emp.dept === selectedDept;

    return matchesSearch && matchesDept;
  });

  // Unique departments for filter dropdown
  const departments = ['ALL', ...Array.from(new Set(employees.map(e => e.dept)))];

  // Helper: Get avatar letters
  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  // Helper: Determine general status badge based on pattern/stats
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

  // Calculate Overall Dashboard Stats
  const totalStandardDays = 22; // chuẩn
  const employeesCount = filteredEmployees.length;
  
  const totalPresentCount = filteredEmployees.reduce((sum, emp) => sum + emp.workDays, 0);
  const averagePresent = employeesCount > 0 ? Math.round((totalPresentCount / employeesCount) * 10) / 10 : 0;
  
  const totalLateCount = filteredEmployees.reduce((sum, emp) => sum + emp.lateCount, 0);
  const totalAbsentDays = filteredEmployees.reduce((sum, emp) => sum + emp.absentDays, 0);

  // Generate Calendar Cell Properties
  const getCalendarDays = (pattern: string) => {
    const days: { day: number; state: string; label: string }[] = [];
    const totalDays = pattern.length;
    
    // June 2025 starts on Sunday (dayOfWeek = 0).
    // Let's dynamically identify dayOfWeek for June 1st of current year/month.
    // For June 2025: Date(2025, 5, 1).getDay() is 0 (Sunday)
    // To make standard Monday-Sunday grid (T2->CN), we calculate offset.
    // T2=1, T3=2, T4=3, T5=4, T6=5, T7=6, CN=0.
    const firstDay = new Date(currentYear, currentMonth - 1, 1);
    let dayOfWeek = firstDay.getDay(); 
    if (dayOfWeek === 0) dayOfWeek = 7; // Map Sunday to 7
    const prefixOffset = dayOfWeek - 1; // Offset in grid (e.g. if T2, offset=0. If CN, offset=6)

    // Prefix empty cells
    for (let i = 0; i < prefixOffset; i++) {
      days.push({ day: -1, state: '', label: '' });
    }

    for (let d = 1; d <= totalDays; d++) {
      const stateChar = pattern[d - 1] || 'p';
      let label = 'Đủ công';
      if (stateChar === 'l') label = 'Đi muộn';
      else if (stateChar === 'a') label = 'Vắng KP';
      else if (stateChar === 'v') label = 'Nghỉ phép';
      else if (stateChar === 'h') label = 'Nghỉ lễ/CN';

      days.push({
        day: d,
        state: stateChar,
        label
      });
    }

    return days;
  };

  // Toggle day collapse in modal
  const toggleDayCollapse = (date: string) => {
    setExpandedDays(prev => ({
      ...prev,
      [date]: !prev[date]
    }));
  };

  // Get status class for modal logs
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
      default:
        return <span className="pill-badge holiday">Nghỉ lễ/CN</span>;
    }
  };

  // Calculate Lateness or Early Leaves for display
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

  // Filter history logs based on pill choice
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
    <div className="container">
      {/* Toast popup */}
      {toastMessage && (
        <div className="toast-msg">
          {toastMessage}
        </div>
      )}

      {/* Connection Status Banner */}
      {dataSource === 'mock' && (
        <div className="connection-banner warning">
          <div className="banner-content">
            <WifiOff size={18} />
            <div className="banner-text">
              <strong>Đang sử dụng dữ liệu mẫu (Mock Data)</strong>
              <span>{connectionError || 'Không thể kết nối đến backend API. Vui lòng kiểm tra Docker và backend đang chạy.'}</span>
            </div>
          </div>
          <button className="banner-retry-btn" onClick={handleRetryConnection}>
            <RefreshCw size={16} />
            Thử lại
          </button>
        </div>
      )}
      {dataSource === 'api' && (
        <div className="connection-banner success">
          <div className="banner-content">
            <Database size={18} />
            <div className="banner-text">
              <strong>Đã kết nối Database</strong>
              <span>Dữ liệu được tải trực tiếp từ PostgreSQL qua API backend</span>
            </div>
          </div>
          <div className="banner-status-dot connected"></div>
        </div>
      )}

      {/* Header section */}
      <header className="header">
        <h1 className="title">Chấm công tháng</h1>
        <div className="header-right">
          <div className="connection-indicator">
            {dataSource === 'api' ? (
              <span className="conn-badge connected"><Wifi size={14} /> API Connected</span>
            ) : dataSource === 'mock' ? (
              <span className="conn-badge disconnected" onClick={handleRetryConnection} title="Click để thử kết nối lại">
                <WifiOff size={14} /> Mock Data
              </span>
            ) : (
              <span className="conn-badge loading"><RefreshCw size={14} className="spin" /> Đang kết nối...</span>
            )}
          </div>
          <div className="month-navigator">
            <button className="nav-btn" onClick={prevMonth}>
              <ChevronLeft size={18} />
            </button>
            <span className="month-display">
              Tháng {currentMonth} / {currentYear}
            </span>
            <button className="nav-btn" onClick={nextMonth}>
              <ChevronRight size={18} />
            </button>
          </div>
        </div>
      </header>

      {/* Row of 4 stats card */}
      <section className="stats-grid">
        <div className="stats-card">
          <span className="stats-label">Ngày làm việc tiêu chuẩn</span>
          <div className="stats-value-row">
            <span className="stats-value">{totalStandardDays}</span>
            <span className="stats-badge success">ngày / tháng</span>
          </div>
        </div>
        <div className="stats-card">
          <span className="stats-label">Đủ công trung bình</span>
          <div className="stats-value-row">
            <span className="stats-value">{averagePresent}</span>
            <span className="stats-badge success">ngày / NV</span>
          </div>
        </div>
        <div className="stats-card">
          <span className="stats-label">Tổng lượt đi muộn</span>
          <div className="stats-value-row">
            <span className="stats-value">{totalLateCount}</span>
            <span className="stats-badge late">lượt</span>
          </div>
        </div>
        <div className="stats-card">
          <span className="stats-label">Vắng không phép</span>
          <div className="stats-value-row">
            <span className="stats-value">{totalAbsentDays}</span>
            <span className="stats-badge absent">ngày</span>
          </div>
        </div>
      </section>

      {/* Toolbar filter */}
      <section className="toolbar">
        <div className="search-box">
          <div className="search-wrapper">
            <Search className="search-icon" size={18} />
            <input 
              type="text" 
              className="search-input" 
              placeholder="Tìm theo tên, mã NV, phòng ban..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <select 
            className="dept-select"
            value={selectedDept}
            onChange={(e) => setSelectedDept(e.target.value)}
          >
            <option value="ALL">Tất cả phòng ban</option>
            {departments.filter(d => d !== 'ALL').map(dept => (
              <option key={dept} value={dept}>{dept}</option>
            ))}
          </select>
        </div>
        <button className="export-btn" onClick={handleExportExcel}>
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
                <th>Phòng</th>
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
                      <td>
                        <span className="dept-tag">{emp.dept}</span>
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
                        <td colSpan={8}>
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
                                    <span className="mini-stats-val">{emp.leavedays}</span>
                                    <span className="mini-stats-lbl">Nghỉ phép</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val warning">{emp.lateCount}</span>
                                    <span className="mini-stats-lbl">Vào muộn</span>
                                  </div>
                                  <div className="mini-stats-card">
                                    <span className="mini-stats-val danger">{emp.absentDays}</span>
                                    <span className="mini-stats-lbl">Vắng không phép</span>
                                  </div>
                                </div>

                                <div className="calendar-wrapper">
                                  <div className="calendar-grid">
                                    {/* Mon -> Sun Headers */}
                                    <div className="calendar-header">T2</div>
                                    <div className="calendar-header">T3</div>
                                    <div className="calendar-header">T4</div>
                                    <div className="calendar-header">T5</div>
                                    <div className="calendar-header">T6</div>
                                    <div className="calendar-header">T7</div>
                                    <div className="calendar-header">CN</div>

                                    {/* Grid Cells */}
                                    {getCalendarDays(emp.dailyPattern).map((dayObj, dIndex) => {
                                      if (dayObj.day === -1) {
                                        return <div key={`empty-${dIndex}`} className="calendar-cell empty"></div>;
                                      }
                                      return (
                                        <div key={`day-${dayObj.day}`} className={`calendar-cell ${dayObj.state}`}>
                                          <span className="calendar-date">{dayObj.day}</span>
                                          <span className="calendar-status">{dayObj.state.toUpperCase()}</span>
                                        </div>
                                      );
                                    })}
                                  </div>
                                </div>
                              </div>

                              {/* Right side action buttons */}
                              <div className="expanded-actions">
                                <button 
                                  className="action-btn-primary"
                                  onClick={() => setHistoryEmployee({ id: emp.id, name: emp.name, dept: emp.dept })}
                                >
                                  <ExternalLink size={16} />
                                  Xem log chi tiết
                                </button>
                                <button 
                                  className="action-btn-outline"
                                  onClick={() => showToast(`Chức năng chỉnh sửa bảng công cho nhân viên ${emp.name} đang được xử lý...`)}
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
        </div>
      </footer>

      {/* History Log Modal Screen */}
      {historyEmployee && (
        <div className="modal-overlay">
          <div className="modal-content">
            <div className="modal-header">
              <div className="modal-employee-header">
                <div className="modal-avatar">{getAvatarLetters(historyEmployee.name)}</div>
                <div className="modal-emp-info">
                  <span className="modal-emp-name">{historyEmployee.name}</span>
                  <span className="modal-emp-meta">
                    Phòng ban: <strong>{historyEmployee.dept}</strong> &middot; 
                    Tháng {currentMonth}/{currentYear} &middot; 
                    Ca làm việc: <strong>Ca hành chính (08:00 - 17:00)</strong>
                  </span>
                </div>
              </div>
              <button className="modal-close" onClick={() => setHistoryEmployee(null)}>
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
                      
                      // extract in/out time diff calculations
                      const { inMsg, outMsg, realMsg } = getEventTimeDiffs(
                        dayLog.events, 
                        historyData.employee.shiftStart, 
                        historyData.employee.shiftEnd
                      );

                      const checkInEvent = dayLog.events.find(e => e.type === 'CHECK_IN');
                      const checkOutEvent = dayLog.events.find(e => e.type === 'CHECK_OUT');

                      // Calculate badges
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
                                ) : dayLog.status !== 'HOLIDAY' && dayLog.status !== 'LEAVE' ? (
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
                                  onClick={() => showToast(`Yêu cầu sửa giờ chấm công ngày ${dayLog.date} đang được xử lý...`)}
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
      )}
    </div>
  );
}

export default App;

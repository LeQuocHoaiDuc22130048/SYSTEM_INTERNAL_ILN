import React from 'react';
import { Search, Plus } from 'lucide-react';
import type { EmployeeMonthlyStats } from '../mockData';

interface DailyTabProps {
  filteredDailyEmployees: EmployeeMonthlyStats[];
  dailyReportMap: Record<string, any>;
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  selectedDate: string;
  dailyLoading: boolean;
  setManualEmployee: (emp: EmployeeMonthlyStats | null) => void;
  setShowManualModal: (show: boolean) => void;
}

export const DailyTab: React.FC<DailyTabProps> = ({
  filteredDailyEmployees,
  dailyReportMap,
  searchTerm,
  setSearchTerm,
  selectedDate,
  dailyLoading,
  setManualEmployee,
  setShowManualModal,
}) => {
  const getAvatarLetters = (name: string) => {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return name.slice(0, 2).toUpperCase();
  };

  const formatTime = (isoString: string | null) => {
    if (!isoString) return '-';
    try {
      const date = new Date(isoString);
      return date.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', hour12: false });
    } catch (e) {
      return '-';
    }
  };

  const getDailyStatusFromPattern = (emp: EmployeeMonthlyStats, dateStr: string) => {
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      const day = parseInt(parts[2], 10);
      if (emp.dailyPattern && day >= 1 && day <= emp.dailyPattern.length) {
        return emp.dailyPattern[day - 1];
      }
    }
    return '';
  };

  return (
    <>
      {/* Daily Toolbar filter */}
      <section className="toolbar">
        <div className="search-box">
          <div className="search-wrapper">
            <Search className="search-icon" size={18} />
            <input 
              id="daily-search-input"
              type="text" 
              className="search-input" 
              placeholder="Tìm theo tên, mã NV..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>
      </section>

      {/* Daily Table list */}
      <main className="table-card">
        {dailyLoading ? (
          <div className="loading-overlay">Đang tải dữ liệu chấm công ngày...</div>
        ) : filteredDailyEmployees.length === 0 ? (
          <div className="loading-overlay">Không tìm thấy nhân viên phù hợp</div>
        ) : (
          <table className="attendance-table">
            <thead>
              <tr>
                <th>Nhân viên</th>
                <th>Ca làm việc</th>
                <th>Giờ vào (In)</th>
                <th>Giờ ra (Out)</th>
                <th>Thời gian làm</th>
                <th>Trạng thái</th>
                <th>Hành động</th>
              </tr>
            </thead>
            <tbody>
              {filteredDailyEmployees.map((emp) => {
                const report = dailyReportMap[emp.id];
                const statusChar = getDailyStatusFromPattern(emp, selectedDate);
                
                let checkInText = '-';
                let checkInClass = '';
                let checkOutText = '-';
                let checkOutClass = '';

                if (report) {
                  if (report.checkIn) {
                    checkInText = `In: ${formatTime(report.checkIn)}`;
                    checkInClass = report.isLate ? 'warning' : 'success';
                  }
                  if (report.checkOut) {
                    checkOutText = `Out: ${formatTime(report.checkOut)}`;
                    checkOutClass = report.isEarlyLeave ? 'warning' : 'success';
                  }
                }

                const workingHours = report && report.totalMinutes 
                  ? `${(report.totalMinutes / 60).toFixed(1)}h`
                  : '-';

                const getStatusPill = () => {
                  if (report) {
                    if (report.isLate && report.isEarlyLeave) {
                      return <span className="pill-badge late">Đi muộn & Về sớm</span>;
                    }
                    if (report.isLate) {
                      return <span className="pill-badge late">Đi muộn</span>;
                    }
                    if (report.isEarlyLeave) {
                      return <span className="pill-badge late">Về sớm</span>;
                    }
                    if (report.checkOut) {
                      return <span className="pill-badge present">Đủ công</span>;
                    }
                    return <span className="pill-badge present">Đang làm</span>;
                  } else {
                    if (statusChar === 'v') {
                      return <span className="pill-badge leave">Nghỉ phép</span>;
                    }
                    if (statusChar === 'h') {
                      return <span className="pill-badge holiday">Cuối tuần / Lễ</span>;
                    }
                    if (statusChar === 'a') {
                      return <span className="pill-badge absent">Vắng không phép</span>;
                    }
                    return <span className="pill-badge absent">Chưa check-in</span>;
                  }
                };

                const shiftStart = report?.shiftStart || '08:00';
                const shiftEnd = report?.shiftEnd || '17:00';

                return (
                  <tr key={emp.id} className="table-row">
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
                      <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--color-text)' }}>
                        Ca hành chính ({shiftStart} - {shiftEnd})
                      </span>
                    </td>
                    <td className={`number-cell ${checkInClass}`} style={{ fontWeight: 600 }}>
                      {checkInText}
                    </td>
                    <td className={`number-cell ${checkOutClass}`} style={{ fontWeight: 600 }}>
                      {checkOutText}
                    </td>
                    <td className="number-cell">{workingHours}</td>
                    <td>
                      {getStatusPill()}
                    </td>
                    <td>
                      <button 
                        className="action-btn-outline" 
                        style={{ 
                          padding: '5px 10px', 
                          fontSize: '12px',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          borderRadius: '6px'
                        }}
                        onClick={(e) => {
                          e.stopPropagation();
                          setManualEmployee(emp);
                          setShowManualModal(true);
                        }}
                      >
                        <Plus size={12} />
                        Ghi công tay
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </main>
    </>
  );
};

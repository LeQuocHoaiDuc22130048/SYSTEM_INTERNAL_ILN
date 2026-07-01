import React from 'react';
import { Search, Plus } from 'lucide-react';
import type { EmployeeMonthlyStats } from '../mockData';
import { getAvatarLetters, getDailyStatusFromPattern } from '../utils/employee';

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

function formatTime(isoString: string | null): string {
  if (!isoString) return '-';
  try {
    return new Date(isoString).toLocaleTimeString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    });
  } catch {
    return '-';
  }
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
  const getTodayStr = () => {
    const d = new Date();
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const isPastDate = (dateStr: string, todayStr: string) => {
    return dateStr < todayStr;
  };

  const isFutureDate = (dateStr: string, todayStr: string) => {
    return dateStr > todayStr;
  };

  const isPastShiftEnd = (shiftEndStr: string) => {
    const now = new Date();
    const currentHours = now.getHours();
    const currentMinutes = now.getMinutes();
    const [endHours, endMinutes] = shiftEndStr.split(':').map(Number);
    return (currentHours > endHours) || (currentHours === endHours && currentMinutes > endMinutes);
  };

  const getStatusPill = (report: any, statusChar: string) => {
    const todayStr = getTodayStr();
    const isToday = selectedDate === todayStr;
    const isPast = isPastDate(selectedDate, todayStr);
    const isFuture = isFutureDate(selectedDate, todayStr);

    if (report) {
      const hasIn = !!report.checkIn;
      const hasOut = !!report.checkOut;

      if (!hasIn && hasOut) {
        return <span className="pill-badge late">Thiếu check-in</span>;
      }
      if (hasIn && !hasOut) {
        const shiftEnd = report.shiftEnd ?? '17:00';
        if (isPast || (isToday && isPastShiftEnd(shiftEnd))) {
          return <span className="pill-badge late">Thiếu check-out</span>;
        }
        return <span className="pill-badge present">Đang làm</span>;
      }
      if (hasIn && hasOut) {
        if (report.isLate && report.isEarlyLeave) {
          return <span className="pill-badge late">Đi muộn & Về sớm</span>;
        }
        if (report.isLate) {
          return <span className="pill-badge late">Đi muộn</span>;
        }
        if (report.isEarlyLeave) {
          return <span className="pill-badge late">Về sớm</span>;
        }
        if (statusChar === 'h' || statusChar === 'o') {
          return <span className="pill-badge ot">Tăng ca</span>;
        }
        return <span className="pill-badge present">Đủ công</span>;
      }
    }

    if (isFuture || statusChar === 'f') {
      return <span className="pill-badge holiday">Chưa diễn ra</span>;
    }
    if (statusChar === 'v') {
      return <span className="pill-badge leave">Nghỉ phép</span>;
    }
    if (statusChar === 'h') {
      return <span className="pill-badge holiday">Cuối tuần / Lễ</span>;
    }
    if (statusChar === 'a') {
      if (isToday) {
        return <span className="pill-badge absent">Chưa check-in</span>;
      }
      return <span className="pill-badge absent">Vắng không phép</span>;
    }

    if (isToday) {
      return <span className="pill-badge absent">Chưa check-in</span>;
    }
    return <span className="pill-badge absent">Vắng không phép</span>;
  };

  return (
    <>
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

                const checkInText = report?.checkIn ? `In: ${formatTime(report.checkIn)}` : '-';
                const checkInClass = report?.checkIn ? (report.isLate ? 'warning' : 'success') : '';
                const checkOutText = report?.checkOut ? `Out: ${formatTime(report.checkOut)}` : '-';
                const checkOutClass = report?.checkOut ? (report.isEarlyLeave ? 'warning' : 'success') : '';
                const workingHours = report?.totalMinutes
                  ? `${(report.totalMinutes / 60).toFixed(1)}h`
                  : '-';

                const shiftStart = report?.shiftStart ?? '08:00';
                const shiftEnd = report?.shiftEnd ?? '17:00';

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
                      <span className="shift-label">
                        Ca hành chính ({shiftStart} - {shiftEnd})
                      </span>
                    </td>
                    <td className={`number-cell ${checkInClass}`}>{checkInText}</td>
                    <td className={`number-cell ${checkOutClass}`}>{checkOutText}</td>
                    <td className="number-cell">{workingHours}</td>
                    <td>{getStatusPill(report, statusChar)}</td>
                    <td>
                      <button
                        className="action-btn-outline action-btn-sm"
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

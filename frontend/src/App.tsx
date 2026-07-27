import { useState, useEffect, useCallback, useMemo } from 'react';
import type { EmployeeMonthlyStats, UserInfo } from './mockData';
import './App.css';

import { LoginScreen } from './components/LoginScreen';
import { Header } from './components/Header';
import { MonthlyStatsGrid } from './components/MonthlyStatsGrid';
import { DailyStatsGrid } from './components/DailyStatsGrid';
import { MonthlyTab } from './components/MonthlyTab';
import { DailyTab } from './components/DailyTab';
import { HistoryModal } from './components/HistoryModal';
import { EditModal } from './components/EditModal';
import { ManualModal } from './components/ManualModal';
import { DeviceTab } from './components/DeviceTab';
import { UpdateTab } from './components/UpdateTab';
import { Sidebar } from './components/Sidebar';
import { OrdersTab } from './components/OrdersTab';
import { WarehouseTab } from './components/WarehouseTab';
import { AccountsTab } from './components/AccountsTab';
import { DashboardTab } from './components/DashboardTab';

import { getAuthHeaders, getJsonAuthHeaders, createTimeoutController, STANDARD_WORK_DAYS } from './utils/auth';
import { getDailyStatusFromPattern } from './utils/employee';
import { exportAttendanceExcel } from './utils/excel';


/** Trạng thái nguồn dữ liệu kết nối */
type DataSource = 'api' | 'error' | 'loading';

/** Tab đang hiển thị */
type ActiveTab = 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts';

/** Dữ liệu target để mở EditModal */
interface EditModalTarget {
  employee: any;
  date: string;
  dayLog: any;
}

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    return !!localStorage.getItem('accessToken');
  });
  const [sidebarOpen, setSidebarOpen] = useState<boolean>(window.innerWidth > 1024);
  const [currentUser, setCurrentUser] = useState<UserInfo | null>(() => {
    const userStr = localStorage.getItem('currentUser');
    try {
      return userStr ? JSON.parse(userStr) : null;
    } catch {
      return null;
    }
  });

  const [currentYear, setCurrentYear] = useState<number>(() => new Date().getFullYear());
  const [currentMonth, setCurrentMonth] = useState<number>(() => new Date().getMonth() + 1);

  const [employees, setEmployees] = useState<EmployeeMonthlyStats[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  const [dataSource, setDataSource] = useState<DataSource>('loading');
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState<number>(0);

  const [searchTerm, setSearchTerm] = useState<string>('');

  const [activeTab, setActiveTab] = useState<ActiveTab>('dashboard');
  const [selectedDate, setSelectedDate] = useState<string>(() => {
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  });
  const [dailyReports, setDailyReports] = useState<any[]>([]);
  const [dailyLoading, setDailyLoading] = useState<boolean>(false);

  const [historyEmployee, setHistoryEmployee] = useState<{ id: string; name: string; dept: string } | null>(null);
  const [manualModalEmployee, setManualModalEmployee] = useState<EmployeeMonthlyStats | null>(null);
  const [editModalTarget, setEditModalTarget] = useState<EditModalTarget | null>(null);

  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = useCallback((message: string) => {
    setToastMessage(message);
    setTimeout(() => setToastMessage(null), 3000);
  }, []);

  const handleLogout = useCallback(async () => {
    const refreshToken = localStorage.getItem('refreshToken');
    try {
      if (refreshToken) {
        await fetch('/api/v1/auth/logout', {
          method: 'POST',
          headers: {
            ...getJsonAuthHeaders(),
          },
          body: JSON.stringify({ refreshToken }),
        });
      }
    } catch (e) {
      console.error('Lỗi khi gọi API logout:', e);
    }
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    localStorage.removeItem('currentUser');
    setIsAuthenticated(false);
    setCurrentUser(null);
    showToast('Đăng xuất thành công.');
  }, [showToast]);

  const fetchMonthlyData = useCallback(async () => {
    if (!isAuthenticated) return;
    setLoading(true);
    setDataSource('loading');
    setConnectionError(null);
    const { signal, clear } = createTimeoutController();
    try {
      const response = await fetch(
        `/api/attendance/monthly?year=${currentYear}&month=${currentMonth}`,
        { signal, headers: getAuthHeaders() }
      );
      clear();
      if (!response.ok) {
        if (response.status === 401) {
          handleLogout();
          throw new Error('Phiên đăng nhập đã hết hạn.');
        }
        if (response.status === 403) {
          setDataSource('api');
          setConnectionError(null);
          setEmployees([]);
          return;
        }
        throw new Error(`Server trả về lỗi: ${response.status}`);
      }
      const apiData = await response.json();
      if (apiData?.data?.employees) {
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
      console.warn('Lỗi kết nối API:', errorMsg);
      setConnectionError(errorMsg);
      setDataSource('error');
      setEmployees([]);
    } finally {
      setLoading(false);
    }
  }, [currentYear, currentMonth, isAuthenticated, handleLogout]);

  useEffect(() => {
    fetchMonthlyData();
  }, [fetchMonthlyData, retryCount]);

  const fetchDailyReport = useCallback(async (dateStr: string) => {
    if (!isAuthenticated) return;
    setDailyLoading(true);
    try {
      const response = await fetch(`/api/v1/attendance/report?date=${dateStr}`, {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          const normalized = result.data.map((report: any) => ({
            ...report,
            records: report.records.map((r: any) => ({
              ...r,
              type: r.type === 'IN' ? 'CHECK_IN' : r.type === 'OUT' ? 'CHECK_OUT' : r.type,
            })),
          }));
          setDailyReports(normalized);
        }
      }
    } catch (e) {
      console.error('Lỗi khi tải báo cáo chấm công ngày:', e);
    } finally {
      setDailyLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (activeTab === 'daily') {
      fetchDailyReport(selectedDate);
    }
  }, [activeTab, selectedDate, fetchDailyReport, retryCount]);

  const handleRetryConnection = () => {
    setRetryCount(prev => prev + 1);
    showToast('Đang thử kết nối lại đến server...');
  };

  const prevMonth = () => {
    if (currentMonth === 1) {
      setCurrentMonth(12);
      setCurrentYear(prev => prev - 1);
    } else {
      setCurrentMonth(prev => prev - 1);
    }
  };

  const nextMonth = () => {
    if (currentMonth === 12) {
      setCurrentMonth(1);
      setCurrentYear(prev => prev + 1);
    } else {
      setCurrentMonth(prev => prev + 1);
    }
  };

  const handleDateChange = (dateStr: string) => {
    setSelectedDate(dateStr);
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      setCurrentYear(parseInt(parts[0], 10));
      setCurrentMonth(parseInt(parts[1], 10));
    }
  };

  const handleOpenEditModal = (dayLog: any, employee: any) => {
    setEditModalTarget({ employee, date: dayLog.date, dayLog });
  };

  const handleExportExcel = async () => {
    showToast('Đang kết xuất dữ liệu chấm công tháng...');
    try {
      await exportAttendanceExcel(filteredEmployees, currentMonth, currentYear);
      showToast('Xuất Excel chấm công thành công!');
    } catch (err) {
      console.error(err);
      showToast('Có lỗi xảy ra khi xuất file Excel!');
    }
  };

  const dailyReportMap = useMemo(() => {
    const map: Record<string, any> = {};
    dailyReports.forEach(report => {
      if (report.records?.length > 0) {
        const empId = report.records[0].employeeId;
        if (empId) map[empId] = report;
      }
    });
    return map;
  }, [dailyReports]);

  const activeEmployees = useMemo(() => {
    return employees.filter(emp => {
      const nameLower = emp.name.toLowerCase();
      const codeLower = emp.employeeCode.toLowerCase();
      const deptLower = emp.dept.toLowerCase();
      return !(
        nameLower.includes('admin') ||
        codeLower.includes('admin') ||
        deptLower.includes('admin') ||
        deptLower.includes('quản trị')
      );
    });
  }, [employees]);

  const filteredEmployees = useMemo(() => {
    const term = searchTerm.toLowerCase();
    return activeEmployees.filter(emp =>
      emp.name.toLowerCase().includes(term) ||
      emp.employeeCode.toLowerCase().includes(term)
    );
  }, [activeEmployees, searchTerm]);

  const dailyStats = useMemo(() => {
    const total = activeEmployees.length;
    let onTime = 0;
    let lateEarly = 0;
    let absent = 0;

    const todayStr = new Date().toLocaleDateString('sv-SE');
    const isToday = selectedDate === todayStr;
    const isPast = selectedDate < todayStr;
    const isFuture = selectedDate > todayStr;

    const isPastShiftEnd = (shiftEndStr: string) => {
      const now = new Date();
      const currentHours = now.getHours();
      const currentMinutes = now.getMinutes();
      const [endHours, endMinutes] = shiftEndStr.split(':').map(Number);
      return (currentHours > endHours) || (currentHours === endHours && currentMinutes > endMinutes);
    };

    activeEmployees.forEach(emp => {
      const report = dailyReportMap[emp.id];
      const statusChar = getDailyStatusFromPattern(emp, selectedDate);

      if (report) {
        const hasIn = !!report.checkIn;
        const hasOut = !!report.checkOut;

        if (!hasIn && hasOut) {
          lateEarly++;
        } else if (hasIn && !hasOut) {
          const shiftEnd = report.shiftEnd ?? '17:00';
          if (isPast || (isToday && isPastShiftEnd(shiftEnd))) {
            lateEarly++;
          } else {
            onTime++;
          }
        } else if (hasIn && hasOut) {
          if (report.isLate || report.isEarlyLeave) {
            lateEarly++;
          } else {
            onTime++;
          }
        }
      } else {
        if (!isFuture && statusChar !== 'f' && statusChar !== 'h') {
          if (statusChar === 'a' || statusChar === 'v' || statusChar === 'o' || statusChar === '') {
            absent++;
          }
        }
      }
    });

    return { total, onTime, lateEarly, absent };
  }, [activeEmployees, dailyReportMap, selectedDate]);

  const monthlyStats = useMemo(() => {
    const count = activeEmployees.length;
    const totalPresent = activeEmployees.reduce((sum, emp) => sum + emp.workDays, 0);
    return {
      averagePresent: count > 0 ? Math.round((totalPresent / count) * 10) / 10 : 0,
      totalLateCount: activeEmployees.reduce((sum, emp) => sum + emp.lateCount, 0),
      totalAbsentDays: activeEmployees.reduce((sum, emp) => sum + emp.absentDays, 0),
    };
  }, [activeEmployees]);

  if (!isAuthenticated) {
    return (
      <LoginScreen
        onLoginSuccess={(userInfo) => {
          setIsAuthenticated(true);
          setCurrentUser(userInfo);
        }}
        showToast={showToast}
      />
    );
  }

  if (loading && dataSource === 'loading') {
    return <div className="loading-screen">Đang kết nối hệ thống...</div>;
  }

  return (
    <div className="app-layout">
      {toastMessage && <div className="toast-msg">{toastMessage}</div>}

      <Sidebar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        currentUser={currentUser}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
        handleLogout={handleLogout}
      />

      <div className="main-container">
        <Header
          activeTab={activeTab}
          currentMonth={currentMonth}
          currentYear={currentYear}
          prevMonth={prevMonth}
          nextMonth={nextMonth}
          selectedDate={selectedDate}
          handleDateChange={handleDateChange}
          dataSource={dataSource}
          connectionError={connectionError}
          handleRetryConnection={handleRetryConnection}
          onToggleSidebar={() => setSidebarOpen(!sidebarOpen)}
        />

        <div className="main-content-inner">
          {activeTab === 'dashboard' ? (
            <DashboardTab
              setActiveTab={setActiveTab}
              showToast={showToast}
              currentUser={currentUser}
            />
          ) : activeTab === 'monthly' ? (
            <>
              <MonthlyStatsGrid
                totalStandardDays={STANDARD_WORK_DAYS}
                averagePresent={monthlyStats.averagePresent}
                totalLateCount={monthlyStats.totalLateCount}
                totalAbsentDays={monthlyStats.totalAbsentDays}
              />
              <MonthlyTab
                key={`${currentMonth}-${currentYear}`}
                filteredEmployees={filteredEmployees}
                searchTerm={searchTerm}
                setSearchTerm={setSearchTerm}
                currentMonth={currentMonth}
                currentYear={currentYear}
                loading={loading}
                handleExportExcel={handleExportExcel}
                setHistoryEmployee={setHistoryEmployee}
                showToast={showToast}
              />
            </>
          ) : activeTab === 'daily' ? (
            <>
              <DailyStatsGrid
                total={dailyStats.total}
                onTime={dailyStats.onTime}
                lateEarly={dailyStats.lateEarly}
                absent={dailyStats.absent}
              />
              <DailyTab
                filteredDailyEmployees={filteredEmployees}
                dailyReportMap={dailyReportMap}
                searchTerm={searchTerm}
                setSearchTerm={setSearchTerm}
                selectedDate={selectedDate}
                dailyLoading={dailyLoading}
                setManualEmployee={setManualModalEmployee}
                setShowManualModal={(show) => { if (!show) setManualModalEmployee(null); }}
              />
            </>
          ) : activeTab === 'devices' ? (
            <DeviceTab
              showToast={showToast}
              currentUser={currentUser}
            />
          ) : activeTab === 'updates' ? (
            <UpdateTab
              showToast={showToast}
            />
          ) : activeTab === 'orders' ? (
            <OrdersTab
              showToast={showToast}
              currentUser={currentUser}
            />
          ) : activeTab === 'accounts' ? (
            <AccountsTab
              showToast={showToast}
              currentUser={currentUser}
            />
          ) : (
            <WarehouseTab
              showToast={showToast}
            />
          )}
        </div>
      </div>

      {historyEmployee && (
        <HistoryModal
          employee={historyEmployee}
          currentMonth={currentMonth}
          currentYear={currentYear}
          onClose={() => setHistoryEmployee(null)}
          onOpenEditModal={handleOpenEditModal}
          showToast={showToast}
        />
      )}

      {manualModalEmployee && (
        <ManualModal
          employee={manualModalEmployee}
          selectedDate={selectedDate}
          onClose={() => setManualModalEmployee(null)}
          showToast={showToast}
          onSaveSuccess={() => {
            fetchDailyReport(selectedDate);
            fetchMonthlyData();
          }}
        />
      )}

      {editModalTarget && (
        <EditModal
          employee={editModalTarget.employee}
          date={editModalTarget.date}
          dayLog={editModalTarget.dayLog}
          onClose={() => setEditModalTarget(null)}
          showToast={showToast}
          onSaveSuccess={() => {
            if (historyEmployee) {
              const emp = { ...historyEmployee };
              setHistoryEmployee(null);
              setTimeout(() => setHistoryEmployee(emp), 50);
            }
            fetchMonthlyData();
          }}
        />
      )}
    </div>
  );
}

export default App;

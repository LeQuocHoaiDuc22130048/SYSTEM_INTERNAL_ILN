import { useState, useEffect, useCallback, useMemo } from 'react';
import type { EmployeeMonthlyStats } from './mockData';
import './App.css';

// Import split components
import { LoginScreen } from './components/LoginScreen';
import { Header } from './components/Header';
import { MonthlyStatsGrid } from './components/MonthlyStatsGrid';
import { DailyStatsGrid } from './components/DailyStatsGrid';
import { MonthlyTab } from './components/MonthlyTab';
import { DailyTab } from './components/DailyTab';
import { HistoryModal } from './components/HistoryModal';
import { EditModal } from './components/EditModal';
import { ManualModal } from './components/ManualModal';

function App() {
  // Authentication State
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    return !!localStorage.getItem('accessToken');
  });
  const [currentUser, setCurrentUser] = useState<any>(() => {
    const userStr = localStorage.getItem('currentUser');
    try {
      return userStr ? JSON.parse(userStr) : null;
    } catch {
      return null;
    }
  });

  // Navigation State
  const [currentYear, setCurrentYear] = useState<number>(() => new Date().getFullYear());
  const [currentMonth, setCurrentMonth] = useState<number>(() => new Date().getMonth() + 1);

  // Data State
  const [employees, setEmployees] = useState<EmployeeMonthlyStats[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  // Connection Status
  const [dataSource, setDataSource] = useState<'api' | 'error' | 'loading'>('loading');
  const [connectionError, setConnectionError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState<number>(0);

  // Search & Filter State
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Daily View State
  const [activeTab, setActiveTab] = useState<'monthly' | 'daily'>('monthly');
  const [selectedDate, setSelectedDate] = useState<string>(() => {
    const today = new Date();
    const y = today.getFullYear();
    const m = String(today.getMonth() + 1).padStart(2, '0');
    const d = String(today.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  });
  const [dailyReports, setDailyReports] = useState<any[]>([]);
  const [dailyLoading, setDailyLoading] = useState<boolean>(false);

  // Modal Targets
  const [historyEmployee, setHistoryEmployee] = useState<{ id: string; name: string; dept: string } | null>(null);
  
  const [showManualModal, setShowManualModal] = useState<boolean>(false);
  const [manualEmployee, setManualEmployee] = useState<EmployeeMonthlyStats | null>(null);

  const [showEditModal, setShowEditModal] = useState<boolean>(false);
  const [editEmployee, setEditEmployee] = useState<any>(null);
  const [editDate, setEditDate] = useState<string>('');
  const [editDayLog, setEditDayLog] = useState<any>(null);

  // Toast State
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Show Toast Helper
  const showToast = useCallback((message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  }, []);

  // Logout handler
  const handleLogout = useCallback(async () => {
    const refreshToken = localStorage.getItem('refreshToken');
    try {
      if (refreshToken) {
        await fetch('/api/v1/auth/logout', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
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

  // Fetch Monthly Data
  const fetchMonthlyData = useCallback(async () => {
    if (!isAuthenticated) return;
    setLoading(true);
    setDataSource('loading');
    setConnectionError(null);
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);
      const token = localStorage.getItem('accessToken');
      const headers: Record<string, string> = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
      const response = await fetch(`/api/attendance/monthly?year=${currentYear}&month=${currentMonth}`, {
        signal: controller.signal,
        headers,
      });
      clearTimeout(timeoutId);
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          handleLogout();
          throw new Error('Phiên đăng nhập đã hết hạn.');
        }
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

  // Daily Attendance report loading
  const fetchDailyReport = useCallback(async (dateStr: string) => {
    if (!isAuthenticated) return;
    setDailyLoading(true);
    try {
      const token = localStorage.getItem('accessToken');
      const headers: Record<string, string> = {};
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
      const response = await fetch(`/api/v1/attendance/report?date=${dateStr}`, {
        headers,
      });
      if (response.ok) {
        const result = await response.json();
        if (result && result.data) {
          const normalized = result.data.map((report: any) => ({
            ...report,
            records: report.records.map((r: any) => ({
              ...r,
              type: r.type === 'IN' ? 'CHECK_IN' : r.type === 'OUT' ? 'CHECK_OUT' : r.type
            }))
          }));
          setDailyReports(normalized);
        }
      }
    } catch (e) {
      console.error("Lỗi khi tải báo cáo chấm công ngày:", e);
    } finally {
      setDailyLoading(false);
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (activeTab === 'daily') {
      fetchDailyReport(selectedDate);
    }
  }, [activeTab, selectedDate, fetchDailyReport, retryCount]);

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

  // Open Edit Modal
  const handleOpenEditModal = (dayLog: any, employee: any) => {
    setEditEmployee(employee);
    setEditDate(dayLog.date);
    setEditDayLog(dayLog);
    setShowEditModal(true);
  };

  // Export Excel Sim
  const handleExportExcel = () => {
    showToast("Đang kết xuất dữ liệu chấm công tháng...");
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

  const dailyReportMap = useMemo(() => {
    const map: Record<string, any> = {};
    dailyReports.forEach(report => {
      if (report.records && report.records.length > 0) {
        const empId = report.records[0].employeeId;
        if (empId) {
          map[empId] = report;
        }
      }
    });
    return map;
  }, [dailyReports]);

  // Get active employees list (excluding administrative accounts)
  const activeEmployees = useMemo(() => {
    return employees.filter(emp => {
      const isSystemAdmin = 
        emp.name.toLowerCase().includes('admin') ||
        emp.employeeCode.toLowerCase().includes('admin') ||
        emp.dept.toLowerCase().includes('admin') ||
        emp.dept.toLowerCase().includes('quản trị');
      return !isSystemAdmin;
    });
  }, [employees]);

  // Filter logic (Monthly)
  const filteredEmployees = useMemo(() => {
    return activeEmployees.filter(emp => {
      return (
        emp.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        emp.employeeCode.toLowerCase().includes(searchTerm.toLowerCase())
      );
    });
  }, [activeEmployees, searchTerm]);

  // Filter logic (Daily)
  const filteredDailyEmployees = useMemo(() => {
    return activeEmployees.filter(emp => {
      return (
        emp.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        emp.employeeCode.toLowerCase().includes(searchTerm.toLowerCase())
      );
    });
  }, [activeEmployees, searchTerm]);

  // Daily Stats Calculation
  const dailyStats = useMemo(() => {
    const total = activeEmployees.length;
    let onTime = 0;
    let lateEarly = 0;
    let absent = 0;

    activeEmployees.forEach(emp => {
      const report = dailyReportMap[emp.id];
      const statusChar = getDailyStatusFromPattern(emp, selectedDate);
      if (report) {
        if (report.checkIn) {
          if (report.isLate) {
            lateEarly++;
          } else {
            onTime++;
          }
        }
        if (report.isEarlyLeave && !report.isLate) {
          lateEarly++;
        }
      } else {
        if (statusChar === 'a' || statusChar === '' || statusChar === 'v') {
          absent++;
        }
      }
    });

    return { total, onTime, lateEarly, absent };
  }, [activeEmployees, dailyReportMap, selectedDate]);

  // Calculate Overall Dashboard Stats
  const totalStandardDays = 22; // chuẩn
  const employeesCount = filteredEmployees.length;
  
  const totalPresentCount = filteredEmployees.reduce((sum, emp) => sum + emp.workDays, 0);
  const averagePresent = employeesCount > 0 ? Math.round((totalPresentCount / employeesCount) * 10) / 10 : 0;
  
  const totalLateCount = filteredEmployees.reduce((sum, emp) => sum + emp.lateCount, 0);
  const totalAbsentDays = filteredEmployees.reduce((sum, emp) => sum + emp.absentDays, 0);

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
    <div className="container">
      {/* Toast popup */}
      {toastMessage && (
        <div className="toast-msg">
          {toastMessage}
        </div>
      )}

      <Header 
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        currentMonth={currentMonth}
        currentYear={currentYear}
        prevMonth={prevMonth}
        nextMonth={nextMonth}
        selectedDate={selectedDate}
        handleDateChange={handleDateChange}
        dataSource={dataSource}
        connectionError={connectionError}
        handleRetryConnection={handleRetryConnection}
        currentUser={currentUser}
        handleLogout={handleLogout}
      />

      {activeTab === 'monthly' ? (
        <>
          <MonthlyStatsGrid 
            totalStandardDays={totalStandardDays}
            averagePresent={averagePresent}
            totalLateCount={totalLateCount}
            totalAbsentDays={totalAbsentDays}
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
      ) : (
        <>
          <DailyStatsGrid 
            total={dailyStats.total}
            onTime={dailyStats.onTime}
            lateEarly={dailyStats.lateEarly}
            absent={dailyStats.absent}
          />
          <DailyTab 
            filteredDailyEmployees={filteredDailyEmployees}
            dailyReportMap={dailyReportMap}
            searchTerm={searchTerm}
            setSearchTerm={setSearchTerm}
            selectedDate={selectedDate}
            dailyLoading={dailyLoading}
            setManualEmployee={setManualEmployee}
            setShowManualModal={setShowManualModal}
          />
        </>
      )}

      {/* History Log Modal Screen */}
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

      {/* Manual Check-in Modal */}
      {showManualModal && manualEmployee && (
        <ManualModal 
          employee={manualEmployee}
          selectedDate={selectedDate}
          onClose={() => {
            setShowManualModal(false);
            setManualEmployee(null);
          }}
          showToast={showToast}
          onSaveSuccess={() => {
            fetchDailyReport(selectedDate);
            fetchMonthlyData();
          }}
        />
      )}

      {/* Edit Attendance Modal */}
      {showEditModal && editEmployee && (
        <EditModal 
          employee={editEmployee}
          date={editDate}
          dayLog={editDayLog}
          onClose={() => {
            setShowEditModal(false);
            setEditEmployee(null);
            setEditDate('');
            setEditDayLog(null);
          }}
          showToast={showToast}
          onSaveSuccess={() => {
            // refresh history view
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

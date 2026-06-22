import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { 
  Search, 
  ChevronLeft, 
  ChevronRight, 
  Download, 
  Edit3, 
  ExternalLink, 
  X, 
  LogOut,
  LogIn,
  ChevronDown,
  ChevronUp,
  Wifi,
  WifiOff,
  RefreshCw,
  Database,
  Calendar,
  Plus,
  User,
  Lock,
  Phone,
  ShieldCheck,
  Eye,
  EyeOff,
  AlertCircle
} from 'lucide-react';
import type { 
  EmployeeMonthlyStats, 
  EmployeeHistoryResponse 
} from './mockData';
import './App.css';

// ponytail: normalizes checkin/checkout event types from backend API to fit frontend expectation
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

  // Login Form State
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [showPassword, setShowPassword] = useState<boolean>(false);
  const [error, setError] = useState<string>('');
  const [loginLoading, setLoginLoading] = useState<boolean>(false);

  // Forgot Password State
  const [forgotUsername, setForgotUsername] = useState<string>('');
  const [forgotPhone, setForgotPhone] = useState<string>('');
  const [forgotOtp, setForgotOtp] = useState<string>('');
  const [forgotNewPassword, setForgotNewPassword] = useState<string>('');
  const [forgotConfirmPassword, setForgotConfirmPassword] = useState<string>('');
  const [forgotOtpRequested, setForgotOtpRequested] = useState<boolean>(false);
  const [forgotError, setForgotError] = useState<string>('');
  const [forgotLoading, setForgotLoading] = useState<boolean>(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState<boolean>(false);

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

  // Manual Check-in Modal State
  const [showManualModal, setShowManualModal] = useState<boolean>(false);
  const [manualEmployee, setManualEmployee] = useState<EmployeeMonthlyStats | null>(null);
  const [manualType, setManualType] = useState<'IN' | 'OUT'>('IN');
  const [manualTime, setManualTime] = useState<string>('08:00');
  const [manualNote, setManualNote] = useState<string>('');
  const [manualSubmitting, setManualSubmitting] = useState<boolean>(false);

  // Expanded Inline Employee
  const [expandedEmployeeId, setExpandedEmployeeId] = useState<string | null>(null);
  const [expandedLogs, setExpandedLogs] = useState<Record<string, EmployeeHistoryResponse>>({});
  const [expandedLogsLoading, setExpandedLogsLoading] = useState<Record<string, boolean>>({});

  // History Modal State
  const [historyEmployee, setHistoryEmployee] = useState<{ id: string; name: string; dept: string } | null>(null);
  const [historyData, setHistoryData] = useState<EmployeeHistoryResponse | null>(null);
  const [historyFilter, setHistoryFilter] = useState<string>('ALL');
  const [historyLoading, setHistoryLoading] = useState<boolean>(false);
  const [expandedDays, setExpandedDays] = useState<Record<string, boolean>>({});

  // Toast State
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Show Toast Helper
  const showToast = useCallback((message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  }, []);

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
  }, [currentYear, currentMonth, isAuthenticated]);

  useEffect(() => {
    fetchMonthlyData();
  }, [fetchMonthlyData, retryCount]);

  // Fetch History Logs
  useEffect(() => {
    if (!historyEmployee || !isAuthenticated) {
      setHistoryData(null);
      return;
    }

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
        const response = await fetch(`/api/attendance/${historyEmployee.id}/logs?year=${currentYear}&month=${currentMonth}`, {
          signal: controller.signal,
          headers,
        });
        clearTimeout(timeoutId);
        if (!response.ok) {
          if (response.status === 401 || response.status === 403) {
            handleLogout();
            throw new Error('Phiên đăng nhập đã hết hạn.');
          }
          throw new Error('Không thể tải lịch sử chi tiết từ server');
        }
        const apiData = await response.json();
        if (apiData && apiData.data) {
          setHistoryData(normalizeHistoryResponse(apiData.data));
        } else {
          throw new Error('Dữ liệu không đúng cấu trúc');
        }
      } catch (err) {
        console.error('Lỗi tải lịch sử chi tiết cho:', historyEmployee.name);
        setHistoryData(null);
      } finally {
        setHistoryLoading(false);
      }
    };

    fetchHistoryData();
  }, [historyEmployee, currentYear, currentMonth, isAuthenticated]);

  // Reset cached expanded logs when month or year changes
  useEffect(() => {
    setExpandedLogs({});
    setExpandedLogsLoading({});
  }, [currentMonth, currentYear]);

  // Fetch logs for expanded employee inline
  useEffect(() => {
    if (!expandedEmployeeId || !isAuthenticated) return;
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
  }, [expandedEmployeeId, currentYear, currentMonth, isAuthenticated, expandedLogs, expandedLogsLoading]);

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

  const handleDateChange = (dateStr: string) => {
    setSelectedDate(dateStr);
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      setCurrentYear(parseInt(parts[0], 10));
      setCurrentMonth(parseInt(parts[1], 10));
    }
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

  // Login handler
  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoginLoading(true);
    try {
      const response = await fetch('/api/v1/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });
      
      if (!response.ok) {
        const errResult = await response.json();
        throw new Error(errResult.message || 'Sai tên đăng nhập hoặc mật khẩu.');
      }
      
      const result = await response.json();
      if (result && result.data) {
        const { accessToken, refreshToken, userInfo } = result.data;
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('refreshToken', refreshToken);
        localStorage.setItem('currentUser', JSON.stringify(userInfo));
        setIsAuthenticated(true);
        setCurrentUser(userInfo);
        showToast(`Đăng nhập thành công! Chào mừng ${userInfo.fullName || userInfo.username}`);
      } else {
        throw new Error('Dữ liệu đăng nhập không hợp lệ.');
      }
    } catch (err: any) {
      setError(err.message || 'Không thể kết nối đến máy chủ.');
    } finally {
      setLoginLoading(false);
    }
  };

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
  }, []);

  // Forgot password handler
  const handleForgotPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setForgotError('');
    setForgotLoading(true);
    try {
      if (!forgotOtpRequested) {
        // Request OTP
        const response = await fetch('/api/v1/auth/forgot-password/otp', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: forgotUsername, phone: forgotPhone })
        });
        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.message || 'Yêu cầu OTP thất bại.');
        }
        setForgotOtpRequested(true);
      } else {
        // Submit reset password
        if (forgotNewPassword !== forgotConfirmPassword) {
          throw new Error('Mật khẩu xác nhận không khớp.');
        }
        const response = await fetch('/api/v1/auth/forgot-password', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            username: forgotUsername,
            otp: forgotOtp,
            newPassword: forgotNewPassword
          })
        });
        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.message || 'Đặt lại mật khẩu thất bại.');
        }
        showToast('Đặt lại mật khẩu thành công! Vui lòng đăng nhập.');
        setShowForgotPasswordModal(false);
        setForgotOtpRequested(false);
      }
    } catch (err: any) {
      setForgotError(err.message);
    } finally {
      setForgotLoading(false);
    }
  };

  // Manual check-in handler
  const handleManualSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualEmployee) return;

    setManualSubmitting(true);
    try {
      const token = localStorage.getItem('accessToken');
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
      };
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }

      const checkTime = `${selectedDate}T${manualTime}:00+07:00`;

      const body = {
        employeeId: manualEmployee.id,
        type: manualType,
        checkTime,
        note: manualNote || 'Chấm công thủ công bởi quản trị viên'
      };

      const response = await fetch('/api/v1/attendance/manual', {
        method: 'POST',
        headers,
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Lỗi khi gửi yêu cầu chấm công thủ công');
      }

      showToast(`Đã ghi nhận công tay thành công cho ${manualEmployee.name}`);
      setShowManualModal(false);
      fetchDailyReport(selectedDate);
      fetchMonthlyData();
    } catch (err: any) {
      console.error(err);
      showToast(err.message || 'Có lỗi xảy ra khi chấm công thủ công.');
    } finally {
      setManualSubmitting(false);
    }
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

  if (!isAuthenticated) {
    return (
      <div className="login-screen-container">
        <div className="login-grid-overlay"></div>
        <div className="login-content-wrapper">
          <div className="login-split-layout">
            {/* Left side branding */}
            <div className="login-branding-section">
              <img src="/app_logo.png" alt="App Logo" className="login-logo" />
              <h1 className="login-title-h1">HỆ THỐNG INTERNAL ILN</h1>
              <p className="login-subtitle-p">Ứng dụng quản lý giám sát chấm công và thiết bị IoT nội bộ.</p>
            </div>

            {/* Right side login form */}
            <div className="login-form-container">
              <div className="login-card">
                <h2 className="login-card-title">Đăng nhập Quản trị</h2>
                <p className="login-card-subtitle">Vui lòng điền thông tin tài khoản của bạn</p>

                {error && (
                  <div className="login-error-card">
                    <AlertCircle size={18} style={{ color: '#ef4444' }} />
                    <span className="login-error-text">{error}</span>
                  </div>
                )}

                <form onSubmit={handleLoginSubmit}>
                  <div className="login-form-group">
                    <label className="login-input-label">Tên đăng nhập</label>
                    <div className="login-input-wrapper">
                      <User className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                      <input 
                        type="text" 
                        className="login-input-field" 
                        placeholder="Nhập username..."
                        value={username}
                        onChange={(e) => setUsername(e.target.value)}
                        required
                        disabled={loginLoading}
                      />
                    </div>
                  </div>

                  <div className="login-form-group">
                    <label className="login-input-label">Mật khẩu</label>
                    <div className="login-input-wrapper">
                      <Lock className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                      <input 
                        type={showPassword ? "text" : "password"} 
                        className="login-input-field" 
                        placeholder="Nhập mật khẩu..."
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        required
                        disabled={loginLoading}
                      />
                      <button 
                        type="button" 
                        className="login-password-toggle"
                        onClick={() => setShowPassword(!showPassword)}
                        style={{ border: 'none', background: 'none', cursor: 'pointer' }}
                      >
                        {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '20px' }}>
                    <button 
                      type="button" 
                      className="login-forgot-pwd-btn"
                      onClick={() => setShowForgotPasswordModal(true)}
                      style={{ border: 'none', background: 'none', cursor: 'pointer' }}
                    >
                      Quên mật khẩu?
                    </button>
                  </div>

                  <button 
                    type="submit" 
                    className="login-btn-primary"
                    disabled={loginLoading}
                  >
                    {loginLoading ? <span className="login-spinner"></span> : 'Đăng nhập'}
                  </button>
                </form>
              </div>
            </div>
          </div>
        </div>

        {/* Forgot Password Modal */}
        {showForgotPasswordModal && (
          <div className="login-modal-overlay">
            <div className="login-modal-card">
              <div className="login-modal-header">
                <h3 className="login-modal-title">Đặt lại mật khẩu</h3>
                <button className="modal-close" onClick={() => {
                  setShowForgotPasswordModal(false);
                  setForgotOtpRequested(false);
                  setForgotError('');
                }} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                  <X size={20} />
                </button>
              </div>
              <form onSubmit={handleForgotPasswordSubmit}>
                <div className="login-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  {forgotError && (
                    <div className="login-error-card">
                      <AlertCircle size={18} style={{ color: '#ef4444' }} />
                      <span className="login-error-text">{forgotError}</span>
                    </div>
                  )}

                  {!forgotOtpRequested ? (
                    <>
                      <div className="login-form-group">
                        <label className="login-input-label">Tên tài khoản</label>
                        <div className="login-input-wrapper">
                          <User className="login-input-icon-left" size={18} />
                          <input 
                            type="text" 
                            className="login-input-field" 
                            placeholder="Nhập tên đăng nhập..."
                            value={forgotUsername}
                            onChange={(e) => setForgotUsername(e.target.value)}
                            required
                          />
                        </div>
                      </div>
                      <div className="login-form-group">
                        <label className="login-input-label">Số điện thoại đăng ký</label>
                        <div className="login-input-wrapper">
                          <Phone className="login-input-icon-left" size={18} />
                          <input 
                            type="text" 
                            className="login-input-field" 
                            placeholder="Nhập số điện thoại..."
                            value={forgotPhone}
                            onChange={(e) => setForgotPhone(e.target.value)}
                            required
                          />
                        </div>
                      </div>
                    </>
                  ) : (
                    <>
                      <div style={{ fontSize: '13px', color: 'var(--color-success)', background: 'var(--color-success-light)', padding: '10px', borderRadius: '6px' }}>
                        Mã OTP đã được gửi đến số điện thoại của bạn!
                      </div>
                      <div className="login-form-group">
                        <label className="login-input-label">Mã OTP</label>
                        <div className="login-input-wrapper">
                          <ShieldCheck className="login-input-icon-left" size={18} />
                          <input 
                            type="text" 
                            className="login-input-field" 
                            placeholder="Nhập mã OTP 6 số..."
                            value={forgotOtp}
                            onChange={(e) => setForgotOtp(e.target.value)}
                            required
                          />
                        </div>
                      </div>
                      <div className="login-form-group">
                        <label className="login-input-label">Mật khẩu mới</label>
                        <div className="login-input-wrapper">
                          <Lock className="login-input-icon-left" size={18} />
                          <input 
                            type="password" 
                            className="login-input-field" 
                            placeholder="Mật khẩu mới..."
                            value={forgotNewPassword}
                            onChange={(e) => setForgotNewPassword(e.target.value)}
                            required
                          />
                        </div>
                      </div>
                      <div className="login-form-group">
                        <label className="login-input-label">Xác nhận mật khẩu</label>
                        <div className="login-input-wrapper">
                          <Lock className="login-input-icon-left" size={18} />
                          <input 
                            type="password" 
                            className="login-input-field" 
                            placeholder="Nhập lại mật khẩu..."
                            value={forgotConfirmPassword}
                            onChange={(e) => setForgotConfirmPassword(e.target.value)}
                            required
                          />
                        </div>
                      </div>
                    </>
                  )}
                </div>
                <div className="login-modal-footer">
                  <button 
                    type="button" 
                    className="login-modal-btn-cancel"
                    onClick={() => {
                      setShowForgotPasswordModal(false);
                      setForgotOtpRequested(false);
                      setForgotError('');
                    }}
                    disabled={forgotLoading}
                  >
                    Hủy
                  </button>
                  <button 
                    type="submit" 
                    className="login-modal-btn-submit"
                    disabled={forgotLoading}
                  >
                    {forgotLoading ? <span className="login-spinner"></span> : (forgotOtpRequested ? 'Cập nhật' : 'Gửi mã OTP')}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
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

      {/* Connection Status Banner */}
      {dataSource === 'error' && (
        <div className="connection-banner warning">
          <div className="banner-content">
            <WifiOff size={18} style={{ color: '#ef4444' }} />
            <div className="banner-text">
              <strong style={{ color: '#ef4444' }}>Lỗi kết nối Backend</strong>
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
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <h1 className="title" style={{ fontSize: '22px', fontWeight: 'bold' }}>Quản lý Chấm công</h1>
          <div className="tab-buttons" style={{ display: 'flex', gap: '8px', background: '#f1f5f9', padding: '4px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
            <button 
              id="tab-monthly"
              className={`tab-btn ${activeTab === 'monthly' ? 'active' : ''}`}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '13px',
                background: activeTab === 'monthly' ? '#ffffff' : 'transparent',
                color: activeTab === 'monthly' ? 'var(--color-primary)' : 'var(--color-text-light)',
                boxShadow: activeTab === 'monthly' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.2s'
              }}
              onClick={() => setActiveTab('monthly')}
            >
              Xem theo tháng
            </button>
            <button 
              id="tab-daily"
              className={`tab-btn ${activeTab === 'daily' ? 'active' : ''}`}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '13px',
                background: activeTab === 'daily' ? '#ffffff' : 'transparent',
                color: activeTab === 'daily' ? 'var(--color-primary)' : 'var(--color-text-light)',
                boxShadow: activeTab === 'daily' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.2s'
              }}
              onClick={() => setActiveTab('daily')}
            >
              Xem theo ngày
            </button>
          </div>
        </div>
        <div className="header-right">
          <div className="connection-indicator">
            {dataSource === 'api' ? (
              <span className="conn-badge connected"><Wifi size={14} /> API Connected</span>
            ) : dataSource === 'error' ? (
              <span className="conn-badge disconnected" onClick={handleRetryConnection} title="Click để thử kết nối lại">
                <WifiOff size={14} /> Connection Error
              </span>
            ) : (
              <span className="conn-badge loading"><RefreshCw size={14} className="spin" /> Đang kết nối...</span>
            )}
          </div>
          {activeTab === 'monthly' ? (
            <div className="month-navigator">
              <button id="btn-prev-month" className="nav-btn" onClick={prevMonth}>
                <ChevronLeft size={18} />
              </button>
              <span className="month-display">
                Tháng {currentMonth} / {currentYear}
              </span>
              <button id="btn-next-month" className="nav-btn" onClick={nextMonth}>
                <ChevronRight size={18} />
              </button>
            </div>
          ) : (
            <div className="month-navigator" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Calendar size={18} style={{ color: 'var(--color-text-light)' }} />
              <input 
                id="header-date-picker"
                type="date" 
                value={selectedDate}
                onChange={(e) => handleDateChange(e.target.value)}
                style={{
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  padding: '6px 10px',
                  fontSize: '13px',
                  fontWeight: 600,
                  color: 'var(--color-text-dark)',
                  outline: 'none',
                  fontFamily: 'inherit'
                }}
              />
            </div>
          )}
          {currentUser && (
            <button id="btn-logout" className="login-header-logout" onClick={handleLogout} title="Đăng xuất">
              <LogOut size={16} />
              <span>{currentUser.fullName || currentUser.username}</span>
            </button>
          )}
        </div>
      </header>

      {activeTab === 'monthly' ? (
        <>
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
                                    <div className="calendar-grid-wrapper">
                                      <div className="calendar-grid-header">Lịch chi tiết</div>
                                      
                                      {expandedLogsLoading[emp.id] ? (
                                        <div style={{ padding: '20px', textAlign: 'center', fontSize: '13px', color: 'var(--color-text-light)' }}>
                                          Đang tải lịch sử chấm công...
                                        </div>
                                      ) : (
                                        <div className="calendar-days-grid">
                                          {/* Empty spacer days for offset (mock grid 30 elements starting on custom layout) */}
                                          {(() => {
                                            const days = [];
                                            // generate 30 days based on active month
                                            const numDays = new Date(currentYear, currentMonth, 0).getDate();
                                            // start Day of week for day 1
                                            const firstDayOfWeek = new Date(currentYear, currentMonth - 1, 1).getDay();
                                            // calendar alignment spacer
                                            const spacerCount = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1; // alignment T2 - CN
                                            
                                            for (let s = 0; s < spacerCount; s++) {
                                              days.push({ day: -1, state: 'empty' });
                                            }
                                            for (let d = 1; d <= numDays; d++) {
                                              const char = emp.dailyPattern[d - 1] || 'a';
                                              let stateClass = 'absent';
                                              if (char === 'p') stateClass = 'present';
                                              else if (char === 'l') stateClass = 'late';
                                              else if (char === 'v') stateClass = 'leave';
                                              else if (char === 'h') stateClass = 'holiday';
                                              else if (char === 'o') stateClass = 'ot';
                                              
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

                                            const checkInEvent = dayLog?.events.find(e => e.type === 'CHECK_IN');
                                            const checkOutEvent = dayLog?.events.find(e => e.type === 'CHECK_OUT');

                                            return (
                                              <div key={`day-${dayObj.day}`} className={`calendar-cell ${dayObj.state}`}>
                                                <div className="calendar-cell-top">
                                                  <span className="calendar-date">{dayObj.day}</span>
                                                  <span className="calendar-status">{dayObj.state.toUpperCase()}</span>
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
              <div className="legend-item">
                <div className="legend-dot o"></div>
                <span>Tăng ca (#8B5CF6)</span>
              </div>
            </div>
          </footer>
        </>
      ) : (
        <>
          {/* Row of 4 stats card for Daily */}
          <section className="stats-grid">
            <div className="stats-card">
              <span className="stats-label">Tổng số nhân sự</span>
              <div className="stats-value-row">
                <span className="stats-value">{dailyStats.total}</span>
                <span className="stats-badge success">nhân viên</span>
              </div>
            </div>
            <div className="stats-card">
              <span className="stats-label">Đúng giờ / Có mặt</span>
              <div className="stats-value-row">
                <span className="stats-value">{dailyStats.onTime}</span>
                <span className="stats-badge success">đang làm việc</span>
              </div>
            </div>
            <div className="stats-card">
              <span className="stats-label">Đi muộn / Về sớm</span>
              <div className="stats-value-row">
                <span className="stats-value">{dailyStats.lateEarly}</span>
                <span className="stats-badge late">trường hợp</span>
              </div>
            </div>
            <div className="stats-card">
              <span className="stats-label">Vắng mặt / Nghỉ phép</span>
              <div className="stats-value-row">
                <span className="stats-value">{dailyStats.absent}</span>
                <span className="stats-badge absent">vắng</span>
              </div>
            </div>
          </section>

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
                              setManualType('IN');
                              setManualTime('08:00');
                              setManualNote('');
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
      )}

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

      {showManualModal && manualEmployee && (
        <div className="modal-overlay">
          <div className="modal-content" style={{ maxWidth: '450px' }}>
            <div className="modal-header">
              <h3 className="modal-title" style={{ fontSize: '18px', fontWeight: 'bold' }}>Chấm công thủ công</h3>
              <button className="modal-close" onClick={() => setShowManualModal(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleManualSubmit}>
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', background: '#f8fafc', padding: '12px', borderRadius: '8px' }}>
                  <div className="avatar-badge">{getAvatarLetters(manualEmployee.name)}</div>
                  <div>
                    <div style={{ fontWeight: 'bold', color: 'var(--color-text-dark)' }}>{manualEmployee.name}</div>
                    <div style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>{manualEmployee.employeeCode}</div>
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Ngày chấm công</label>
                  <input 
                    type="date" 
                    value={selectedDate} 
                    disabled 
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #cbd5e1',
                      borderRadius: '6px',
                      background: '#f1f5f9',
                      color: 'var(--color-text-light)',
                      cursor: 'not-allowed'
                    }}
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Loại ghi công</label>
                  <div style={{ display: 'flex', gap: '16px' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                      <input 
                        type="radio" 
                        name="manualType" 
                        value="IN" 
                        checked={manualType === 'IN'} 
                        onChange={() => setManualType('IN')} 
                      />
                      Vào (CHECK_IN)
                    </label>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', fontSize: '14px' }}>
                      <input 
                        type="radio" 
                        name="manualType" 
                        value="OUT" 
                        checked={manualType === 'OUT'} 
                        onChange={() => setManualType('OUT')} 
                      />
                      Ra (CHECK_OUT)
                    </label>
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Giờ chấm công</label>
                  <input 
                    type="time" 
                    value={manualTime} 
                    onChange={(e) => setManualTime(e.target.value)} 
                    required
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #cbd5e1',
                      borderRadius: '6px',
                      outline: 'none'
                    }}
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: 'var(--color-text-dark)' }}>Ghi chú</label>
                  <textarea 
                    value={manualNote} 
                    onChange={(e) => setManualNote(e.target.value)}
                    placeholder="Lý do quên chấm công, đi công tác,..."
                    rows={3}
                    style={{
                      padding: '8px 12px',
                      border: '1px solid #cbd5e1',
                      borderRadius: '6px',
                      outline: 'none',
                      fontFamily: 'inherit',
                      resize: 'none'
                    }}
                  />
                </div>
              </div>

              <div className="modal-footer" style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', padding: '16px 24px', borderTop: '1px solid #e2e8f0' }}>
                <button 
                  type="button" 
                  className="action-btn-outline" 
                  onClick={() => setShowManualModal(false)}
                  disabled={manualSubmitting}
                >
                  Hủy
                </button>
                <button 
                  type="submit" 
                  className="action-btn-primary"
                  disabled={manualSubmitting}
                >
                  {manualSubmitting ? 'Đang lưu...' : 'Xác nhận'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

export default App;

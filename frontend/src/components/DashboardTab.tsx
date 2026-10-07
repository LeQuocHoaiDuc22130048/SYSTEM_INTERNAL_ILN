import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Wrench, Activity, CheckCircle2, Cpu, Users, UserPlus,
  AlertTriangle, RefreshCw, ArrowRight, UserCheck,
  CalendarCheck, Clock, LogIn, LogOut,
  Calendar, Zap, CalendarDays, CalendarRange, SlidersHorizontal, Inbox
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { getAuthHeaders } from '../utils/auth';
import { getAvatarLetters } from '../utils/employee';
import { isAdminOrAbove } from '../utils/permissions';
import './DashboardTab.css';

export type TimeRangePreset = 'today' | '7days' | 'month' | 'custom';

// Helper chuyển Date sang YYYY-MM-DD theo giờ địa phương (local timezone)
const toLocalDateStr = (date: Date): string => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

// Helper tạo đường cong Bezier SVG mượt mà qua các điểm tọa độ
const getCurvedPath = (points: { x: number; y: number }[]): string => {
  if (points.length === 0) return '';
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`;
  let d = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i];
    const p1 = points[i + 1];
    const cx1 = Math.round(p0.x + (p1.x - p0.x) / 3);
    const cy1 = Math.round(p0.y);
    const cx2 = Math.round(p0.x + (2 * (p1.x - p0.x)) / 3);
    const cy2 = Math.round(p1.y);
    d += ` C ${cx1} ${cy1}, ${cx2} ${cy2}, ${p1.x} ${p1.y}`;
  }
  return d;
};

interface DashboardTabProps {
  setActiveTab: (tab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts') => void;
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
  onViewPersonalAttendance?: (emp: { id: string; name: string; dept: string }) => void;
  currentMonth?: number;
  currentYear?: number;
  refreshTrigger?: number;
}

interface OrderRecord {
  id: string;
  orderCode: string;
  deviceName: string;
  customerName: string;
  status: string;
  assignedTo?: { id: string; fullName: string } | null;
  assignees?: { id: string; fullName: string }[];
  createdAt: string;
}

interface BoardRecord {
  id: string;
  name: string;
  status: string;
}

interface AttendanceResponseRecord {
  id: string;
  employeeId: string;
  employeeName: string;
  employeeCode: string;
  avatarUrl?: string;
  type: string;
  checkTime: string;
  note?: string;
}

interface AttendanceReportRecord {
  date: string;
  checkIn: string | null;
  checkOut: string | null;
  totalMinutes?: number;
  isLate: boolean;
  isEarlyLeave: boolean;
  shiftStart?: string;
  shiftEnd?: string;
  records?: AttendanceResponseRecord[];
}

interface PersonalEvent {
  id: string;
  logTime: string;
  type: string;
  source: string;
  confidence: number;
  note?: string;
}

interface PersonalHistoryDay {
  date: string;
  dayOfWeek: string;
  status: string;
  events: PersonalEvent[];
}

interface PersonalSummary {
  workDays: number;
  totalHours: number;
  lateCount: number;
  absentDays: number;
  overtimeHours: number;
}

interface MyTodayAttendance {
  date: string;
  checkIn: string | null;
  checkOut: string | null;
  totalMinutes?: number | null;
  isLate: boolean;
  isEarlyLeave: boolean;
  shiftStart?: string;
  shiftEnd?: string;
  records?: AttendanceResponseRecord[];
}

export const DashboardTab: React.FC<DashboardTabProps> = ({
  setActiveTab,
  showToast,
  currentUser,
  onViewPersonalAttendance,
  currentMonth,
  currentYear,
  refreshTrigger,
}) => {
  const [orders, setOrders] = useState<OrderRecord[]>([]);
  const [boards, setBoards] = useState<BoardRecord[]>([]);
  const [employees, setEmployees] = useState<any[]>([]);
  const [attendance, setAttendance] = useState<AttendanceReportRecord[]>([]);
  const [pendingUsers, setPendingUsers] = useState<any[]>([]);
  const [myToday, setMyToday] = useState<MyTodayAttendance | null>(null);
  const [personalDays, setPersonalDays] = useState<PersonalHistoryDay[]>([]);
  const [personalSummary, setPersonalSummary] = useState<PersonalSummary | null>(null);
  const [loading, setLoading] = useState(true);

  // Bộ lọc khoảng thời gian Dashboard
  const [rangeType, setRangeType] = useState<TimeRangePreset>('7days');
  const [customStartDate, setCustomStartDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() - 6);
    return toLocalDateStr(d);
  });
  const [customEndDate, setCustomEndDate] = useState<string>(() => toLocalDateStr(new Date()));
  const [hoveredSlotIndex, setHoveredSlotIndex] = useState<number | null>(null);

  const isAdmin = useMemo(() => isAdminOrAbove(currentUser), [currentUser]);

  const fetchDashboardData = useCallback(async () => {
    try {
      const headers = getAuthHeaders();
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
      const queryYear = currentYear || today.getFullYear();
      const queryMonth = currentMonth || (today.getMonth() + 1);

      // 1. Fetch Orders
      const ordersRes = await fetch('/api/v1/repair-orders?size=200', { headers });
      const ordersData = ordersRes.ok ? await ordersRes.json() : null;
      const fetchedOrders: OrderRecord[] = ordersData?.data?.content || ordersData?.data || [];

      // 2. Fetch Boards
      const boardsRes = await fetch('/api/v1/boards?size=200', { headers });
      const boardsData = boardsRes.ok ? await boardsRes.json() : null;
      const fetchedBoards: BoardRecord[] = boardsData?.data?.content || boardsData?.data || [];

      let fetchedEmployees: any[] = [];
      let fetchedAttendance: AttendanceReportRecord[] = [];
      let fetchedPending: any[] = [];
      let fetchedMyToday: MyTodayAttendance | null = null;
      let fetchedPersonalDays: PersonalHistoryDay[] = [];
      let fetchedPersonalSummary: PersonalSummary | null = null;

      if (isAdmin) {
        // 3. Fetch Employees (Manager/Admin)
        const employeesRes = await fetch('/api/v1/employees?size=200', { headers });
        if (employeesRes.ok) {
          const empData = await employeesRes.json();
          fetchedEmployees = empData?.data?.employees || empData?.data?.content || empData?.data || [];
        }

        // 4. Fetch Today Attendance for all employees (Admin)
        const attendanceRes = await fetch(`/api/v1/attendance/report?date=${todayStr}`, { headers });
        if (attendanceRes.ok) {
          const attData = await attendanceRes.json();
          fetchedAttendance = attData?.data || [];
        }

        // 5. Fetch Pending Users (Admin)
        const pendingRes = await fetch('/api/v1/auth/pending?size=200', { headers });
        if (pendingRes.ok) {
          const pendData = await pendingRes.json();
          fetchedPending = pendData?.data?.content || pendData?.data || [];
        }
      } else {
        // Tài khoản có vai trò khác quản trị viên: Lấy ngày chấm công cá nhân
        // 1. Chấm công hôm nay của cá nhân
        try {
          const todayRes = await fetch('/api/v1/attendance/me/today', { headers });
          if (todayRes.ok) {
            const todayData = await todayRes.json();
            fetchedMyToday = todayData?.data || null;
          }
        } catch (err) {
          console.warn('Lỗi khi tải chấm công hôm nay của cá nhân:', err);
        }

        // 2. Danh sách các ngày chấm công trong tháng & tổng hợp công cá nhân
        if (currentUser?.id) {
          try {
            const logsRes = await fetch(`/api/attendance/${currentUser.id}/logs?year=${queryYear}&month=${queryMonth}`, { headers });
            if (logsRes.ok) {
              const logsData = await logsRes.json();
              if (logsData?.data) {
                fetchedPersonalDays = logsData.data.days || [];
                fetchedPersonalSummary = logsData.data.summary || null;
              }
            }
          } catch (err) {
            console.warn('Lỗi khi tải lịch sử ngày chấm công cá nhân:', err);
          }
        }
      }

      setOrders(fetchedOrders);
      setBoards(fetchedBoards);
      setEmployees(fetchedEmployees);
      setAttendance(fetchedAttendance);
      setPendingUsers(fetchedPending);
      setMyToday(fetchedMyToday);
      setPersonalDays(fetchedPersonalDays);
      setPersonalSummary(fetchedPersonalSummary);
    } catch (e: any) {
      console.error('Error fetching dashboard stats:', e);
      showToast('Có lỗi xảy ra khi tải số liệu thống kê.');
    } finally {
      setLoading(false);
    }
  }, [showToast, isAdmin, currentUser?.id, currentYear, currentMonth]);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  const handleRefresh = useCallback(() => {
    fetchDashboardData();
    showToast('Đang làm mới dữ liệu...');
  }, [fetchDashboardData, showToast]);

  // Lắng nghe yêu cầu làm mới dữ liệu từ Header
  useEffect(() => {
    if (refreshTrigger && refreshTrigger > 0) {
      handleRefresh();
    }
  }, [refreshTrigger, handleRefresh]);

  // Helper tính giờ vào, ra và tổng thời gian làm việc trong ngày
  const getDayInOut = useCallback((day: PersonalHistoryDay) => {
    if (!day.events || day.events.length === 0) {
      return { checkIn: null, checkOut: null, duration: null };
    }
    const inEv = day.events.find(e => e.type === 'IN' || e.type === 'CHECK_IN');
    const outEv = [...day.events].reverse().find(e => e.type === 'OUT' || e.type === 'CHECK_OUT');

    let duration: string | null = null;
    if (inEv && outEv && inEv.logTime && outEv.logTime) {
      const [ih, im] = inEv.logTime.split(':').map(Number);
      const [oh, om] = outEv.logTime.split(':').map(Number);
      if (!isNaN(ih) && !isNaN(im) && !isNaN(oh) && !isNaN(om)) {
        let diffMin = (oh * 60 + om) - (ih * 60 + im);
        if (ih * 60 + im < 12 * 60 + 30 && oh * 60 + om > 13 * 60) {
          diffMin = Math.max(0, diffMin - 90);
        }
        if (diffMin > 0) {
          const hrs = Math.floor(diffMin / 60);
          const mins = diffMin % 60;
          duration = `${hrs}h${mins > 0 ? `${mins}p` : ''}`;
        }
      }
    }

    return {
      checkIn: inEv?.logTime || null,
      checkOut: outEv?.logTime || null,
      duration
    };
  }, []);

  // ── Tính toán Date Range từ bộ lọc khoảng thời gian ──────────────────────
  const dateRange = useMemo(() => {
    const today = new Date();
    const todayStr = toLocalDateStr(today);
    let startDateStr = todayStr;
    let endDateStr = todayStr;

    if (rangeType === 'today') {
      startDateStr = todayStr;
      endDateStr = todayStr;
    } else if (rangeType === '7days') {
      const start = new Date(today);
      start.setDate(today.getDate() - 6);
      startDateStr = toLocalDateStr(start);
      endDateStr = todayStr;
    } else if (rangeType === 'month') {
      const y = currentYear || today.getFullYear();
      const m = currentMonth || (today.getMonth() + 1);
      startDateStr = `${y}-${String(m).padStart(2, '0')}-01`;
      const lastDay = new Date(y, m, 0).getDate();
      endDateStr = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
    } else if (rangeType === 'custom') {
      let s = customStartDate || todayStr;
      let e = customEndDate || todayStr;
      if (s > e) {
        const tmp = s;
        s = e;
        e = tmp;
      }
      startDateStr = s;
      endDateStr = e;
    }

    const start = new Date(startDateStr + 'T00:00:00');
    const end = new Date(endDateStr + 'T23:59:59.999');

    return {
      startDateStr,
      endDateStr,
      start,
      end
    };
  }, [rangeType, customStartDate, customEndDate, currentYear, currentMonth]);

  // Nhãn tóm tắt khoảng thời gian đang lọc
  const filterSummaryText = useMemo(() => {
    const { startDateStr, endDateStr, start, end } = dateRange;
    const formatVi = (s: string) => {
      const parts = s.split('-');
      if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
      return s;
    };
    if (rangeType === 'today') {
      return `Hôm nay: ${formatVi(startDateStr)}`;
    }
    const diffDays = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));
    return `${formatVi(startDateStr)} - ${formatVi(endDateStr)} (${diffDays} ngày)`;
  }, [dateRange, rangeType]);

  // Danh sách đơn hàng đã được lọc theo khoảng thời gian
  const filteredOrders = useMemo(() => {
    return orders.filter(o => {
      if (!o.createdAt) return true;
      const d = new Date(o.createdAt);
      if (isNaN(d.getTime())) return true;
      const orderDateStr = toLocalDateStr(d);
      return orderDateStr >= dateRange.startDateStr && orderDateStr <= dateRange.endDateStr;
    });
  }, [orders, dateRange]);

  // Lịch sử chấm công cá nhân lọc theo khoảng thời gian
  const filteredPersonalDays = useMemo(() => {
    return personalDays.filter(d => {
      return d.date >= dateRange.startDateStr && d.date <= dateRange.endDateStr;
    });
  }, [personalDays, dateRange]);

  // Thống kê tóm tắt cá nhân tính lại theo khoảng thời gian
  const filteredPersonalSummary = useMemo(() => {
    if (rangeType === 'month' && personalSummary) {
      return personalSummary;
    }
    const workDays = filteredPersonalDays.filter(d =>
      !['ABSENT', 'HOLIDAY', 'FUTURE'].includes(d.status.toUpperCase())
    ).length;
    const lateCount = filteredPersonalDays.filter(d =>
      ['LATE', 'HALF_DAY_AFTERNOON'].includes(d.status.toUpperCase())
    ).length;
    const absentDays = filteredPersonalDays.filter(d =>
      d.status.toUpperCase() === 'ABSENT'
    ).length;

    let totalMinutes = 0;
    let overtimeHours = 0;
    filteredPersonalDays.forEach(d => {
      if (d.status.toUpperCase() === 'OVERTIME') overtimeHours += 2;
      const inOut = getDayInOut(d);
      if (inOut.duration) {
        const match = inOut.duration.match(/(\d+)h(?:(\d+)p)?/);
        if (match) {
          totalMinutes += parseInt(match[1], 10) * 60 + (match[2] ? parseInt(match[2], 10) : 0);
        }
      }
    });
    const totalHours = Math.round((totalMinutes / 60) * 10) / 10;
    return {
      workDays,
      totalHours,
      lateCount,
      absentDays,
      overtimeHours
    };
  }, [filteredPersonalDays, rangeType, personalSummary, getDayInOut]);

  // ── Calculated Stats theo bộ lọc ──────────────────────────────────────────
  const stats = useMemo(() => {
    // 1. Total Orders trong khoảng lọc
    const totalOrders = filteredOrders.length;

    // 2. In progress orders trong khoảng lọc
    const inProgressOrders = filteredOrders.filter(o =>
      ['IN_PROGRESS', 'CHECKING', 'CHECKED', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())
    ).length;

    // 3. Completed orders trong khoảng lọc
    const completedOrders = filteredOrders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;

    // 4. Available boards ratio (tài sản kho hiện hữu)
    const availableBoards = boards.filter(b => b.status.toUpperCase() === 'AVAILABLE').length;
    const totalBoards = boards.length;

    // 5. Active attendance record ratio
    const checkedInEmployees = attendance.length;
    const totalEmployees = employees.length || checkedInEmployees || 1;

    // 6. Đơn chưa gán KTV và chưa sửa chữa (đối với các đơn chưa hoàn thành)
    const unassignedOrders = filteredOrders.filter(o => {
      const status = (o.status || '').toUpperCase();
      // Bỏ qua các đơn đã hoàn thành / đã giao / đã hủy
      const isCompleted = ['COMPLETED', 'DELIVERED', 'CANCELLED'].includes(status);
      if (isCompleted) return false;

      // Bỏ qua các đơn đang sửa chữa
      const isRepairing = status === 'IN_PROGRESS';
      if (isRepairing) return false;

      // Kiểm tra chưa gán kỹ thuật viên (không có assignedTo và assignees rỗng)
      const hasAssignee = Boolean(o.assignedTo) || (Array.isArray(o.assignees) && o.assignees.length > 0);
      return !hasAssignee;
    }).length;

    // 7. Maintenance boards (tài sản kho bảo trì)
    const maintenanceBoards = boards.filter(b =>
      ['MAINTENANCE', 'IN_REPAIR'].includes(b.status.toUpperCase())
    ).length;

    // 8. Pending approval users
    const pendingCount = pendingUsers.length;

    return {
      totalOrders,
      inProgressOrders,
      completedOrders,
      availableBoards,
      totalBoards,
      checkedInEmployees,
      totalEmployees,
      unassignedOrders,
      maintenanceBoards,
      pendingCount
    };
  }, [filteredOrders, boards, employees, attendance, pendingUsers]);

  // ── Combo Chart (Bar & Line) Calculation ──────────────────────────────────
  const comboChartData = useMemo(() => {
    const today = new Date();
    const todayStr = toLocalDateStr(today);

    interface RawSlot {
      label: string;
      fullDate: string;
      pending: number;
      inProgress: number;
      completed: number;
      total: number;
      isZero: boolean;
    }
    let rawSlots: RawSlot[];
    let chartTitle: string;
    let chartSubtitle: string;

    if (rangeType === 'today') {
      chartTitle = 'Thống kê đơn hôm nay theo khung giờ (Cột & Đường)';
      chartSubtitle = 'Phân bố đơn phát sinh trong các khung giờ làm việc hôm nay';

      const timeSlots = [
        { label: '07h-09h', fullLabel: 'Đầu sáng (07:00 - 09:30)', startH: 7, startM: 0, endH: 9, endM: 30 },
        { label: '09h-12h', fullLabel: 'Giữa sáng (09:30 - 12:00)', startH: 9, startM: 30, endH: 12, endM: 0 },
        { label: '12h-14h', fullLabel: 'Nghỉ trưa (12:00 - 14:00)', startH: 12, startM: 0, endH: 14, endM: 0 },
        { label: '14h-16h', fullLabel: 'Đầu chiều (14:00 - 16:30)', startH: 14, startM: 0, endH: 16, endM: 30 },
        { label: '16h-18h', fullLabel: 'Cuối chiều (16:30 - 18:30)', startH: 16, startM: 30, endH: 18, endM: 30 },
        { label: '18h-21h', fullLabel: 'Tối & Tăng ca (18:30 - 21:00)', startH: 18, startM: 30, endH: 21, endM: 0 },
      ];

      const todayOrders = orders.filter(o => {
        if (!o.createdAt) return false;
        const d = new Date(o.createdAt);
        return !isNaN(d.getTime()) && toLocalDateStr(d) === todayStr;
      });

      rawSlots = timeSlots.map(slot => {
        const slotOrders = todayOrders.filter(o => {
          const d = new Date(o.createdAt);
          const mins = d.getHours() * 60 + d.getMinutes();
          const startMin = slot.startH * 60 + slot.startM;
          const endMin = slot.endH * 60 + slot.endM;
          return mins >= startMin && mins < endMin;
        });

        const pending = slotOrders.filter(o => ['PENDING', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())).length;
        const inProgress = slotOrders.filter(o => ['IN_PROGRESS', 'CHECKING', 'CHECKED'].includes(o.status.toUpperCase())).length;
        const completed = slotOrders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;
        const total = pending + inProgress + completed;

        return {
          label: slot.label,
          fullDate: `${slot.fullLabel} · Hôm nay`,
          pending,
          inProgress,
          completed,
          total,
          isZero: total === 0
        };
      });
    } else {
      const dayList: Date[] = [];
      if (rangeType === '7days') {
        chartTitle = 'Thống kê đơn 7 ngày qua (Cột & Đường)';
        chartSubtitle = 'Theo dõi tồn đọng, đang xử lý và sản lượng hoàn thành mỗi ngày';
        for (let i = 6; i >= 0; i--) {
          const d = new Date(today);
          d.setDate(today.getDate() - i);
          dayList.push(d);
        }
      } else if (rangeType === 'month') {
        const y = currentYear || today.getFullYear();
        const m = currentMonth || (today.getMonth() + 1);
        chartTitle = `Thống kê đơn Tháng ${m}/${y} (Cột & Đường)`;
        chartSubtitle = 'Tiến độ xử lý đơn sửa chữa theo từng ngày trong tháng';
        const totalDays = new Date(y, m, 0).getDate();
        for (let d = 1; d <= totalDays; d++) {
          dayList.push(new Date(y, m - 1, d));
        }
      } else {
        // Custom
        const start = new Date(dateRange.startDateStr + 'T00:00:00');
        const end = new Date(dateRange.endDateStr + 'T00:00:00');
        const diffTime = end.getTime() - start.getTime();
        const diffDays = Math.min(31, Math.max(1, Math.round(diffTime / 86400000) + 1));
        chartTitle = `Thống kê đơn tùy chỉnh (${dateRange.startDateStr} → ${dateRange.endDateStr})`;
        chartSubtitle = 'Biểu đồ phân tích đơn sửa chữa theo khoảng thời gian đã chọn';
        for (let i = 0; i < diffDays; i++) {
          const d = new Date(start);
          d.setDate(start.getDate() + i);
          dayList.push(d);
        }
      }

      const fullWeekdays = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

      rawSlots = dayList.map(date => {
        const dateString = toLocalDateStr(date);
        const label = `${date.getDate()}/${date.getMonth() + 1}`;
        const fullDate = `${fullWeekdays[date.getDay()]}, ${date.getDate()}/${date.getMonth() + 1}/${date.getFullYear()}`;

        const dayOrders = orders.filter(o => {
          if (!o.createdAt) return false;
          const d = new Date(o.createdAt);
          return !isNaN(d.getTime()) && toLocalDateStr(d) === dateString;
        });

        const pending = dayOrders.filter(o => ['PENDING', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())).length;
        const inProgress = dayOrders.filter(o => ['IN_PROGRESS', 'CHECKING', 'CHECKED'].includes(o.status.toUpperCase())).length;
        const completed = dayOrders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;
        const total = pending + inProgress + completed;

        return {
          label,
          fullDate,
          pending,
          inProgress,
          completed,
          total,
          isZero: total === 0
        };
      });
    }

    // Tính trần trục Y
    const maxVal = Math.max(
      8,
      ...rawSlots.flatMap(s => [s.pending, s.inProgress, s.completed, s.total])
    );
    const yMax = maxVal % 4 === 0 ? maxVal : maxVal + (4 - (maxVal % 4));

    // Kích thước SVG
    const svgWidth = 680;
    const paddingLeft = 46;
    const paddingRight = 24;
    const paddingTop = 26;
    const graphH = 168;
    const baseY = paddingTop + graphH;
    const graphW = svgWidth - paddingLeft - paddingRight;

    const slotCount = rawSlots.length || 1;
    const slotW = graphW / slotCount;

    const points: { x: number; y: number }[] = [];

    const computedSlots = rawSlots.map((item, index) => {
      const slotX = paddingLeft + index * slotW;
      const cx = Math.round(slotX + slotW / 2);
      const barW = Math.max(3, Math.min(13, Math.floor((slotW - 6) / 2)));

      const hPending = Math.round((item.pending / yMax) * graphH);
      const hProgress = Math.round((item.inProgress / yMax) * graphH);
      const hCompleted = Math.round((item.completed / yMax) * graphH);

      const bar1X = cx - barW - 1;
      const bar2X = cx + 1;
      const lineY = baseY - hCompleted;

      points.push({ x: cx, y: lineY });

      const showXLabel = slotCount <= 14
        ? true
        : (index % Math.ceil(slotCount / 8) === 0 || index === slotCount - 1);

      return {
        ...item,
        slotX,
        slotW,
        cx,
        barW,
        hPending,
        hProgress,
        hCompleted,
        bar1X,
        bar2X,
        lineY,
        showXLabel
      };
    });

    const linePath = getCurvedPath(points);
    const areaPath = points.length > 0
      ? `${linePath} L ${points[points.length - 1].x} ${baseY} L ${points[0].x} ${baseY} Z`
      : '';

    const activeDaysCount = rawSlots.filter(s => !s.isZero).length;

    return {
      title: chartTitle,
      subtitle: chartSubtitle,
      slots: computedSlots,
      yMax,
      baseY,
      paddingTop,
      paddingLeft,
      graphW,
      graphH,
      linePath,
      areaPath,
      activeDaysCount,
      totalSlots: slotCount
    };
  }, [orders, rangeType, dateRange, currentYear, currentMonth]);

  // ── Pie/Donut Chart Calculation (theo khoảng thời gian lọc) ────────────────
  const pieChartData = useMemo(() => {
    const pending = filteredOrders.filter(o =>
      ['PENDING', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())
    ).length;
    const inProgress = filteredOrders.filter(o =>
      ['IN_PROGRESS', 'CHECKING', 'CHECKED'].includes(o.status.toUpperCase())
    ).length;
    const completed = filteredOrders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;
    const delivered = filteredOrders.filter(o => o.status.toUpperCase() === 'DELIVERED').length;
    const total = pending + inProgress + completed + delivered;

    return {
      pending,
      inProgress,
      completed,
      delivered,
      total
    };
  }, [filteredOrders]);

  // Helper to format checkin status pill
  const getAttendanceStatusBadge = (rec: AttendanceReportRecord) => {
    if (rec.isLate && rec.isEarlyLeave) {
      return <span className="att-badge warning">Muộn & Về sớm</span>;
    }
    if (rec.isLate) {
      return <span className="att-badge warning">Đi muộn</span>;
    }
    if (rec.isEarlyLeave) {
      return <span className="att-badge warning">Về sớm</span>;
    }
    if (rec.checkIn) {
      return <span className="att-badge success">Đủ công</span>;
    }
    return <span className="att-badge danger">Vắng</span>;
  };

  const getOrderStatusLabel = (status: string) => {
    switch (status.toUpperCase()) {
      case 'PENDING': return { label: 'Chưa kiểm tra', className: 'os-pending' };
      case 'WAITING_FOR_CHECK': return { label: 'Chờ kiểm tra', className: 'os-checking' };
      case 'CHECKING': return { label: 'Đang kiểm tra', className: 'os-checking' };
      case 'CHECKED': return { label: 'Đã kiểm tra', className: 'os-checked' };
      case 'IN_PROGRESS': return { label: 'Đang sửa', className: 'os-progress' };
      case 'COMPLETED': return { label: 'Hoàn thành', className: 'os-completed' };
      case 'DELIVERED': return { label: 'Đã giao', className: 'os-delivered' };
      case 'CANCELLED': return { label: 'Đã trả', className: 'os-cancelled' };
      default: return { label: status, className: 'os-pending' };
    }
  };

  // Helper to format personal attendance status badge
  const getPersonalDayBadge = (status: string) => {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return <span className="att-badge success">Đủ công</span>;
      case 'LATE':
        return <span className="att-badge warning">Vào muộn</span>;
      case 'OVERTIME':
        return <span className="att-badge purple">Tăng ca</span>;
      case 'HALF_DAY_MORNING':
        return <span className="att-badge info">Nửa công (Sáng)</span>;
      case 'HALF_DAY_AFTERNOON':
        return <span className="att-badge info">Nửa công (Chiều)</span>;
      case 'HALF_DAY':
        return <span className="att-badge info">Nửa công (0.5)</span>;
      case 'LEAVE':
        return <span className="att-badge info">Nghỉ phép</span>;
      case 'ABSENT':
        return <span className="att-badge danger">Vắng KP</span>;
      case 'HOLIDAY':
        return <span className="att-badge secondary">Nghỉ lễ/CN</span>;
      default:
        return <span className="att-badge secondary">{status}</span>;
    }
  };

  const formatDayDisplay = (dateStr: string, dayOfWeek: string) => {
    try {
      const parts = dateStr.split('-');
      if (parts.length === 3) {
        return `${dayOfWeek}, ${parts[2]}/${parts[1]}`;
      }
    } catch {
      // fallback
    }
    return `${dayOfWeek}, ${dateStr}`;
  };

  const myTodayTimes = useMemo(() => {
    if (!myToday) return { checkInStr: null, checkOutStr: null };
    const formatTime = (timeStr?: string | null) => {
      if (!timeStr) return null;
      try {
        return new Date(timeStr).toLocaleTimeString('vi-VN', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: false
        });
      } catch {
        return null;
      }
    };
    return {
      checkInStr: formatTime(myToday.checkIn),
      checkOutStr: formatTime(myToday.checkOut)
    };
  }, [myToday]);

  // Phần tử đang được hover trên biểu đồ kết hợp
  const hoveredItem = hoveredSlotIndex !== null && comboChartData.slots[hoveredSlotIndex]
    ? comboChartData.slots[hoveredSlotIndex]
    : null;

  if (loading) {
    return <div className="dashboard-loading"><RefreshCw size={24} className="spin" /> Đang tải số liệu...</div>;
  }

  // Calculate donut slices parameters
  const donutR = 50;
  const donutCircumference = 2 * Math.PI * donutR;

  const slices = [
    { name: 'Chờ xử lý', val: pieChartData.pending, color: '#f59e0b' },
    { name: 'Đang sửa', val: pieChartData.inProgress, color: '#3b82f6' },
    { name: 'Hoàn thành', val: pieChartData.completed, color: '#10b981' },
    { name: 'Đã giao', val: pieChartData.delivered, color: '#64748b' }
  ].filter(s => s.val > 0);

  const totalPie = pieChartData.total || 1;

  return (
    <div className="dashboard-tab">
      {/* ── Bộ lọc linh hoạt (Filters) ── */}
      <div className="dashboard-filter-bar">
        <div className="filter-left-section">
          <div className="filter-label">
            <Calendar size={15} />
            <span>Khoảng thời gian:</span>
          </div>

          <div className="preset-buttons" role="tablist" aria-label="Bộ lọc thời gian">
            <button
              type="button"
              className={`filter-preset-btn ${rangeType === 'today' ? 'active' : ''}`}
              onClick={() => setRangeType('today')}
            >
              <Zap size={14} />
              <span>Hôm nay</span>
            </button>
            <button
              type="button"
              className={`filter-preset-btn ${rangeType === '7days' ? 'active' : ''}`}
              onClick={() => setRangeType('7days')}
            >
              <CalendarDays size={14} />
              <span>7 ngày qua</span>
            </button>
            <button
              type="button"
              className={`filter-preset-btn ${rangeType === 'month' ? 'active' : ''}`}
              onClick={() => setRangeType('month')}
            >
              <CalendarRange size={14} />
              <span>Tháng này</span>
            </button>
            <button
              type="button"
              className={`filter-preset-btn ${rangeType === 'custom' ? 'active' : ''}`}
              onClick={() => setRangeType('custom')}
            >
              <SlidersHorizontal size={14} />
              <span>Tùy chỉnh</span>
            </button>
          </div>

          {rangeType === 'custom' && (
            <div className="custom-range-inputs">
              <div className="custom-input-group">
                <span className="custom-input-label">Từ:</span>
                <input
                  type="date"
                  value={customStartDate}
                  max={customEndDate || toLocalDateStr(new Date())}
                  onChange={(e) => setCustomStartDate(e.target.value)}
                  className="custom-date-field"
                  aria-label="Từ ngày"
                />
              </div>
              <span className="range-arrow">→</span>
              <div className="custom-input-group">
                <span className="custom-input-label">Đến:</span>
                <input
                  type="date"
                  value={customEndDate}
                  min={customStartDate}
                  max={toLocalDateStr(new Date())}
                  onChange={(e) => setCustomEndDate(e.target.value)}
                  className="custom-date-field"
                  aria-label="Đến ngày"
                />
              </div>
            </div>
          )}
        </div>

        <div className="filter-summary-pill" title="Khoảng thời gian đang áp dụng cho toàn bộ widget">
          <Clock size={13} />
          <span>{filterSummaryText}</span>
        </div>
      </div>

      {/* Grid containing 8 stats card */}
      <div className="dashboard-stats-grid">
        {/* Card 1: Tổng đơn */}
        <div className="stat-card border-blue">
          <div className="stat-info">
            <span className="stat-label">Tổng đơn</span>
            <span className="stat-value">{stats.totalOrders}</span>
            <span className="stat-sub">Tổng số đơn trong khoảng lọc</span>
          </div>
          <div className="stat-icon-wrapper bg-blue">
            <Wrench size={20} className="icon-blue" />
          </div>
        </div>

        {/* Card 2: Đang xử lý */}
        <div className="stat-card border-orange">
          <div className="stat-info">
            <span className="stat-label">Đang xử lý</span>
            <span className="stat-value">{stats.inProgressOrders}</span>
            <span className="stat-sub">Đơn cần theo dõi</span>
          </div>
          <div className="stat-icon-wrapper bg-orange">
            <Activity size={20} className="icon-orange" />
          </div>
        </div>

        {/* Card 3: Hoàn thành */}
        <div className="stat-card border-green">
          <div className="stat-info">
            <span className="stat-label">Hoàn thành</span>
            <span className="stat-value">{stats.completedOrders}</span>
            <span className="stat-sub">Đơn đã sửa xong</span>
          </div>
          <div className="stat-icon-wrapper bg-green">
            <CheckCircle2 size={20} className="icon-green" />
          </div>
        </div>

        {/* Card 4: Bo mạch sẵn sàng */}
        <div className="stat-card border-purple">
          <div className="stat-info">
            <span className="stat-label">Bo mạch sẵn sàng</span>
            <span className="stat-value">{stats.availableBoards}/{stats.totalBoards}</span>
            <span className="stat-sub">Bo mạch có sẵn trong kho</span>
          </div>
          <div className="stat-icon-wrapper bg-purple">
            <Cpu size={20} className="icon-purple" />
          </div>
        </div>

        {/* Card 5: Nhân viên có mặt (Admin) HOẶC Ngày công của tôi (Non-admin) */}
        {isAdmin ? (
          <div className="stat-card border-teal">
            <div className="stat-info">
              <span className="stat-label">Nhân viên có mặt</span>
              <span className="stat-value">{stats.checkedInEmployees}/{stats.totalEmployees}</span>
              <span className="stat-sub">Đã check-in hệ thống</span>
            </div>
            <div className="stat-icon-wrapper bg-teal">
              <Users size={20} className="icon-teal" />
            </div>
          </div>
        ) : (
          <div className="stat-card border-teal">
            <div className="stat-info">
              <span className="stat-label">{rangeType === 'month' ? 'Công tháng này' : 'Ngày công'}</span>
              <span className="stat-value">{filteredPersonalSummary ? filteredPersonalSummary.workDays : 0} công</span>
              <span className="stat-sub">
                {filteredPersonalSummary ? `Tổng giờ làm: ${filteredPersonalSummary.totalHours}h` : filterSummaryText}
              </span>
            </div>
            <div className="stat-icon-wrapper bg-teal">
              <CalendarCheck size={20} className="icon-teal" />
            </div>
          </div>
        )}

        {/* Card 6: Đơn chờ phân công */}
        <div className="stat-card border-pink">
          <div className="stat-info">
            <span className="stat-label">Chờ phân công</span>
            <span className="stat-value">{stats.unassignedOrders}</span>
            <span className="stat-sub">Đơn chưa sửa & chưa gán KTV</span>
          </div>
          <div className="stat-icon-wrapper bg-pink">
            <UserPlus size={20} className="icon-pink" />
          </div>
        </div>

        {/* Card 7: Bo mạch bảo trì */}
        <div className="stat-card border-red">
          <div className="stat-info">
            <span className="stat-label">Bo mạch bảo trì</span>
            <span className="stat-value">{stats.maintenanceBoards}</span>
            <span className="stat-sub">Đang sửa chữa/bảo trì</span>
          </div>
          <div className="stat-icon-wrapper bg-red">
            <AlertTriangle size={20} className="icon-red" />
          </div>
        </div>

        {/* Card 8: Tài khoản chờ duyệt (Admin) HOẶC Đi muộn / Tăng ca (Non-admin) */}
        {isAdmin ? (
          <div className="stat-card border-amber">
            <div className="stat-info">
              <span className="stat-label">Tài khoản chờ duyệt</span>
              <span className="stat-value">{stats.pendingCount}</span>
              <span className="stat-sub">Chờ xét duyệt hệ thống</span>
            </div>
            <div className="stat-icon-wrapper bg-amber">
              <UserCheck size={20} className="icon-amber" />
            </div>
          </div>
        ) : (
          <div className="stat-card border-amber">
            <div className="stat-info">
              <span className="stat-label">Đi muộn / Về sớm</span>
              <span className="stat-value">{filteredPersonalSummary ? filteredPersonalSummary.lateCount : 0} lần</span>
              <span className="stat-sub">
                {filteredPersonalSummary && filteredPersonalSummary.overtimeHours > 0
                  ? `Tăng ca: ${filteredPersonalSummary.overtimeHours}h`
                  : filteredPersonalSummary?.lateCount === 0
                    ? 'Chuyên cần đúng giờ'
                    : 'Cần chú ý giờ giấc'}
              </span>
            </div>
            <div className="stat-icon-wrapper bg-amber">
              <Clock size={20} className="icon-amber" />
            </div>
          </div>
        )}
      </div>

      {/* Main content split */}
      <div className="dashboard-content-split">
        {/* Left Side: Charts */}
        <div className="dashboard-charts-column">
          {/* Enhanced Combo Chart (Bar & Line) */}
          <div className="dashboard-panel">
            <div className="panel-header" style={{ marginBottom: '8px' }}>
              <div>
                <h3 className="panel-title" style={{ marginBottom: '2px' }}>{comboChartData.title}</h3>
                <span style={{ fontSize: '12px', color: 'var(--color-text-light)' }}>
                  {comboChartData.subtitle}
                </span>
              </div>
              <span className="panel-badge">
                Hoạt động: {comboChartData.activeDaysCount}/{comboChartData.totalSlots} {rangeType === 'today' ? 'khung giờ' : 'ngày'}
              </span>
            </div>

            <div className="chart-container weekly-chart-container">
              <svg
                viewBox="0 0 680 260"
                className="combo-svg"
                onMouseLeave={() => setHoveredSlotIndex(null)}
              >
                <defs>
                  {/* Gradient đổ bóng nhẹ dưới đường Line Hoàn thành */}
                  <linearGradient id="completedAreaGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="#10b981" stopOpacity="0.28" />
                    <stop offset="100%" stopColor="#10b981" stopOpacity="0.0" />
                  </linearGradient>
                </defs>

                {/* Đường lưới ngang & mốc giá trị trục Y */}
                {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => {
                  const y = comboChartData.paddingTop + ratio * comboChartData.graphH;
                  const labelVal = Math.round(comboChartData.yMax * (1 - ratio));
                  return (
                    <g key={index}>
                      <line
                        x1={comboChartData.paddingLeft}
                        y1={y}
                        x2={comboChartData.paddingLeft + comboChartData.graphW}
                        y2={y}
                        className="grid-line"
                      />
                      <text x={comboChartData.paddingLeft - 8} y={y + 4} className="y-label">
                        {labelVal}
                      </text>
                    </g>
                  );
                })}

                {/* Vùng diện tích mờ dưới đường Hoàn thành */}
                {comboChartData.areaPath && (
                  <path d={comboChartData.areaPath} className="chart-line-area" />
                )}

                {/* Cột dữ liệu (Bars) & Dấu hiệu ngày 0 phát sinh */}
                {comboChartData.slots.map((slot, index) => {
                  const isHovered = hoveredSlotIndex === index;

                  return (
                    <g key={index}>
                      {/* Vệt sáng đổi màu cột khi hover */}
                      {isHovered && (
                        <>
                          <rect
                            x={slot.slotX + 1}
                            y={comboChartData.paddingTop}
                            width={slot.slotW - 2}
                            height={comboChartData.graphH}
                            fill="rgba(37, 67, 122, 0.05)"
                            rx="4"
                            className="slot-highlight-band"
                          />
                          <line
                            x1={slot.cx}
                            y1={comboChartData.paddingTop}
                            x2={slot.cx}
                            y2={comboChartData.baseY}
                            className="vertical-guide-line"
                          />
                        </>
                      )}

                      {/* Xử lý ngày không có phát sinh dữ liệu trực quan */}
                      {slot.isZero ? (
                        <g>
                          {/* Đường gạch ngang tối giản ngay tại vạch 0 */}
                          <line
                            x1={slot.cx - Math.min(10, Math.floor(slot.slotW * 0.35))}
                            y1={comboChartData.baseY}
                            x2={slot.cx + Math.min(10, Math.floor(slot.slotW * 0.35))}
                            y2={comboChartData.baseY}
                            className="zero-marker-line"
                          />
                        </g>
                      ) : (
                        <g>
                          {/* Cột 1: Chờ xử lý (Amber) */}
                          {slot.pending > 0 && (
                            <rect
                              x={slot.bar1X}
                              y={comboChartData.baseY - slot.hPending}
                              width={slot.barW}
                              height={Math.max(2, slot.hPending)}
                              rx="3"
                              className="bar-pending"
                              opacity={isHovered ? 1 : 0.9}
                            />
                          )}

                          {/* Cột 2: Đang sửa (Blue) */}
                          {slot.inProgress > 0 && (
                            <rect
                              x={slot.bar2X}
                              y={comboChartData.baseY - slot.hProgress}
                              width={slot.barW}
                              height={Math.max(2, slot.hProgress)}
                              rx="3"
                              className="bar-progress"
                              opacity={isHovered ? 1 : 0.9}
                            />
                          )}
                        </g>
                      )}

                      {/* Nhãn trục X */}
                      {slot.showXLabel && (
                        <text
                          x={slot.cx}
                          y={comboChartData.baseY + 18}
                          textAnchor="middle"
                          className={`x-label ${slot.isZero ? 'zero-label' : 'active-label'}`}
                        >
                          {slot.label}
                        </text>
                      )}
                    </g>
                  );
                })}

                {/* Đường Line: Hoàn thành */}
                {comboChartData.linePath && (
                  <path d={comboChartData.linePath} className="chart-line-completed" />
                )}

                {/* Các điểm node tròn trên đường Line */}
                {comboChartData.slots.map((slot, index) => {
                  const isHovered = hoveredSlotIndex === index;
                  if (slot.completed > 0) {
                    return (
                      <circle
                        key={index}
                        cx={slot.cx}
                        cy={slot.lineY}
                        r={isHovered ? 5.5 : 3.5}
                        fill="#ffffff"
                        stroke="#10b981"
                        strokeWidth={isHovered ? 3 : 2}
                        className="chart-node-circle"
                      />
                    );
                  }
                  // Điểm 0 công việc hoàn thành
                  return (
                    <circle
                      key={index}
                      cx={slot.cx}
                      cy={comboChartData.baseY}
                      r={isHovered ? 3.5 : 2}
                      fill="var(--color-card, #ffffff)"
                      stroke={slot.isZero ? '#cbd5e1' : '#94a3b8'}
                      strokeWidth="1.5"
                      className="zero-node-dot"
                    />
                  );
                })}

                {/* Vùng cảm ứng chuột trong suốt cho từng cột */}
                {comboChartData.slots.map((slot, index) => (
                  <rect
                    key={`hit-${index}`}
                    x={slot.slotX}
                    y={comboChartData.paddingTop - 10}
                    width={slot.slotW}
                    height={comboChartData.graphH + 35}
                    fill="transparent"
                    style={{ cursor: 'pointer' }}
                    onMouseEnter={() => setHoveredSlotIndex(index)}
                    onTouchStart={() => setHoveredSlotIndex(index)}
                  />
                ))}
              </svg>

              {/* Tooltip nổi chi tiết khi Hover */}
              {hoveredItem && (
                <div
                  className="chart-tooltip"
                  style={{
                    left: `${(hoveredItem.cx / 680) * 100}%`,
                    top: `${(Math.min(hoveredItem.lineY, 130) / 260) * 100}%`,
                    transform: hoveredSlotIndex !== null && hoveredSlotIndex > comboChartData.slots.length / 2
                      ? 'translate(-105%, -60%)'
                      : 'translate(12px, -60%)',
                  }}
                >
                  <div className="tooltip-header">
                    <div className="tooltip-title-wrap">
                      <Calendar size={13} className="tooltip-icon" />
                      <span>{hoveredItem.fullDate}</span>
                    </div>
                    {hoveredItem.total > 0 ? (
                      <span className="tooltip-badge-total">{hoveredItem.total} đơn</span>
                    ) : (
                      <span className="tooltip-badge-zero">0 đơn</span>
                    )}
                  </div>

                  {hoveredItem.isZero ? (
                    <div className="tooltip-empty-hint">
                      <Inbox size={14} className="empty-icon" />
                      <span>Ngày không có phát sinh đơn sửa chữa mới</span>
                    </div>
                  ) : (
                    <div className="tooltip-body">
                      <div className="tooltip-row">
                        <div className="tooltip-row-left">
                          <span className="tooltip-dot bg-amber" />
                          <span className="tooltip-lbl">Chờ xử lý:</span>
                        </div>
                        <strong className="tooltip-val">{hoveredItem.pending}</strong>
                      </div>
                      <div className="tooltip-row">
                        <div className="tooltip-row-left">
                          <span className="tooltip-dot bg-blue" />
                          <span className="tooltip-lbl">Đang sửa:</span>
                        </div>
                        <strong className="tooltip-val">{hoveredItem.inProgress}</strong>
                      </div>
                      <div className="tooltip-row">
                        <div className="tooltip-row-left">
                          <span className="tooltip-dot bg-green" />
                          <span className="tooltip-lbl">Hoàn thành:</span>
                        </div>
                        <strong className="tooltip-val">{hoveredItem.completed}</strong>
                      </div>
                      <div className="tooltip-footer">
                        <span>Tỷ lệ hoàn thành:</span>
                        <strong className="text-green">
                          {hoveredItem.total > 0
                            ? `${Math.round((hoveredItem.completed / hoveredItem.total) * 100)}%`
                            : '0%'}
                        </strong>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Chú giải biểu đồ (Legend) */}
            <div className="chart-legend">
              <div className="legend-items-group">
                <span className="legend-item">
                  <span className="legend-bar bg-amber" />
                  <span>Chờ xử lý (Cột)</span>
                </span>
                <span className="legend-item">
                  <span className="legend-bar bg-blue" />
                  <span>Đang sửa (Cột)</span>
                </span>
                <span className="legend-item">
                  <span className="legend-line-sample">
                    <span className="line-line" />
                    <span className="line-node" />
                  </span>
                  <span>Hoàn thành (Đường)</span>
                </span>
              </div>
              <span className="legend-activity-tag">
                {rangeType === 'today' ? 'Phân bố theo ca làm việc' : 'Dữ liệu cập nhật theo bộ lọc'}
              </span>
            </div>
          </div>

          {/* Status Ratio Pie/Donut Chart */}
          <div className="dashboard-panel">
            <h3 className="panel-title">Tỷ lệ trạng thái đơn</h3>
            <div className="status-ratio-wrapper">
              <div className="pie-chart-container">
                {pieChartData.total === 0 ? (
                  <svg width="140" height="140" viewBox="0 0 120 120">
                    <circle cx="60" cy="60" r={donutR} stroke="#e2e8f0" strokeWidth="15" fill="transparent" />
                    <text x="60" y="65" textAnchor="middle" fill="#94a3b8" fontSize="12" fontWeight="bold">0%</text>
                  </svg>
                ) : (
                  <svg width="140" height="140" viewBox="0 0 120 120">
                    <g transform="rotate(-90 60 60)">
                      {(() => {
                        let currentOffset = 0;
                        return slices.map((slice, index) => {
                          const percent = slice.val / totalPie;
                          const strokeLength = percent * donutCircumference;
                          const strokeOffset = currentOffset;
                          currentOffset -= strokeLength;
                          return (
                            <circle
                              key={index}
                              cx="60"
                              cy="60"
                              r={donutR}
                              stroke={slice.color}
                              strokeWidth="15"
                              fill="transparent"
                              strokeDasharray={`${strokeLength} ${donutCircumference}`}
                              strokeDashoffset={strokeOffset}
                              className="donut-slice"
                            />
                          );
                        });
                      })()}
                    </g>
                    <circle cx="60" cy="60" r={donutR - 8} fill="var(--color-card, #ffffff)" />
                    <text x="60" y="65" textAnchor="middle" fill="var(--color-text-dark, #0f172a)" fontSize="14" fontWeight="800">
                      {pieChartData.total} đơn
                    </text>
                  </svg>
                )}
              </div>
              <div className="pie-stats-list">
                {[
                  { label: 'Chờ xử lý', count: pieChartData.pending, color: '#f59e0b' },
                  { label: 'Đang sửa', count: pieChartData.inProgress, color: '#3b82f6' },
                  { label: 'Hoàn thành', count: pieChartData.completed, color: '#10b981' },
                  { label: 'Đã giao', count: pieChartData.delivered, color: '#64748b' }
                ].map((item, index) => {
                  const pct = pieChartData.total > 0 ? Math.round((item.count / pieChartData.total) * 100) : 0;
                  return (
                    <div key={index} className="pie-stat-row">
                      <span className="bullet" style={{ backgroundColor: item.color }} />
                      <span className="label">{item.label}</span>
                      <strong className="value">{item.count}</strong>
                      <span className="percent">{pct}%</span>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        </div>

        {/* Right Side: Data Lists */}
        <div className="dashboard-lists-column">
          {/* Attendance Panel: Admin sees company-wide today check-ins; Non-admin sees personal attendance days */}
          {isAdmin ? (
            <div className="dashboard-panel flex-column">
              <div className="panel-header">
                <h3 className="panel-title">Chấm công hôm nay</h3>
                <span className="panel-badge">{stats.checkedInEmployees} Nhân viên</span>
              </div>
              <div className="list-container attendance-list">
                {attendance.length === 0 ? (
                  <div className="empty-state">Không có nhân viên nào check-in hôm nay</div>
                ) : (
                  attendance.map((rec, index) => {
                    const empName = rec.records && rec.records.length > 0
                      ? rec.records[0].employeeName
                      : 'Nhân viên';
                    const checkInTime = rec.checkIn ? new Date(rec.checkIn).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', hour12: false }) : '--:--';
                    return (
                      <div key={index} className="list-item">
                        <div className="item-avatar">
                          {getAvatarLetters(empName)}
                        </div>
                        <div className="item-details">
                          <span className="item-primary-name">{empName}</span>
                          <span className="item-secondary-info">Check-in: {checkInTime}</span>
                        </div>
                        <div className="item-action-status">
                          {getAttendanceStatusBadge(rec)}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          ) : (
            <div className="dashboard-panel flex-column personal-attendance-panel">
              <div className="panel-header">
                <div className="panel-title-group">
                  <h3 className="panel-title">Ngày chấm công của bạn</h3>
                  <span className="panel-badge">
                    {personalSummary ? `${personalSummary.workDays} công` : 'Cá nhân'}
                  </span>
                </div>
                {onViewPersonalAttendance && currentUser && (
                  <button
                    className="btn-link"
                    onClick={() => onViewPersonalAttendance({
                      id: currentUser.id || '',
                      name: currentUser.fullName || currentUser.username,
                      dept: currentUser.department || 'Nhân viên'
                    })}
                  >
                    <span>Xem chi tiết tháng</span>
                    <ArrowRight size={14} />
                  </button>
                )}
              </div>

              {/* Thẻ chấm công hôm nay */}
              <div className="personal-today-card">
                <div className="ptc-header">
                  <span className="ptc-date">Hôm nay ({new Date().toLocaleDateString('vi-VN')})</span>
                  {myToday?.checkIn ? (
                    myToday.isLate && myToday.isEarlyLeave ? (
                      <span className="att-badge warning">Muộn & Về sớm</span>
                    ) : myToday.isLate ? (
                      <span className="att-badge warning">Đi muộn</span>
                    ) : myToday.isEarlyLeave ? (
                      <span className="att-badge warning">Về sớm</span>
                    ) : myToday.checkOut ? (
                      <span className="att-badge success">Đủ công</span>
                    ) : (
                      <span className="att-badge success">Đã vào ca</span>
                    )
                  ) : (
                    <span className="att-badge danger">Chưa chấm công</span>
                  )}
                </div>
                <div className="ptc-times-row">
                  <div className="ptc-time-box">
                    <LogIn size={15} className="ptc-icon in" />
                    <div className="ptc-time-text">
                      <span className="ptc-time-label">Giờ vào</span>
                      <strong className="ptc-time-value">{myTodayTimes.checkInStr || '--:--'}</strong>
                    </div>
                  </div>
                  <div className="ptc-divider" />
                  <div className="ptc-time-box">
                    <LogOut size={15} className="ptc-icon out" />
                    <div className="ptc-time-text">
                      <span className="ptc-time-label">Giờ ra</span>
                      <strong className="ptc-time-value">{myTodayTimes.checkOutStr || '--:--'}</strong>
                    </div>
                  </div>
                </div>
              </div>

              {/* Tóm tắt nhanh thống kê theo bộ lọc */}
              {filteredPersonalSummary && (
                <div className="personal-summary-chips">
                  <div className="mini-chip">
                    <span className="mc-label">Tổng công</span>
                    <strong className="mc-val text-teal">{filteredPersonalSummary.workDays}</strong>
                  </div>
                  <div className="mini-chip">
                    <span className="mc-label">Tổng giờ</span>
                    <strong className="mc-val text-blue">{filteredPersonalSummary.totalHours}h</strong>
                  </div>
                  <div className="mini-chip">
                    <span className="mc-label">Đi muộn</span>
                    <strong className={`mc-val ${filteredPersonalSummary.lateCount > 0 ? 'text-amber' : 'text-green'}`}>
                      {filteredPersonalSummary.lateCount}
                    </strong>
                  </div>
                  <div className="mini-chip">
                    <span className="mc-label">Tăng ca</span>
                    <strong className="mc-val text-purple">{filteredPersonalSummary.overtimeHours}h</strong>
                  </div>
                </div>
              )}

              {/* Tiêu đề danh sách ngày */}
              <div className="personal-days-title">
                <span>Lịch sử chấm công ({filterSummaryText})</span>
                <span className="pdt-sub">Bấm vào ngày để xem chi tiết</span>
              </div>

              {/* Danh sách các ngày chấm công trong khoảng lọc */}
              <div className="list-container personal-attendance-list">
                {filteredPersonalDays.length === 0 ? (
                  <div className="empty-state">Chưa có bản ghi chấm công nào trong khoảng thời gian này</div>
                ) : (
                  [...filteredPersonalDays]
                    .filter(d => d.status !== 'FUTURE')
                    .sort((a, b) => b.date.localeCompare(a.date))
                    .map((day, index) => {
                    const inOut = getDayInOut(day);
                    return (
                      <div
                        key={index}
                        className={`list-item clickable personal-day-row ${day.status.toLowerCase()}`}
                        onClick={() => onViewPersonalAttendance && currentUser && onViewPersonalAttendance({
                          id: currentUser.id || '',
                          name: currentUser.fullName || currentUser.username,
                          dept: currentUser.department || 'Nhân viên'
                        })}
                        title="Bấm để xem chi tiết lịch sử"
                      >
                        <div className="day-date-badge">
                          <span className="dd-dow">{day.dayOfWeek}</span>
                          <span className="dd-day">{day.date.split('-')[2]}</span>
                        </div>
                        <div className="item-details">
                          <div className="day-primary-row">
                            <span className="item-primary-name">
                              {formatDayDisplay(day.date, day.dayOfWeek)}
                            </span>
                            {inOut.duration && (
                              <span className="day-duration-tag">{inOut.duration}</span>
                            )}
                          </div>
                          <span className="item-secondary-info">
                            {inOut.checkIn || inOut.checkOut
                              ? `Vào: ${inOut.checkIn || '--:--'} · Ra: ${inOut.checkOut || '--:--'}`
                              : 'Không có quẹt thẻ'}
                          </span>
                        </div>
                        <div className="item-action-status">
                          {getPersonalDayBadge(day.status)}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          )}

          {/* Recent Orders Panel */}
          <div className="dashboard-panel flex-column">
            <div className="panel-header">
              <h3 className="panel-title">Đơn hàng gần đây</h3>
              <button className="btn-link" onClick={() => setActiveTab('orders')}>
                <span>Xem tất cả</span>
                <ArrowRight size={14} />
              </button>
            </div>
            <div className="list-container orders-list">
              {filteredOrders.length === 0 ? (
                <div className="empty-state">Không có đơn hàng nào trong khoảng thời gian này</div>
              ) : (
                filteredOrders.slice(0, 10).map((order) => {
                  const statusInfo = getOrderStatusLabel(order.status);
                  return (
                    <div key={order.id} className="list-item clickable" onClick={() => setActiveTab('orders')}>
                      <div className="order-icon-badge">
                        <Wrench size={16} />
                      </div>
                      <div className="item-details">
                        <span className="item-primary-name">{order.deviceName}</span>
                        <span className="item-secondary-info">{order.orderCode} · {order.customerName}</span>
                      </div>
                      <div className="item-action-status">
                        <span className={`status-pill-small ${statusInfo.className}`}>
                          {statusInfo.label}
                        </span>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

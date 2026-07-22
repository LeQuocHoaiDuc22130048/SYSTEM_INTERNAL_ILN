import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Wrench, Activity, CheckCircle2, Cpu, Users, UserPlus,
  AlertTriangle, RefreshCw, ArrowRight, UserCheck
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { getAuthHeaders } from '../utils/auth';
import { getAvatarLetters } from '../utils/employee';
import './DashboardTab.css';

interface DashboardTabProps {
  setActiveTab: (tab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts') => void;
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
}

interface OrderRecord {
  id: string;
  orderCode: string;
  deviceName: string;
  customerName: string;
  status: string;
  assignedTo?: { id: string; fullName: string } | null;
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

export const DashboardTab: React.FC<DashboardTabProps> = ({
  setActiveTab,
  showToast,
  currentUser
}) => {
  const [orders, setOrders] = useState<OrderRecord[]>([]);
  const [boards, setBoards] = useState<BoardRecord[]>([]);
  const [employees, setEmployees] = useState<any[]>([]);
  const [attendance, setAttendance] = useState<AttendanceReportRecord[]>([]);
  const [pendingUsers, setPendingUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchDashboardData = useCallback(async () => {
    try {
      const headers = getAuthHeaders();
      const today = new Date();
      const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

      // 1. Fetch Orders
      const ordersRes = await fetch('/api/v1/repair-orders?size=200', { headers });
      const ordersData = ordersRes.ok ? await ordersRes.json() : null;
      const fetchedOrders: OrderRecord[] = ordersData?.data?.content || ordersData?.data || [];

      // 2. Fetch Boards
      const boardsRes = await fetch('/api/v1/boards?size=200', { headers });
      const boardsData = boardsRes.ok ? await boardsRes.json() : null;
      const fetchedBoards: BoardRecord[] = boardsData?.data?.content || boardsData?.data || [];

      // 3. Fetch Employees (Manager+)
      let fetchedEmployees: any[] = [];
      const employeesRes = await fetch('/api/v1/employees?size=200', { headers });
      if (employeesRes.ok) {
        const empData = await employeesRes.json();
        fetchedEmployees = empData?.data?.employees || empData?.data?.content || empData?.data || [];
      }

      // 4. Fetch Today Attendance (Manager+)
      let fetchedAttendance: AttendanceReportRecord[] = [];
      const attendanceRes = await fetch(`/api/v1/attendance/report?date=${todayStr}`, { headers });
      if (attendanceRes.ok) {
        const attData = await attendanceRes.json();
        fetchedAttendance = attData?.data || [];
      }

      // 5. Fetch Pending Users (Manager+)
      let fetchedPending: any[] = [];
      const pendingRes = await fetch('/api/v1/auth/pending?size=200', { headers });
      if (pendingRes.ok) {
        const pendData = await pendingRes.json();
        fetchedPending = pendData?.data?.content || pendData?.data || [];
      }

      setOrders(fetchedOrders);
      setBoards(fetchedBoards);
      setEmployees(fetchedEmployees);
      setAttendance(fetchedAttendance);
      setPendingUsers(fetchedPending);
    } catch (e: any) {
      console.error('Error fetching dashboard stats:', e);
      showToast('Có lỗi xảy ra khi tải số liệu thống kê.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [showToast]);

  useEffect(() => {
    fetchDashboardData();
  }, [fetchDashboardData]);

  const handleRefresh = () => {
    setRefreshing(true);
    fetchDashboardData();
    showToast('Đang làm mới dữ liệu...');
  };

  // ── Calculated Stats ──────────────────────────────────────────────────────
  const stats = useMemo(() => {
    // 1. Total Orders
    const totalOrders = orders.length;

    // 2. In progress orders
    const inProgressOrders = orders.filter(o =>
      ['IN_PROGRESS', 'CHECKING', 'CHECKED', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())
    ).length;

    // 3. Completed orders
    const completedOrders = orders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;

    // 4. Available boards ratio
    const availableBoards = boards.filter(b => b.status.toUpperCase() === 'AVAILABLE').length;
    const totalBoards = boards.length;

    // 5. Active attendance record ratio
    const checkedInEmployees = attendance.length;
    const totalEmployees = employees.length || checkedInEmployees || 1; // Fallback to avoid division by zero

    // 6. Unassigned orders
    const unassignedOrders = orders.filter(o => !o.assignedTo).length;

    // 7. Maintenance boards
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
  }, [orders, boards, employees, attendance, pendingUsers]);

  // ── Weekly Chart Calculation ──────────────────────────────────────────────
  const weeklyChartData = useMemo(() => {
    const dates = Array.from({ length: 7 }, (_, i) => {
      const d = new Date();
      d.setDate(d.getDate() - (6 - i));
      return d;
    });

    const statsList = dates.map(date => {
      const dateString = date.toLocaleDateString('en-CA'); // YYYY-MM-DD local format
      const label = `${date.getDate()}/${date.getMonth() + 1}`;

      const dayOrders = orders.filter(o => {
        if (!o.createdAt) return false;
        const createdDate = new Date(o.createdAt).toLocaleDateString('en-CA');
        return createdDate === dateString;
      });

      const pending = dayOrders.filter(o => o.status.toUpperCase() === 'PENDING').length;
      const inProgress = dayOrders.filter(o =>
        ['IN_PROGRESS', 'CHECKING', 'CHECKED', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())
      ).length;
      const completed = dayOrders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;

      return {
        label,
        pending,
        inProgress,
        completed
      };
    });

    // Find max value to scale Y axis in SVG
    const maxVal = Math.max(
      10, // Minimum upper bound of 10
      ...statsList.flatMap(s => [s.pending, s.inProgress, s.completed])
    );
    // Round to next even number
    const yMax = maxVal % 2 === 0 ? maxVal : maxVal + 1;

    return {
      stats: statsList,
      yMax
    };
  }, [orders]);

  // ── Pie/Donut Chart Calculation ───────────────────────────────────────────
  const pieChartData = useMemo(() => {
    const pending = orders.filter(o => o.status.toUpperCase() === 'PENDING').length;
    const inProgress = orders.filter(o =>
      ['IN_PROGRESS', 'CHECKING', 'CHECKED', 'WAITING_FOR_CHECK'].includes(o.status.toUpperCase())
    ).length;
    const completed = orders.filter(o => o.status.toUpperCase() === 'COMPLETED').length;
    const delivered = orders.filter(o => o.status.toUpperCase() === 'DELIVERED').length;
    const total = pending + inProgress + completed + delivered;

    return {
      pending,
      inProgress,
      completed,
      delivered,
      total
    };
  }, [orders]);

  // Helper to format Vietnamese date
  const vietnameseDate = () => {
    const date = new Date();
    const weekdays = [
      'Chủ Nhật',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
    ];
    return `${weekdays[date.getDay()]}, ${date.getDate()} tháng ${date.getMonth() + 1}, ${date.getFullYear()}`;
  };

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
      {/* Header section */}
      <div className="dashboard-header-panel">
        <div className="welcome-info">
          <span className="current-date">{vietnameseDate()}</span>
          <h2>Xin chào, {currentUser?.fullName || currentUser?.username || 'Người dùng'}</h2>
        </div>
        <button className="btn-refresh-dashboard" onClick={handleRefresh} disabled={refreshing}>
          <RefreshCw size={16} className={refreshing ? 'spin' : ''} />
          <span>Làm mới dữ liệu</span>
        </button>
      </div>

      {/* Grid containing 8 stats card */}
      <div className="dashboard-stats-grid">
        {/* Card 1: Tổng đơn */}
        <div className="stat-card border-blue">
          <div className="stat-info">
            <span className="stat-label">Tổng đơn</span>
            <span className="stat-value">{stats.totalOrders}</span>
            <span className="stat-sub">Tổng số đơn sửa chữa</span>
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

        {/* Card 5: Nhân viên có mặt */}
        <div className="stat-card border-teal">
          <div className="stat-info">
            <span className="stat-label">Nhân viên có mặt</span>
            <span className="stat-value">{stats.checkedInEmployees}/{stats.totalEmployees}</span>
            <span className="stat-sub">Đã check-in hôm nay</span>
          </div>
          <div className="stat-icon-wrapper bg-teal">
            <Users size={20} className="icon-teal" />
          </div>
        </div>

        {/* Card 6: Đơn chờ phân công */}
        <div className="stat-card border-pink">
          <div className="stat-info">
            <span className="stat-label">Chờ phân công</span>
            <span className="stat-value">{stats.unassignedOrders}</span>
            <span className="stat-sub">Đơn chưa gán kỹ thuật viên</span>
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

        {/* Card 8: Tài khoản chờ duyệt */}
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
      </div>

      {/* Main content split */}
      <div className="dashboard-content-split">
        {/* Left Side: Charts */}
        <div className="dashboard-charts-column">
          {/* Weekly Orders Bar Chart */}
          <div className="dashboard-panel">
            <h3 className="panel-title">Thống kê đơn theo tuần</h3>
            <div className="chart-container weekly-chart-container">
              <svg viewBox="0 0 600 240" className="weekly-svg">
                {/* Horizontal grid lines */}
                {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => {
                  const y = 20 + ratio * 160;
                  const labelVal = Math.round(weeklyChartData.yMax * (1 - ratio));
                  return (
                    <g key={index}>
                      <line x1="45" y1={y} x2="570" y2={y} className="grid-line" />
                      <text x="35" y={y + 4} className="y-label">{labelVal}</text>
                    </g>
                  );
                })}

                {/* Vertical bars */}
                {weeklyChartData.stats.map((dayData, index) => {
                  const slotWidth = 525 / 7;
                  const groupWidth = 42; // 3 bars * 12 + 2 spaces * 3
                  const startX = 45 + index * slotWidth + (slotWidth - groupWidth) / 2;

                  // Bar heights
                  const hPending = (dayData.pending / weeklyChartData.yMax) * 160;
                  const hProgress = (dayData.inProgress / weeklyChartData.yMax) * 160;
                  const hCompleted = (dayData.completed / weeklyChartData.yMax) * 160;

                  return (
                    <g key={index}>
                      {/* Pending bar (amber) */}
                      <rect
                        x={startX}
                        y={180 - hPending}
                        width="11"
                        height={Math.max(2, hPending)}
                        rx="2"
                        className="bar-pending"
                      />
                      {/* In progress bar (blue) */}
                      <rect
                        x={startX + 14}
                        y={180 - hProgress}
                        width="11"
                        height={Math.max(2, hProgress)}
                        rx="2"
                        className="bar-progress"
                      />
                      {/* Completed bar (green) */}
                      <rect
                        x={startX + 28}
                        y={180 - hCompleted}
                        width="11"
                        height={Math.max(2, hCompleted)}
                        rx="2"
                        className="bar-completed"
                      />
                      {/* X-axis Label */}
                      <text
                        x={startX + 21}
                        y="202"
                        textAnchor="middle"
                        className="x-label"
                      >
                        {dayData.label}
                      </text>
                    </g>
                  );
                })}
              </svg>
            </div>
            {/* Chart Legend */}
            <div className="chart-legend">
              <span className="legend-item"><span className="legend-dot bg-amber" />Chờ xử lý</span>
              <span className="legend-item"><span className="legend-dot bg-blue" />Đang sửa</span>
              <span className="legend-item"><span className="legend-dot bg-green" />Hoàn thành</span>
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
          {/* Today Attendance Panel */}
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
              {orders.length === 0 ? (
                <div className="empty-state">Không có đơn hàng nào</div>
              ) : (
                orders.slice(0, 10).map((order) => {
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

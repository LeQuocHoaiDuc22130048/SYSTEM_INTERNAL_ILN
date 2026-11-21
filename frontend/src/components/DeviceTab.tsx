import { AttendanceTabletPanel } from './AttendanceTabletPanel';
import { usePermissionCheck } from '../utils/permissionContext';
import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { hasPermission } from '../utils/permissions';
import {
  Search,
  Plus,
  Edit,
  Trash2,
  RefreshCw,
  Cpu,
  Fingerprint,
  Barcode,
  Smartphone,
  Activity,
  Wifi,
  WifiOff,
  Clock,
  X,
  ShieldCheck,
  UserCheck,
  User,
  Globe,
  MoreVertical,
  Eye,
  Power,
  LayoutGrid,
  List,
  AlertTriangle,
  Server,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import {
  computeDeviceStats,
  detectDevicePlatform,
  filterDevices,
  getDeviceConnectionCategory,
  type ConnectionFilter,
  type DeviceInfo,
  type DeviceStatusFilter,
} from './deviceUtils';
import './DeviceTab.css';

export type { DeviceInfo };

interface DeviceTabProps {
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
}

const AndroidIcon: React.FC<{ size?: number; className?: string }> = ({ size = 14, className = '' }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="currentColor"
    className={className}
    aria-hidden="true"
    style={{ display: 'inline-block', verticalAlign: 'middle', flexShrink: 0 }}
  >
    <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4483.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4116 13.8533 8.081 12 8.081c-1.8533 0-3.5902.3306-5.1368.8682L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396" />
  </svg>
);

const AppleIcon: React.FC<{ size?: number; className?: string }> = ({ size = 14, className = '' }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="currentColor"
    className={className}
    aria-hidden="true"
    style={{ display: 'inline-block', verticalAlign: 'middle', flexShrink: 0 }}
  >
    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.8 1.11-1.92.99-3.04-1 .04-2.15.67-2.82 1.45-.58.67-1.1 1.76-.96 2.85 1.11.09 2.19-.58 2.79-1.26z" />
  </svg>
);

const PlatformBadge: React.FC<{ device: DeviceInfo }> = ({ device }) => {
  const platform = detectDevicePlatform(device);
  if (platform === 'ANDROID') {
    return (
      <span className="device-platform-badge android" title="Thiết bị Android (Mobile/App)">
        <AndroidIcon size={13} />
        <span>Android</span>
      </span>
    );
  }
  if (platform === 'IOS') {
    return (
      <span className="device-platform-badge ios" title="Thiết bị iOS (Mobile/App)">
        <AppleIcon size={13} />
        <span>iOS</span>
      </span>
    );
  }
  if (platform === 'WEB') {
    return (
      <span className="device-platform-badge web" title="Trình duyệt Web">
        <Globe size={13} aria-hidden="true" />
        <span>Web</span>
      </span>
    );
  }
  return (
    <span className="device-platform-badge mobile" title="Phiên đăng nhập Mobile / App">
      <Smartphone size={13} aria-hidden="true" />
      <span>App Mobile</span>
    </span>
  );
};

export const DeviceTab: React.FC<DeviceTabProps> = ({ showToast, currentUser }) => {
  const canAction = usePermissionCheck();
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [selectedType, setSelectedType] = useState<string>('ALL');
  const [connectionFilter, setConnectionFilter] = useState<ConnectionFilter>('ALL');
  const [statusFilter, setStatusFilter] = useState<DeviceStatusFilter>('ALL');
  const [sortByLatency, setSortByLatency] = useState<boolean>(false);
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid');

  // Modals & menus state
  const [isFormOpen, setIsFormOpen] = useState<boolean>(false);
  const [editingDevice, setEditingDevice] = useState<DeviceInfo | null>(null);
  const [formData, setFormData] = useState({
    deviceId: '',
    name: '',
    type: 'ATTENDANCE' as DeviceInfo['type'],
    ipAddress: '',
    version: '1.0.0',
  });

  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [confirmToggleDevice, setConfirmToggleDevice] = useState<DeviceInfo | null>(null);
  const [detailDevice, setDetailDevice] = useState<DeviceInfo | null>(null);
  const [openMenuId, setOpenMenuId] = useState<string | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [pingingId, setPingingId] = useState<string | null>(null);
  const [isPingingAll, setIsPingingAll] = useState<boolean>(false);

  const isManagerOrAbove = useMemo(() => {
    return hasPermission(currentUser ?? null, 'DEVICE_MANAGE');
  }, [currentUser]);

  // Fetch devices list
  const fetchDevices = useCallback(
    async (silent = false) => {
      if (!silent) setLoading(true);
      try {
        const response = await fetch('/api/v1/devices', {
          headers: getAuthHeaders(),
        });
        if (response.ok) {
          const result = await response.json();
          if (result?.data) {
            setDevices(result.data);
          }
        } else {
          showToast('Không thể tải danh sách thiết bị từ server.');
        }
      } catch (error) {
        console.error('Lỗi khi fetch devices:', error);
        showToast('Lỗi kết nối tới máy chủ khi tải thiết bị.');
      } finally {
        if (!silent) setLoading(false);
      }
    },
    [showToast]
  );

  useEffect(() => {
    fetchDevices();
    const interval = setInterval(() => {
      fetchDevices(true);
    }, 10000);
    return () => clearInterval(interval);
  }, [fetchDevices]);

  // Close overflow menu on outside click or Escape key
  useEffect(() => {
    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as HTMLElement | null;
      if (!target?.closest('.device-more-menu-wrap')) {
        setOpenMenuId(null);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpenMenuId(null);
        setConfirmToggleDevice(null);
        setConfirmDeleteId(null);
        setDetailDevice(null);
        setIsFormOpen(false);
      }
    };
    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

  const stats = useMemo(() => computeDeviceStats(devices), [devices]);

  const filteredDevices = useMemo(
    () =>
      filterDevices(devices, {
        searchTerm,
        selectedType,
        connectionFilter,
        statusFilter,
        sortByLatency,
      }),
    [devices, searchTerm, selectedType, connectionFilter, statusFilter, sortByLatency]
  );

  // KPI Card quick filter handlers
  const handleSelectTotalKpi = () => {
    setStatusFilter('ALL');
    setSortByLatency(false);
  };

  const handleToggleStatusKpi = (target: 'ONLINE' | 'OFFLINE') => {
    setSortByLatency(false);
    setStatusFilter((prev) => (prev === target ? 'ALL' : target));
  };

  const handleToggleLatencyKpi = () => {
    setSortByLatency((prev) => {
      const next = !prev;
      setStatusFilter(next ? 'ONLINE' : 'ALL');
      return next;
    });
  };

  // Actions handlers
  const handlePing = async (id: string, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setOpenMenuId(null);
    setPingingId(id);
    try {
      const response = await fetch(`/api/v1/devices/${id}/ping`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setDevices((prev) => prev.map((d) => (d.id === id ? result.data : d)));
          setDetailDevice((prev) => (prev?.id === id ? result.data : prev));
          if (result.data.status === 'ONLINE') {
            showToast(`Ping tới ${result.data.name} thành công! Phản hồi: ${result.data.pingMs}ms`);
          } else {
            showToast(`Thiết bị ${result.data.name} không phản hồi mạng (Offline)`);
          }
        }
      } else {
        showToast('Lỗi gửi lệnh ping tới thiết bị.');
      }
    } catch (error) {
      console.error('Error pinging device:', error);
      showToast('Không thể kết nối đến máy chủ.');
    } finally {
      setPingingId(null);
    }
  };

  const handlePingAll = async () => {
    setIsPingingAll(true);
    try {
      const response = await fetch('/api/v1/devices/ping-all', {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setDevices(result.data);
          const onlineCount = result.data.filter((d: DeviceInfo) => d.status === 'ONLINE').length;
          showToast(
            `Đã kiểm tra ${result.data.length} thiết bị: ${onlineCount} Online, ${result.data.length - onlineCount} Offline`
          );
        }
      } else {
        showToast('Lỗi gửi lệnh kiểm tra toàn bộ thiết bị.');
      }
    } catch (error) {
      console.error('Error pinging all devices:', error);
      showToast('Không thể kết nối máy chủ.');
    } finally {
      setIsPingingAll(false);
    }
  };

  const executeToggleStatus = async (id: string) => {
    setTogglingId(id);
    try {
      const response = await fetch(`/api/v1/devices/${id}/toggle`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setDevices((prev) => prev.map((d) => (d.id === id ? result.data : d)));
          setDetailDevice((prev) => (prev?.id === id ? result.data : prev));
          showToast(`Đã chuyển đổi trạng thái thiết bị sang ${result.data.status}`);
        }
      } else {
        showToast('Không thể thay đổi trạng thái thiết bị.');
      }
    } catch (error) {
      console.error('Error toggling status:', error);
      showToast('Lỗi kết nối mạng.');
    } finally {
      setTogglingId(null);
      setConfirmToggleDevice(null);
    }
  };

  const requestToggleStatus = (device: DeviceInfo, e?: React.SyntheticEvent) => {
    e?.stopPropagation();
    setOpenMenuId(null);
    if (togglingId === device.id) return;
    if (device.status === 'ONLINE') {
      setConfirmToggleDevice(device);
    } else {
      void executeToggleStatus(device.id);
    }
  };

  const handleOpenCreateModal = () => {
    setEditingDevice(null);
    setFormData({
      deviceId: '',
      name: '',
      type: 'ATTENDANCE',
      ipAddress: '',
      version: '1.0.0',
    });
    setIsFormOpen(true);
  };

  const handleOpenEditModal = (device: DeviceInfo, e?: React.MouseEvent) => {
    e?.stopPropagation();
    setOpenMenuId(null);
    setEditingDevice(device);
    setFormData({
      deviceId: device.deviceId,
      name: device.name,
      type: device.type,
      ipAddress: device.ipAddress,
      version: device.version,
    });
    setIsFormOpen(true);
  };

  const handleFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.deviceId.trim() || !formData.name.trim() || !formData.ipAddress.trim()) {
      showToast('Vui lòng điền đầy đủ các thông tin bắt buộc.');
      return;
    }

    try {
      const url = editingDevice ? `/api/v1/devices/${editingDevice.id}` : '/api/v1/devices';
      const method = editingDevice ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(formData),
      });

      if (response.ok) {
        const result = await response.json();
        if (result?.success) {
          showToast(editingDevice ? 'Cập nhật thiết bị thành công!' : 'Thêm thiết bị mới thành công!');
          setIsFormOpen(false);
          fetchDevices();
        } else {
          showToast(result?.message || 'Có lỗi xảy ra.');
        }
      } else {
        const errResult = await response.json().catch(() => null);
        showToast(errResult?.message || 'Gửi yêu cầu thất bại.');
      }
    } catch (error) {
      console.error('Error submitting form:', error);
      showToast('Lỗi kết nối máy chủ.');
    }
  };

  const handleDeleteDevice = async (id: string) => {
    try {
      const response = await fetch(`/api/v1/devices/${id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        showToast('Xóa thiết bị thành công.');
        setConfirmDeleteId(null);
        if (detailDevice?.id === id) setDetailDevice(null);
        fetchDevices();
      } else {
        showToast('Không thể xóa thiết bị.');
      }
    } catch (error) {
      console.error('Error deleting device:', error);
      showToast('Lỗi kết nối mạng.');
    }
  };

  const getDeviceIcon = (type: string) => {
    switch (type) {
      case 'ATTENDANCE':
        return <Fingerprint size={22} />;
      case 'WAREHOUSE':
        return <Barcode size={22} />;
      case 'TECHNICIAN':
        return <Smartphone size={22} />;
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return <ShieldCheck size={22} />;
      case 'MANAGER':
        return <UserCheck size={22} />;
      case 'EMPLOYEE':
      case 'RECEPTIONIST':
        return <User size={22} />;
      default:
        return <Cpu size={22} />;
    }
  };

  const getTypeName = (type: string) => {
    switch (type) {
      case 'ATTENDANCE':
        return 'Chấm công';
      case 'WAREHOUSE':
        return 'Kho bãi';
      case 'TECHNICIAN':
        return 'Kỹ thuật';
      case 'SUPER_ADMIN':
        return 'Super Admin';
      case 'ADMIN':
        return 'Quản trị viên';
      case 'MANAGER':
        return 'Quản lý';
      case 'EMPLOYEE':
        return 'Nhân viên';
      case 'RECEPTIONIST':
        return 'Lễ tân';
      default:
        return type;
    }
  };

  const formatActiveTime = (timeStr: string | null) => {
    if (!timeStr) return 'Chưa hoạt động';
    const activeDate = new Date(timeStr);
    const now = new Date();
    const diffMs = now.getTime() - activeDate.getTime();
    const diffSecs = Math.floor(diffMs / 1000);
    const diffMins = Math.floor(diffSecs / 60);

    if (diffSecs < 10) return 'Vừa mới đây';
    if (diffSecs < 60) return `${diffSecs} giây trước`;
    if (diffMins < 60) return `${diffMins} phút trước`;

    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} giờ trước`;

    return activeDate.toLocaleDateString('vi-VN', {
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
    });
  };

  const renderConnectionCell = (device: DeviceInfo) => {
    const category = getDeviceConnectionCategory(device);
    if (category === 'HARDWARE') {
      return <span className="detail-value ip">{device.ipAddress}</span>;
    }
    return <PlatformBadge device={device} />;
  };

  const renderDeviceControls = (device: DeviceInfo) => {
    const canToggleStatus = isManagerOrAbove && canAction('DEVICE_STATUS_UPDATE');
    const canPing = canAction('DEVICE_PING');
    const canEdit = isManagerOrAbove && canAction('DEVICE_UPDATE');
    const canDelete = isManagerOrAbove && canAction('DEVICE_DELETE');
    const isMenuOpen = openMenuId === device.id;
    const isOnline = device.status === 'ONLINE';

    return (
      <div className="device-controls-cluster">
        {canPing && (
          <button
            type="button"
            className="action-btn ping"
            onClick={(e) => void handlePing(device.id, e)}
            disabled={pingingId === device.id}
            title={pingingId === device.id ? 'Đang gửi ping...' : 'Ping kiểm tra kết nối'}
            aria-label={`Ping ${device.name}`}
          >
            <Wifi size={16} className={pingingId === device.id ? 'spin' : ''} aria-hidden="true" />
          </button>
        )}

        {canToggleStatus && (
          <button
            type="button"
            role="switch"
            aria-checked={isOnline}
            aria-label={isOnline ? `Tắt thiết bị ${device.name}` : `Bật thiết bị ${device.name}`}
            title={isOnline ? 'Đang bật — nhấn để tắt (có xác nhận)' : 'Đang tắt — nhấn để bật'}
            className={`device-switch ${isOnline ? 'is-on' : 'is-off'}`}
            disabled={togglingId === device.id}
            onClick={(e) => requestToggleStatus(device, e)}
          >
            <span className="device-switch-thumb" aria-hidden="true" />
          </button>
        )}

        <div className="device-more-menu-wrap">
          <button
            type="button"
            className={`action-btn more-btn ${isMenuOpen ? 'active' : ''}`}
            aria-haspopup="menu"
            aria-expanded={isMenuOpen}
            aria-label={`Thao tác khác cho ${device.name}`}
            title="Thao tác khác"
            onClick={(e) => {
              e.stopPropagation();
              setOpenMenuId((prev) => (prev === device.id ? null : device.id));
            }}
          >
            <MoreVertical size={16} aria-hidden="true" />
          </button>

          {isMenuOpen && (
            <div className="device-more-menu" role="menu" aria-label={`Menu thiết bị ${device.name}`}>
              <button
                type="button"
                role="menuitem"
                className="device-menu-item"
                onClick={(e) => {
                  e.stopPropagation();
                  setOpenMenuId(null);
                  setDetailDevice(device);
                }}
              >
                <Eye size={15} aria-hidden="true" />
                <span>Xem chi tiết</span>
              </button>

              {canPing && (
                <button
                  type="button"
                  role="menuitem"
                  className="device-menu-item"
                  disabled={pingingId === device.id}
                  onClick={(e) => void handlePing(device.id, e)}
                >
                  <Wifi size={15} aria-hidden="true" />
                  <span>Ping lại</span>
                </button>
              )}

              {canToggleStatus && (
                <button
                  type="button"
                  role="menuitem"
                  className={`device-menu-item ${isOnline ? 'danger' : ''}`}
                  onClick={(e) => requestToggleStatus(device, e)}
                >
                  <Power size={15} aria-hidden="true" />
                  <span>{isOnline ? 'Ngắt kết nối' : 'Kích hoạt kết nối'}</span>
                </button>
              )}

              {canEdit && (
                <button
                  type="button"
                  role="menuitem"
                  className="device-menu-item"
                  onClick={(e) => handleOpenEditModal(device, e)}
                >
                  <Edit size={15} aria-hidden="true" />
                  <span>Chỉnh sửa</span>
                </button>
              )}

              {canDelete && (
                <button
                  type="button"
                  role="menuitem"
                  className="device-menu-item danger"
                  onClick={(e) => {
                    e.stopPropagation();
                    setOpenMenuId(null);
                    setConfirmDeleteId(device.id);
                  }}
                >
                  <Trash2 size={15} aria-hidden="true" />
                  <span>Xóa thiết bị</span>
                </button>
              )}
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="device-container">
      {/* 1. Top Priority KPI Cards (4-col desktop grid, interactive quick filters) */}
      <div className="device-stats-grid" role="group" aria-label="Thống kê nhanh trạng thái thiết bị">
        <button
          type="button"
          className={`device-stat-card is-interactive ${statusFilter === 'ALL' && !sortByLatency ? 'active total' : ''}`}
          aria-pressed={statusFilter === 'ALL' && !sortByLatency}
          onClick={handleSelectTotalKpi}
        >
          <div className="device-stat-icon total">
            <Cpu size={22} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Tổng thiết bị</span>
            <span className="device-stat-value">{stats.total}</span>
            <span className="device-stat-hint">Hiện tất cả</span>
          </div>
        </button>

        <button
          type="button"
          className={`device-stat-card is-interactive ${statusFilter === 'ONLINE' && !sortByLatency ? 'active online' : ''}`}
          aria-pressed={statusFilter === 'ONLINE' && !sortByLatency}
          onClick={() => handleToggleStatusKpi('ONLINE')}
        >
          <div className="device-stat-icon online">
            <Wifi size={22} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Hoạt động (Online)</span>
            <span className="device-stat-value" style={{ color: 'var(--color-success)' }}>
              {stats.online}
            </span>
            <span className="device-stat-hint">
              {statusFilter === 'ONLINE' && !sortByLatency ? 'Đang lọc Online' : 'Lọc thiết bị Online'}
            </span>
          </div>
        </button>

        <button
          type="button"
          className={`device-stat-card is-interactive ${statusFilter === 'OFFLINE' ? 'active offline' : ''}`}
          aria-pressed={statusFilter === 'OFFLINE'}
          onClick={() => handleToggleStatusKpi('OFFLINE')}
        >
          <div className="device-stat-icon offline">
            <WifiOff size={22} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Ngoại tuyến (Offline)</span>
            <span className="device-stat-value" style={{ color: 'var(--color-absent)' }}>
              {stats.offline}
            </span>
            <span className="device-stat-hint">
              {statusFilter === 'OFFLINE' ? 'Đang lọc Offline' : 'Lọc thiết bị Offline'}
            </span>
          </div>
        </button>

        <button
          type="button"
          className={`device-stat-card is-interactive ${sortByLatency ? 'active latency' : ''}`}
          aria-pressed={sortByLatency}
          onClick={handleToggleLatencyKpi}
        >
          <div className="device-stat-icon latency">
            <Activity size={22} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Độ trễ trung bình</span>
            <span className="device-stat-value" style={{ color: 'var(--color-leave)' }}>
              {stats.avgLatency > 0 ? `${stats.avgLatency} ms` : 'N/A'}
            </span>
            <span className="device-stat-hint">
              {sortByLatency ? 'Đang xếp theo độ trễ' : 'Lọc & xếp theo độ trễ'}
            </span>
          </div>
        </button>
      </div>

      {/* 2. Collapsible Grouped Attendance Tablet & Pending Reviews */}
      <AttendanceTabletPanel
        role={currentUser?.role}
        canStatus={canAction('DEVICE_STATUS_UPDATE')}
        canReview={canAction('ATTENDANCE_RECORD_UPDATE')}
        showToast={showToast}
      />

      {/* 3. Filter and Search Control Bar */}
      <div className="device-control-bar">
        <div className="device-filters-stack">
          <div className="device-filter-group" role="group" aria-label="Lọc theo vai trò">
            <button
              type="button"
              className={`device-filter-btn ${selectedType === 'ALL' ? 'active' : ''}`}
              onClick={() => setSelectedType('ALL')}
            >
              Tất cả
            </button>
            <button
              type="button"
              className={`device-filter-btn ${selectedType === 'ATTENDANCE' ? 'active' : ''}`}
              onClick={() => setSelectedType('ATTENDANCE')}
            >
              Chấm công
            </button>
            <button
              type="button"
              className={`device-filter-btn ${selectedType === 'WAREHOUSE' ? 'active' : ''}`}
              onClick={() => setSelectedType('WAREHOUSE')}
            >
              Kho bãi
            </button>
            <button
              type="button"
              className={`device-filter-btn ${selectedType === 'TECHNICIAN' ? 'active' : ''}`}
              onClick={() => setSelectedType('TECHNICIAN')}
            >
              Kỹ thuật
            </button>
          </div>

          <div className="device-filter-group connection-group" role="group" aria-label="Lọc theo loại kết nối">
            <button
              type="button"
              className={`device-filter-btn ${connectionFilter === 'ALL' ? 'active' : ''}`}
              onClick={() => setConnectionFilter('ALL')}
            >
              Tất cả kết nối ({stats.total})
            </button>
            <button
              type="button"
              className={`device-filter-btn ${connectionFilter === 'HARDWARE' ? 'active' : ''}`}
              onClick={() => setConnectionFilter('HARDWARE')}
            >
              <Server size={14} aria-hidden="true" />
              <span>Thiết bị vật lý (IP cố định) ({stats.hardwareCount})</span>
            </button>
            <button
              type="button"
              className={`device-filter-btn ${connectionFilter === 'MOBILE_APP' ? 'active' : ''}`}
              onClick={() => setConnectionFilter('MOBILE_APP')}
            >
              <Smartphone size={14} aria-hidden="true" />
              <span>Thiết bị cá nhân / App (Mobile) ({stats.mobileAppCount})</span>
            </button>
          </div>
        </div>

        <div className="device-search-actions">
          <div className="device-search-wrapper">
            <Search size={18} className="device-search-icon" />
            <input
              type="text"
              placeholder="Tìm theo tên, mã, IP, nền tảng..."
              className="device-search-input"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <div className="device-view-toggle" role="group" aria-label="Chế độ hiển thị">
            <button
              type="button"
              className={`device-view-btn ${viewMode === 'grid' ? 'active' : ''}`}
              onClick={() => setViewMode('grid')}
              title="Hiển thị dạng thẻ"
              aria-label="Hiển thị dạng thẻ"
            >
              <LayoutGrid size={16} />
            </button>
            <button
              type="button"
              className={`device-view-btn ${viewMode === 'table' ? 'active' : ''}`}
              onClick={() => setViewMode('table')}
              title="Hiển thị dạng bảng"
              aria-label="Hiển thị dạng bảng"
            >
              <List size={16} />
            </button>
          </div>

          <button
            type="button"
            className="action-btn"
            onClick={() => fetchDevices()}
            title="Làm mới danh sách"
            aria-label="Làm mới danh sách"
          >
            <RefreshCw size={16} className={loading ? 'spin' : ''} />
          </button>

          {canAction('DEVICE_PING') && (
            <button
              type="button"
              className="action-btn ping-all-btn"
              onClick={handlePingAll}
              disabled={isPingingAll || loading}
              title="Ping kiểm tra mạng toàn bộ thiết bị"
            >
              <Activity size={16} className={isPingingAll ? 'spin' : ''} />
              <span>{isPingingAll ? 'Đang ping...' : 'Ping tất cả'}</span>
            </button>
          )}

          {isManagerOrAbove &&
            canAction('DEVICE_CREATE') && (
              <button type="button" className="device-add-btn" onClick={handleOpenCreateModal}>
                <Plus size={16} />
                Thêm thiết bị
              </button>
            )}
        </div>

        {(statusFilter !== 'ALL' || sortByLatency) && (
          <div className="device-active-kpi-bar">
            <span>
              Bộ lọc nhanh:{' '}
              <strong>
                {sortByLatency
                  ? 'Đang xếp thiết bị Online theo độ trễ cao → thấp'
                  : statusFilter === 'ONLINE'
                  ? `Hoạt động (Online) (${filteredDevices.length})`
                  : `Ngoại tuyến (Offline) (${filteredDevices.length})`}
              </strong>
            </span>
            <button type="button" className="device-clear-kpi-btn" onClick={handleSelectTotalKpi}>
              <X size={13} aria-hidden="true" />
              <span>Bỏ lọc nhanh</span>
            </button>
          </div>
        )}
      </div>

      {/* 4. Device List (Card Grid or Compact Table) */}
      {loading && devices.length === 0 ? (
        <div className="loading-screen" style={{ minHeight: '200px' }}>
          Đang tải dữ liệu thiết bị...
        </div>
      ) : filteredDevices.length === 0 ? (
        <div className="device-empty-view">
          <WifiOff size={44} className="device-empty-icon" />
          <span className="device-empty-text">Không tìm thấy thiết bị nào phù hợp</span>
          <span>Thử điều chỉnh bộ lọc trạng thái, loại kết nối hoặc từ khóa tìm kiếm của bạn.</span>
          {(statusFilter !== 'ALL' || selectedType !== 'ALL' || connectionFilter !== 'ALL' || searchTerm) && (
            <button
              type="button"
              className="form-cancel-btn"
              onClick={() => {
                setStatusFilter('ALL');
                setSortByLatency(false);
                setSelectedType('ALL');
                setConnectionFilter('ALL');
                setSearchTerm('');
              }}
            >
              Đặt lại tất cả bộ lọc
            </button>
          )}
        </div>
      ) : viewMode === 'table' ? (
        <div className="device-table-wrap">
          <table className="device-table">
            <thead>
              <tr>
                <th>Thiết bị</th>
                <th>Loại &amp; Vai trò</th>
                <th>IP / Nền tảng</th>
                <th>Trạng thái</th>
                <th>Độ trễ</th>
                <th>Hoạt động cuối</th>
                <th className="text-right">Điều khiển</th>
              </tr>
            </thead>
            <tbody>
              {filteredDevices.map((device) => {
                const isHardware = getDeviceConnectionCategory(device) === 'HARDWARE';
                return (
                  <tr key={device.id} className={openMenuId === device.id ? 'menu-open' : ''}>
                    <td>
                      <div className="device-table-name-cell">
                        <div className={`device-avatar sm ${device.type.toLowerCase()}`}>
                          {getDeviceIcon(device.type)}
                        </div>
                        <div className="device-title-info">
                          <span className="device-name" title={device.name}>
                            {device.name}
                          </span>
                          <span className="device-id">
                            {device.deviceId} · v{device.version}
                          </span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="device-table-type-cell">
                        <span className="detail-value">{getTypeName(device.type)}</span>
                        <span className={`device-category-tag ${isHardware ? 'hardware' : 'mobile'}`}>
                          {isHardware ? 'Vật lý (IP tĩnh)' : 'Cá nhân / App'}
                        </span>
                      </div>
                    </td>
                    <td>{renderConnectionCell(device)}</td>
                    <td>
                      <span className={`device-status-badge ${device.status.toLowerCase()}`}>
                        <span className={`status-dot ${device.status.toLowerCase()}`} />
                        {device.status}
                      </span>
                    </td>
                    <td>
                      <span className={`detail-value ping ${device.pingMs > 30 ? 'high' : ''}`}>
                        {device.status === 'ONLINE' ? `${device.pingMs} ms` : 'N/A'}
                      </span>
                    </td>
                    <td>
                      <span className="detail-value">{formatActiveTime(device.lastActiveAt)}</span>
                    </td>
                    <td className="text-right">{renderDeviceControls(device)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="device-grid">
          {filteredDevices.map((device) => {
            const isHardware = getDeviceConnectionCategory(device) === 'HARDWARE';
            const isMenuOpen = openMenuId === device.id;
            return (
              <div
                key={device.id}
                className={`device-card ${device.status === 'ONLINE' ? 'online' : 'offline'} ${isMenuOpen ? 'menu-open' : ''}`}
              >
                <div className="device-card-header">
                  <div className="device-avatar-title">
                    <div className={`device-avatar ${device.type.toLowerCase()}`}>
                      {getDeviceIcon(device.type)}
                    </div>
                    <div className="device-title-info">
                      <span className="device-name" title={device.name}>
                        {device.name}
                      </span>
                      <span className="device-id">{device.deviceId}</span>
                    </div>
                  </div>

                  <span className={`device-status-badge ${device.status.toLowerCase()}`}>
                    <span className={`status-dot ${device.status.toLowerCase()}`} />
                    {device.status}
                  </span>
                </div>

                <div className="device-card-details">
                  <div className="detail-item">
                    <span className="detail-label">Phân loại</span>
                    <span className="detail-value">{getTypeName(device.type)}</span>
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">{isHardware ? 'IP Address' : 'Nền tảng'}</span>
                    {renderConnectionCell(device)}
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">
                      <Clock size={14} /> Hoạt động cuối
                    </span>
                    <span className="detail-value">{formatActiveTime(device.lastActiveAt)}</span>
                  </div>
                  <div className="detail-item">
                    <span className="detail-label">
                      <Activity size={14} /> Độ trễ ping
                    </span>
                    <span className={`detail-value ping ${device.pingMs > 30 ? 'high' : ''}`}>
                      {device.status === 'ONLINE' ? `${device.pingMs} ms` : 'N/A'}
                    </span>
                  </div>
                </div>

                <div className="device-card-actions">
                  <div className="device-card-meta">
                    <span>v{device.version}</span>
                    <span className={`device-category-tag ${isHardware ? 'hardware' : 'mobile'}`}>
                      {isHardware ? 'IP cố định' : 'App / Mobile'}
                    </span>
                  </div>

                  {renderDeviceControls(device)}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Add / Edit Form Modal */}
      {isFormOpen && (
        <div className="modal-overlay" onClick={() => setIsFormOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true">
            <div className="modal-header">
              <h3>{editingDevice ? 'Chỉnh sửa thiết bị' : 'Đăng ký thiết bị mới'}</h3>
              <button type="button" className="close-modal-btn" onClick={() => setIsFormOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body">
              {(editingDevice ? canAction('DEVICE_UPDATE') : canAction('DEVICE_CREATE')) && (
                <form className="device-form" onSubmit={handleFormSubmit}>
                  <div className="form-group">
                    <label htmlFor="deviceId">Mã thiết bị (Device ID) *</label>
                    <input
                      type="text"
                      id="deviceId"
                      className="form-input"
                      placeholder="Ví dụ: ATT-FREAD-01, WH-SCAN-03"
                      value={formData.deviceId}
                      onChange={(e) => setFormData((prev) => ({ ...prev, deviceId: e.target.value }))}
                      disabled={!!editingDevice}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label htmlFor="name">Tên thiết bị *</label>
                    <input
                      type="text"
                      id="name"
                      className="form-input"
                      placeholder="Ví dụ: Face ID Reader Cổng Chính"
                      value={formData.name}
                      onChange={(e) => setFormData((prev) => ({ ...prev, name: e.target.value }))}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label htmlFor="type">Phân loại vai trò thiết bị *</label>
                    <select
                      id="type"
                      className="form-input"
                      value={formData.type}
                      onChange={(e) =>
                        setFormData((prev) => ({ ...prev, type: e.target.value as DeviceInfo['type'] }))
                      }
                      required
                    >
                      <option value="ATTENDANCE">Chấm công (Attendance)</option>
                      <option value="WAREHOUSE">Kho bãi (Warehouse)</option>
                      <option value="TECHNICIAN">Kỹ thuật (Technician)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label htmlFor="ipAddress">Địa chỉ IP (IP Address) *</label>
                    <input
                      type="text"
                      id="ipAddress"
                      className="form-input"
                      placeholder="Ví dụ: 192.168.1.50"
                      value={formData.ipAddress}
                      onChange={(e) => setFormData((prev) => ({ ...prev, ipAddress: e.target.value }))}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label htmlFor="version">Phiên bản (Firmware Version)</label>
                    <input
                      type="text"
                      id="version"
                      className="form-input"
                      value={formData.version}
                      onChange={(e) => setFormData((prev) => ({ ...prev, version: e.target.value }))}
                    />
                  </div>

                  <div className="form-actions">
                    <button type="button" className="form-cancel-btn" onClick={() => setIsFormOpen(false)}>
                      Hủy bỏ
                    </button>
                    {(editingDevice ? canAction('DEVICE_UPDATE') : canAction('DEVICE_CREATE')) && (
                      <button type="submit" className="form-submit-btn">
                        {editingDevice ? 'Lưu thay đổi' : 'Đăng ký'}
                      </button>
                    )}
                  </div>
                </form>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Device Details Modal */}
      {detailDevice && (
        <div className="modal-overlay" onClick={() => setDetailDevice(null)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label="Chi tiết thiết bị">
            <div className="modal-header">
              <h3>Chi tiết thiết bị</h3>
              <button type="button" className="close-modal-btn" onClick={() => setDetailDevice(null)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body device-detail-modal-body">
              <div className="device-detail-summary">
                <div className={`device-avatar ${detailDevice.type.toLowerCase()}`}>
                  {getDeviceIcon(detailDevice.type)}
                </div>
                <div className="device-title-info">
                  <strong className="device-name">{detailDevice.name}</strong>
                  <span className="device-id">{detailDevice.deviceId}</span>
                </div>
                <span className={`device-status-badge ${detailDevice.status.toLowerCase()}`}>
                  <span className={`status-dot ${detailDevice.status.toLowerCase()}`} />
                  {detailDevice.status}
                </span>
              </div>

              <dl className="device-detail-dl">
                <div>
                  <dt>Nhóm kết nối</dt>
                  <dd>
                    {getDeviceConnectionCategory(detailDevice) === 'HARDWARE'
                      ? 'Thiết bị vật lý (IP cố định)'
                      : 'Thiết bị cá nhân / App (Mobile)'}
                  </dd>
                </div>
                <div>
                  <dt>Vai trò</dt>
                  <dd>{getTypeName(detailDevice.type)}</dd>
                </div>
                <div>
                  <dt>{getDeviceConnectionCategory(detailDevice) === 'HARDWARE' ? 'Địa chỉ IP' : 'Nền tảng'}</dt>
                  <dd>{renderConnectionCell(detailDevice)}</dd>
                </div>
                <div>
                  <dt>Phiên bản</dt>
                  <dd>v{detailDevice.version}</dd>
                </div>
                <div>
                  <dt>Độ trễ</dt>
                  <dd>{detailDevice.status === 'ONLINE' ? `${detailDevice.pingMs} ms` : 'N/A'}</dd>
                </div>
                <div>
                  <dt>Hoạt động cuối</dt>
                  <dd>{formatActiveTime(detailDevice.lastActiveAt)}</dd>
                </div>
              </dl>

              <div className="form-actions">
                {canAction('DEVICE_PING') && (
                  <button
                    type="button"
                    className="form-cancel-btn"
                    disabled={pingingId === detailDevice.id}
                    onClick={() => void handlePing(detailDevice.id)}
                  >
                    {pingingId === detailDevice.id ? 'Đang ping...' : 'Ping lại'}
                  </button>
                )}
                <button type="button" className="form-submit-btn" onClick={() => setDetailDevice(null)}>
                  Đóng
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Disconnect / Turn Off Dialog */}
      {confirmToggleDevice && (
        <div className="modal-overlay" onClick={() => setConfirmToggleDevice(null)}>
          <div
            className="modal-content"
            style={{ maxWidth: '420px' }}
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-label="Xác nhận tắt thiết bị"
          >
            <div className="modal-header warning">
              <h3>
                <AlertTriangle size={18} aria-hidden="true" style={{ marginRight: 8, verticalAlign: '-3px' }} />
                Xác nhận tắt / ngắt kết nối
              </h3>
              <button type="button" className="close-modal-btn" onClick={() => setConfirmToggleDevice(null)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '20px' }}>
              <span>
                Bạn có chắc chắn muốn tắt trạng thái hoạt động của thiết bị{' '}
                <strong>{confirmToggleDevice.name}</strong> ({confirmToggleDevice.deviceId})?
              </span>
              <div className="form-actions">
                <button
                  type="button"
                  className="form-cancel-btn"
                  disabled={togglingId === confirmToggleDevice.id}
                  onClick={() => setConfirmToggleDevice(null)}
                >
                  Hủy bỏ
                </button>
                <button
                  type="button"
                  className="form-submit-btn danger"
                  disabled={togglingId === confirmToggleDevice.id}
                  onClick={() => void executeToggleStatus(confirmToggleDevice.id)}
                >
                  {togglingId === confirmToggleDevice.id ? 'Đang xử lý...' : 'Xác nhận tắt'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Delete Modal */}
      {confirmDeleteId && (
        <div className="modal-overlay" onClick={() => setConfirmDeleteId(null)}>
          <div
            className="modal-content"
            style={{ maxWidth: '400px' }}
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-label="Xác nhận xóa thiết bị"
          >
            <div className="modal-header danger">
              <h3>Xác nhận xóa thiết bị</h3>
              <button type="button" className="close-modal-btn" onClick={() => setConfirmDeleteId(null)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '20px' }}>
              <span>Bạn có chắc chắn muốn xóa thiết bị này khỏi hệ thống không? Hành động này không thể hoàn tác.</span>
              <div className="form-actions">
                <button type="button" className="form-cancel-btn" onClick={() => setConfirmDeleteId(null)}>
                  Hủy bỏ
                </button>
                {canAction('DEVICE_DELETE') && (
                  <button
                    type="button"
                    className="form-submit-btn danger"
                    onClick={() => handleDeleteDevice(confirmDeleteId)}
                  >
                    Xóa bỏ
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

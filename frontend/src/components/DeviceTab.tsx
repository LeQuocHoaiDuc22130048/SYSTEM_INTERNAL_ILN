import React, { useState, useEffect, useMemo, useCallback } from 'react';
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
  Settings,
  X,
  ShieldCheck,
  UserCheck,
  User
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import './DeviceTab.css';

// Device type definition
export interface DeviceInfo {
  id: string; // UUID
  deviceId: string; // User-facing ID, e.g. ATT-FREAD-01
  name: string;
  type: string;
  status: 'ONLINE' | 'OFFLINE';
  ipAddress: string;
  lastActiveAt: string | null;
  pingMs: number;
  version: string;
}

interface DeviceTabProps {
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
}

export const DeviceTab: React.FC<DeviceTabProps> = ({ showToast, currentUser }) => {
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [selectedType, setSelectedType] = useState<string>('ALL');
  
  // Modals state
  const [isFormOpen, setIsFormOpen] = useState<boolean>(false);
  const [editingDevice, setEditingDevice] = useState<DeviceInfo | null>(null);
  const [formData, setFormData] = useState({
    deviceId: '',
    name: '',
    type: 'ATTENDANCE' as DeviceInfo['type'],
    ipAddress: '',
    version: '1.0.0'
  });
  
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  // Check if current user is manager/admin
  const isManagerOrAbove = useMemo(() => {
    if (!currentUser || !currentUser.role) return false;
    const role = currentUser.role.toUpperCase();
    return role === 'SUPER_ADMIN' || role === 'ADMIN' || role === 'MANAGER';
  }, [currentUser]);

  // Fetch devices list
  const fetchDevices = useCallback(async (silent = false) => {
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
  }, [showToast]);

  useEffect(() => {
    fetchDevices();
    
    // Auto refresh every 10 seconds for real-time monitoring feel
    const interval = setInterval(() => {
      fetchDevices(true);
    }, 10000);
    
    return () => clearInterval(interval);
  }, [fetchDevices]);

  // Stats calculation
  const stats = useMemo(() => {
    const total = devices.length;
    const online = devices.filter(d => d.status === 'ONLINE').length;
    const offline = total - online;
    
    const onlineDevices = devices.filter(d => d.status === 'ONLINE' && d.pingMs > 0);
    const avgLatency = onlineDevices.length > 0
      ? Math.round(onlineDevices.reduce((sum, d) => sum + d.pingMs, 0) / onlineDevices.length)
      : 0;

    return { total, online, offline, avgLatency };
  }, [devices]);

  // Filter and Search Devices
  const filteredDevices = useMemo(() => {
    const term = searchTerm.toLowerCase().trim();
    return devices.filter(device => {
      const matchesSearch = 
        device.name.toLowerCase().includes(term) ||
        device.deviceId.toLowerCase().includes(term) ||
        device.ipAddress.includes(term);
        
      const matchesType = 
        selectedType === 'ALL' || 
        device.type === selectedType;

      return matchesSearch && matchesType;
    });
  }, [devices, searchTerm, selectedType]);

  // Actions handlers
  const handlePing = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const response = await fetch(`/api/v1/devices/${id}/ping`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          // Update device in state
          setDevices(prev => prev.map(d => d.id === id ? result.data : d));
          showToast(`Ping tới thiết bị thành công! Phản hồi: ${result.data.pingMs}ms`);
        }
      } else {
        showToast('Lỗi gửi lệnh ping tới thiết bị.');
      }
    } catch (error) {
      console.error('Error pinging device:', error);
      showToast('Không thể kết nối đến máy chủ.');
    }
  };

  const handleToggleStatus = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const response = await fetch(`/api/v1/devices/${id}/toggle`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setDevices(prev => prev.map(d => d.id === id ? result.data : d));
          showToast(`Đã chuyển đổi trạng thái thiết bị sang ${result.data.status}`);
        }
      } else {
        showToast('Không thể thay đổi trạng thái thiết bị.');
      }
    } catch (error) {
      console.error('Error toggling status:', error);
      showToast('Lỗi kết nối mạng.');
    }
  };

  const handleOpenCreateModal = () => {
    setEditingDevice(null);
    setFormData({
      deviceId: '',
      name: '',
      type: 'ATTENDANCE',
      ipAddress: '',
      version: '1.0.0'
    });
    setIsFormOpen(true);
  };

  const handleOpenEditModal = (device: DeviceInfo, e: React.MouseEvent) => {
    e.stopPropagation();
    setEditingDevice(device);
    setFormData({
      deviceId: device.deviceId,
      name: device.name,
      type: device.type,
      ipAddress: device.ipAddress,
      version: device.version
    });
    setIsFormOpen(true);
  };

  const handleFormSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Simple Validation
    if (!formData.deviceId.trim() || !formData.name.trim() || !formData.ipAddress.trim()) {
      showToast('Vui lòng điền đầy đủ các thông tin bắt buộc.');
      return;
    }

    try {
      const url = editingDevice 
        ? `/api/v1/devices/${editingDevice.id}`
        : '/api/v1/devices';
      
      const method = editingDevice ? 'PUT' : 'POST';

      const response = await fetch(url, {
        method,
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(formData)
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
        headers: getAuthHeaders()
      });
      if (response.ok) {
        showToast('Xóa thiết bị thành công.');
        setConfirmDeleteId(null);
        fetchDevices();
      } else {
        showToast('Không thể xóa thiết bị.');
      }
    } catch (error) {
      console.error('Error deleting device:', error);
      showToast('Lỗi kết nối mạng.');
    }
  };

  // Helper render device type icon
  const getDeviceIcon = (type: string) => {
    switch (type) {
      case 'ATTENDANCE':
        return <Fingerprint size={24} />;
      case 'WAREHOUSE':
        return <Barcode size={24} />;
      case 'TECHNICIAN':
        return <Smartphone size={24} />;
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return <ShieldCheck size={24} />;
      case 'MANAGER':
        return <UserCheck size={24} />;
      case 'EMPLOYEE':
      case 'RECEPTIONIST':
        return <User size={24} />;
      default:
        return <Cpu size={24} />;
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

  // Format active time relative
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
      month: '2-digit'
    });
  };

  return (
    <div className="device-container">
      {/* Bento Grid Stats */}
      <div className="device-stats-grid">
        <div className="device-stat-card">
          <div className="device-stat-icon total">
            <Cpu size={24} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Tổng thiết bị</span>
            <span className="device-stat-value">{stats.total}</span>
          </div>
        </div>

        <div className="device-stat-card">
          <div className="device-stat-icon online">
            <Wifi size={24} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Hoạt động (Online)</span>
            <span className="device-stat-value" style={{ color: 'var(--color-success)' }}>
              {stats.online}
            </span>
          </div>
        </div>

        <div className="device-stat-card">
          <div className="device-stat-icon offline">
            <WifiOff size={24} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Ngoại tuyến (Offline)</span>
            <span className="device-stat-value" style={{ color: 'var(--color-absent)' }}>
              {stats.offline}
            </span>
          </div>
        </div>

        <div className="device-stat-card">
          <div className="device-stat-icon latency">
            <Activity size={24} />
          </div>
          <div className="device-stat-info">
            <span className="device-stat-label">Độ trễ trung bình</span>
            <span className="device-stat-value" style={{ color: 'var(--color-leave)' }}>
              {stats.avgLatency > 0 ? `${stats.avgLatency} ms` : 'N/A'}
            </span>
          </div>
        </div>
      </div>

      {/* Filter and Search actions */}
      <div className="device-control-bar">
        <div className="device-filter-group">
          <button
            className={`device-filter-btn ${selectedType === 'ALL' ? 'active' : ''}`}
            onClick={() => setSelectedType('ALL')}
          >
            Tất cả
          </button>
          <button
            className={`device-filter-btn ${selectedType === 'ATTENDANCE' ? 'active' : ''}`}
            onClick={() => setSelectedType('ATTENDANCE')}
          >
            Chấm công (Attendance)
          </button>
          <button
            className={`device-filter-btn ${selectedType === 'WAREHOUSE' ? 'active' : ''}`}
            onClick={() => setSelectedType('WAREHOUSE')}
          >
            Kho bãi (Warehouse)
          </button>
          <button
            className={`device-filter-btn ${selectedType === 'TECHNICIAN' ? 'active' : ''}`}
            onClick={() => setSelectedType('TECHNICIAN')}
          >
            Kỹ thuật (Technician)
          </button>
        </div>

        <div className="device-search-actions">
          <div className="device-search-wrapper">
            <Search size={18} className="device-search-icon" />
            <input
              type="text"
              placeholder="Tìm theo tên, mã, IP..."
              className="device-search-input"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <button className="action-btn" onClick={() => fetchDevices()} title="Làm mới">
            <RefreshCw size={16} className={loading ? 'spin' : ''} />
          </button>

          {isManagerOrAbove && (
            <button className="device-add-btn" onClick={handleOpenCreateModal}>
              <Plus size={16} />
              Thêm thiết bị
            </button>
          )}
        </div>
      </div>

      {/* Grid of Devices */}
      {loading && devices.length === 0 ? (
        <div className="loading-screen" style={{ minHeight: '200px' }}>
          Đang tải dữ liệu thiết bị...
        </div>
      ) : filteredDevices.length === 0 ? (
        <div className="device-empty-view">
          <WifiOff size={48} className="device-empty-icon" />
          <span className="device-empty-text">Không tìm thấy thiết bị nào phù hợp</span>
          <span>Thử điều chỉnh bộ lọc hoặc từ khóa tìm kiếm của bạn.</span>
        </div>
      ) : (
        <div className="device-grid">
          {filteredDevices.map(device => (
            <div
              key={device.id}
              className={`device-card ${device.status === 'ONLINE' ? 'online' : 'offline'}`}
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
                  <span className="detail-label">IP Address</span>
                  <span className="detail-value ip">{device.ipAddress}</span>
                </div>
                <div className="detail-item">
                  <span className="detail-label">
                    <Clock size={14} /> Hoạt động cuối
                  </span>
                  <span className="detail-value">
                    {formatActiveTime(device.lastActiveAt)}
                  </span>
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
                <div style={{ flexGrow: 1, fontSize: '0.75rem', color: 'var(--color-text-light)', fontWeight: 500 }}>
                  v{device.version}
                </div>

                {/* Simulate heartbeat/ping (Any active user can call) */}
                <button
                  className="action-btn ping"
                  onClick={(e) => handlePing(device.id, e)}
                  title="Gửi tín hiệu Ping"
                >
                  <Wifi size={20} />
                </button>

                {/* Toggle simulated status (Only managers/admins) */}
                {isManagerOrAbove && (
                  <button
                    className="action-btn toggle-sim"
                    onClick={(e) => handleToggleStatus(device.id, e)}
                    title="Bật/Tắt Giả lập"
                  >
                    <Settings size={18} />
                    <span>{device.status === 'ONLINE' ? 'Tắt' : 'Bật'}</span>
                  </button>
                )}

                {/* Edit & Delete Actions (Only managers/admins) */}
                {isManagerOrAbove && (
                  <>
                    <button
                      className="action-btn edit"
                      onClick={(e) => handleOpenEditModal(device, e)}
                      title="Chỉnh sửa"
                    >
                      <Edit size={20} />
                    </button>
                    <button
                      className="action-btn delete"
                      onClick={(e) => {
                        e.stopPropagation();
                        setConfirmDeleteId(device.id);
                      }}
                      title="Xóa thiết bị"
                    >
                      <Trash2 size={20} />
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add / Edit Form Modal */}
      {isFormOpen && (
        <div className="modal-overlay" onClick={() => setIsFormOpen(false)}>
          <div className="modal-content" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editingDevice ? 'Chỉnh sửa thiết bị' : 'Đăng ký thiết bị mới'}</h3>
              <button className="close-modal-btn" onClick={() => setIsFormOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body">
              <form className="device-form" onSubmit={handleFormSubmit}>
                <div className="form-group">
                  <label htmlFor="deviceId">Mã thiết bị (Device ID) *</label>
                  <input
                    type="text"
                    id="deviceId"
                    className="form-input"
                    placeholder="Ví dụ: ATT-FREAD-01, WH-SCAN-03"
                    value={formData.deviceId}
                    onChange={(e) => setFormData(prev => ({ ...prev, deviceId: e.target.value }))}
                    disabled={!!editingDevice} // Prevent editing device ID for safety
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
                    onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                    required
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="type">Phân loại vai trò thiết bị *</label>
                  <select
                    id="type"
                    className="form-input"
                    value={formData.type}
                    onChange={(e) => setFormData(prev => ({ ...prev, type: e.target.value as DeviceInfo['type'] }))}
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
                    onChange={(e) => setFormData(prev => ({ ...prev, ipAddress: e.target.value }))}
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
                    onChange={(e) => setFormData(prev => ({ ...prev, version: e.target.value }))}
                  />
                </div>

                <div className="form-actions">
                  <button type="button" className="form-cancel-btn" onClick={() => setIsFormOpen(false)}>
                    Hủy bỏ
                  </button>
                  <button type="submit" className="form-submit-btn">
                    {editingDevice ? 'Lưu thay đổi' : 'Đăng ký'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Delete Modal */}
      {confirmDeleteId && (
        <div className="modal-overlay" onClick={() => setConfirmDeleteId(null)}>
          <div className="modal-content" style={{ maxWidth: '400px' }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header" style={{ background: 'var(--color-absent)' }}>
              <h3>Xác nhận xóa thiết bị</h3>
              <button className="close-modal-btn" onClick={() => setConfirmDeleteId(null)}>
                <X size={18} />
              </button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '20px' }}>
              <span>Bạn có chắc chắn muốn xóa thiết bị này khỏi hệ thống không? Hành động này không thể hoàn tác.</span>
              <div className="form-actions">
                <button type="button" className="form-cancel-btn" onClick={() => setConfirmDeleteId(null)}>
                  Hủy bỏ
                </button>
                <button
                  type="button"
                  className="form-submit-btn"
                  style={{ background: 'var(--color-absent)' }}
                  onClick={() => handleDeleteDevice(confirmDeleteId)}
                >
                  Xóa bỏ
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

import React, { useState } from 'react';
import {
  Calendar,
  Clock,
  Cpu,
  RefreshCw,
  ChevronDown,
  ChevronRight,
  ClipboardCheck,
  Smartphone,
  LogOut,
  Wrench,
  ClipboardList,
  Boxes,
  Users,
  ShieldCheck,
  LayoutDashboard,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { isAdminOrAbove, isManagerOrAbove as _isManagerOrAbove, getRoleLabel } from '../utils/permissions';

interface SidebarProps {
  activeTab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts';
  setActiveTab: (tab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts') => void;
  currentUser: UserInfo | null;
  isOpen: boolean;
  onClose: () => void;
  handleLogout: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  currentUser,
  isOpen,
  onClose,
  handleLogout,
}) => {
  // Trạng thái mở/đóng của các nhóm mục cha
  const [isAttendanceOpen, setIsAttendanceOpen] = useState<boolean>(true);
  const [isDeviceOpen, setIsDeviceOpen] = useState<boolean>(true);
  const [isBusinessOpen, setIsBusinessOpen] = useState<boolean>(true);

  const isManagerOrAbove = React.useMemo(() => _isManagerOrAbove(currentUser), [currentUser]);
  const showAccountsTab = React.useMemo(() => isAdminOrAbove(currentUser), [currentUser]);

  const handleTabClick = (tab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts') => {
    setActiveTab(tab);
    if (window.innerWidth <= 1024) {
      onClose(); // Đóng sidebar trên mobile sau khi click
    }
  };

  return (
    <>
      {/* Vùng overlay tối màu khi mở sidebar trên thiết bị di động */}
      {isOpen && <div className="sidebar-overlay" onClick={onClose} />}

      <aside className={`sidebar ${isOpen ? 'open' : ''}`}>
        {/* Header của Sidebar */}
        <div className="sidebar-header">
          <div className="brand">
            <img src="/app_logo.png" alt="Logo" className="brand-logo" />
            <div className="brand-info">
              <span className="brand-name">INVERTER LIKE NEW</span>
              <span className="brand-sub">Quản lý hệ thống</span>
            </div>
          </div>
          {/* <button className="sidebar-close-btn" onClick={onClose} aria-label="Close sidebar">
            <X size={20} />
          </button> */}
          {/* <button className="sidebar-collapse-btn" onClick={onClose} aria-label="Collapse sidebar">
            <ChevronLeft size={20} />
          </button> */}
        </div>

        {/* Menu Items */}
        <nav className="sidebar-nav">
          {/* DASHBOARD */}
          <div className="menu-group">
            <button
              className={`menu-item-direct ${activeTab === 'dashboard' ? 'active' : ''}`}
              onClick={() => handleTabClick('dashboard')}
              id="sidebar-dashboard-btn"
            >
              <LayoutDashboard size={18} className="item-icon" />
              <span>Dashboard</span>
            </button>
          </div>

          {/* NHÓM 1: QUẢN LÝ CHẤM CÔNG */}
          <div className="menu-group">
            <button
              className="menu-group-header"
              onClick={() => setIsAttendanceOpen(!isAttendanceOpen)}
            >
              <div className="menu-group-title">
                <ClipboardCheck size={18} className="group-icon" />
                <span>Quản lý chấm công</span>
              </div>
              {isAttendanceOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            </button>

            {isAttendanceOpen && (
              <div className="menu-sub-items">
                <button
                  className={`menu-item ${activeTab === 'monthly' ? 'active' : ''}`}
                  onClick={() => handleTabClick('monthly')}
                >
                  <Calendar size={16} className="item-icon" />
                  <span>Xem theo tháng</span>
                </button>
                <button
                  className={`menu-item ${activeTab === 'daily' ? 'active' : ''}`}
                  onClick={() => handleTabClick('daily')}
                >
                  <Clock size={16} className="item-icon" />
                  <span>Xem theo ngày</span>
                </button>
              </div>
            )}
          </div>

          {/* NHÓM 2: THIẾT BỊ */}
          <div className="menu-group">
            <button
              className="menu-group-header"
              onClick={() => setIsDeviceOpen(!isDeviceOpen)}
            >
              <div className="menu-group-title">
                <Cpu size={18} className="group-icon" />
                <span>Thiết bị</span>
              </div>
              {isDeviceOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            </button>

            {isDeviceOpen && (
              <div className="menu-sub-items">
                <button
                  className={`menu-item ${activeTab === 'devices' ? 'active' : ''}`}
                  onClick={() => handleTabClick('devices')}
                >
                  <Smartphone size={16} className="item-icon" />
                  <span>Trạng thái thiết bị</span>
                </button>
                {isManagerOrAbove && (
                  <button
                    className={`menu-item ${activeTab === 'updates' ? 'active' : ''}`}
                    onClick={() => handleTabClick('updates')}
                  >
                    <RefreshCw size={16} className="item-icon" />
                    <span>Cập nhật ứng dụng</span>
                  </button>
                )}
              </div>
            )}
          </div>

          {/* NHÓM 3: NGHIỆP VỤ */}
          <div className="menu-group">
            <button
              className="menu-group-header"
              onClick={() => setIsBusinessOpen(!isBusinessOpen)}
            >
              <div className="menu-group-title">
                <Wrench size={18} className="group-icon" />
                <span>Nghiệp vụ</span>
              </div>
              {isBusinessOpen ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
            </button>

            {isBusinessOpen && (
              <div className="menu-sub-items">
                <button
                  className={`menu-item ${activeTab === 'orders' ? 'active' : ''}`}
                  onClick={() => handleTabClick('orders')}
                >
                  <ClipboardList size={16} className="item-icon" />
                  <span>Đơn sửa chữa</span>
                </button>
                <button
                  className={`menu-item ${activeTab === 'warehouse' ? 'active' : ''}`}
                  onClick={() => handleTabClick('warehouse')}
                >
                  <Boxes size={16} className="item-icon" />
                  <span>Kho bo mạch</span>
                </button>
              </div>
            )}
          </div>

          {/* NHÓM 4: QUẢN LÝ TÀI KHOẢN — chỉ ADMIN+ */}
          {showAccountsTab && (
            <div className="menu-group">
              <div className="menu-group-header" style={{ cursor: 'default' }}>
                <div className="menu-group-title">
                  <ShieldCheck size={18} className="group-icon" />
                  <span>Phân quyền</span>
                </div>
              </div>
              <div className="menu-sub-items">
                <button
                  className={`menu-item ${activeTab === 'accounts' ? 'active' : ''}`}
                  onClick={() => handleTabClick('accounts')}
                >
                  <Users size={16} className="item-icon" />
                  <span>Quản lý tài khoản</span>
                </button>
              </div>
            </div>
          )}
        </nav>

        {/* Footer của Sidebar */}
        <div className="sidebar-footer">
          {currentUser && (
            <div className="sidebar-user-panel">
              <div className="user-avatar">
                {currentUser.fullName ? currentUser.fullName.charAt(0).toUpperCase() : currentUser.username.charAt(0).toUpperCase()}
              </div>
              <div className="user-details">
                <span className="user-name" title={currentUser.fullName || currentUser.username}>
                  {currentUser.fullName || currentUser.username}
                </span>
                <span className="user-role">
                  {getRoleLabel(currentUser.role)}
                </span>
              </div>
              <button 
                className="sidebar-logout-btn" 
                onClick={handleLogout} 
                title="Đăng xuất"
                aria-label="Logout"
              >
                <LogOut size={16} />
              </button>
            </div>
          )}
          <span className="version-tag">Version 1.0.0</span>
        </div>
      </aside>
    </>
  );
};

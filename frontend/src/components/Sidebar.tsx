import React, { useState, useEffect, useMemo } from 'react';
import {
  Calendar,
  Clock,
  Cpu,
  RefreshCw,
  ChevronDown,
  ClipboardCheck,
  Smartphone,
  LogOut,
  Wrench,
  ClipboardList,
  Boxes,
  Users,
  ShieldCheck,
  LayoutDashboard,
  X,
  Image as ImageIcon,
  PanelLeftClose,
  PanelLeftOpen,
  MapPin,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { isAdminOrAbove, isManagerOrAbove as _isManagerOrAbove, getRoleLabel } from '../utils/permissions';

export type SidebarTab =
  | 'dashboard'
  | 'monthly'
  | 'daily'
  | 'devices'
  | 'updates'
  | 'banners'
  | 'orders'
  | 'warehouse'
  | 'locations'
  | 'accounts';

type GroupKey = 'attendance' | 'device' | 'business' | 'accounts';

interface SidebarProps {
  activeTab: SidebarTab;
  setActiveTab: (tab: SidebarTab) => void;
  currentUser: UserInfo | null;
  handleLogout: () => void;
  isOpen?: boolean;
  onClose?: () => void;
  isCollapsed?: boolean;
  onToggleCollapse?: () => void;
  dataSource?: 'api' | 'error' | 'loading';
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  currentUser,
  handleLogout,
  isOpen = false,
  onClose,
  isCollapsed = false,
  onToggleCollapse,
  dataSource = 'api',
}) => {
  const isManagerOrAbove = useMemo(() => _isManagerOrAbove(currentUser), [currentUser]);
  const showAccountsTab = useMemo(() => isAdminOrAbove(currentUser), [currentUser]);

  // Xác định nhóm cha tương ứng với tab
  const getGroupByTab = (tab: SidebarTab): GroupKey | null => {
    if (tab === 'monthly' || tab === 'daily') return 'attendance';
    if (tab === 'devices' || tab === 'updates' || tab === 'banners') return 'device';
    if (tab === 'orders' || tab === 'warehouse' || tab === 'locations') return 'business';
    if (tab === 'accounts') return 'accounts';
    return null;
  };

  // Quản lý trạng thái mở của nhóm cha (Accordion: chỉ 1 nhóm mở tại 1 thời điểm)
  const [openGroup, setOpenGroup] = useState<GroupKey | null>(() => getGroupByTab(activeTab));

  // Tự động đồng bộ nhóm cha khi activeTab thay đổi sang nhóm khác
  useEffect(() => {
    const group = getGroupByTab(activeTab);
    if (group) {
      setOpenGroup(group);
    }
  }, [activeTab]);

  // Xử lý đóng/mở nhóm cha theo cơ chế Accordion
  const handleToggleGroup = (group: GroupKey) => {
    if (isCollapsed && onToggleCollapse) {
      // Khi đang thu gọn, click vào icon mục cha sẽ phóng to sidebar và mở nhóm đó
      onToggleCollapse();
      setOpenGroup(group);
      return;
    }
    // Khi chọn vào mục cha khác, ẩn nhóm cũ và hiện nhóm mới.
    // Nếu chọn lại chính mục cha đang mở thì ẩn nhóm đó.
    setOpenGroup(prev => (prev === group ? null : group));
  };

  const handleTabClick = (tab: SidebarTab) => {
    setActiveTab(tab);
    if (onClose) {
      onClose();
    }
  };

  // Kiểm tra nhóm nào có chứa tab đang active
  const isAttendanceActive = activeTab === 'monthly' || activeTab === 'daily';
  const isDeviceActive = activeTab === 'devices' || activeTab === 'updates' || activeTab === 'banners';
  const isBusinessActive = activeTab === 'orders' || activeTab === 'warehouse' || activeTab === 'locations';
  const isAccountsActive = activeTab === 'accounts';

  return (
    <aside className={`sidebar ${isOpen ? 'open' : ''} ${isCollapsed ? 'collapsed' : ''}`}>
      {/* Header của Sidebar */}
      <div className="sidebar-header">
        <div className="brand" title="INVERTER LIKE NEW">
          <div className="brand-logo-container">
            <img src="/app_logo.png" alt="Logo" className="brand-logo" />
            <span
              className={`brand-status-dot ${dataSource || 'api'}`}
              title={
                dataSource === 'error'
                  ? 'Hệ thống: Mất kết nối máy chủ'
                  : dataSource === 'loading'
                  ? 'Hệ thống: Đang kết nối...'
                  : 'Hệ thống: Hoạt động bình thường'
              }
              aria-label={
                dataSource === 'error'
                  ? 'Hệ thống: Mất kết nối máy chủ'
                  : dataSource === 'loading'
                  ? 'Hệ thống: Đang kết nối...'
                  : 'Hệ thống: Hoạt động bình thường'
              }
            />
          </div>
          <div className="brand-info">
            <span className="brand-name">INVERTER LIKE NEW</span>
            <span className="brand-sub">Quản lý hệ thống</span>
          </div>
        </div>

        {/* Nút đóng Sidebar trên Mobile/Tablet Drawer */}
        {onClose && (
          <button
            type="button"
            className="sidebar-close-btn mobile-only"
            onClick={onClose}
            title="Đóng thanh điều hướng"
            aria-label="Đóng thanh điều hướng"
          >
            <X size={20} />
          </button>
        )}
      </div>

      {/* Menu Items */}
      <nav className="sidebar-nav">
        {/* DASHBOARD */}
        <div className="sidebar-nav-item-wrap">
          <button
            className={`menu-item-direct ${activeTab === 'dashboard' ? 'active' : ''}`}
            onClick={() => handleTabClick('dashboard')}
            id="sidebar-dashboard-btn"
            title={isCollapsed ? 'Dashboard tổng hợp' : undefined}
          >
            <LayoutDashboard size={19} className="item-icon" />
            <span className="menu-label">Dashboard</span>
          </button>
          {isCollapsed && <div className="sidebar-flyout-tooltip">Dashboard</div>}
        </div>

        {/* NHÓM 1: QUẢN LÝ CHẤM CÔNG */}
        <div className={`sidebar-nav-item-wrap menu-group ${openGroup === 'attendance' ? 'open' : ''}`}>
          <button
            type="button"
            className={`menu-group-header ${openGroup === 'attendance' ? 'open' : ''} ${isAttendanceActive ? 'has-active' : ''}`}
            onClick={() => handleToggleGroup('attendance')}
            title={isCollapsed ? 'Quản lý chấm công' : undefined}
          >
            {/* Thanh trạng thái ẩn hiện ở cạnh trái */}
            <span
              className={`group-status-bar ${openGroup === 'attendance' ? 'open' : ''} ${isAttendanceActive ? 'active' : ''}`}
            />
            <div className="menu-group-title">
              <ClipboardCheck size={19} className="group-icon" />
              <span className="menu-label">Quản lý chấm công</span>
            </div>
            <div className="group-header-right">
              {isAttendanceActive && openGroup !== 'attendance' && (
                <span className="group-active-dot" title="Có mục đang chọn" />
              )}
              <ChevronDown
                size={16}
                className={`group-chevron ${openGroup === 'attendance' ? 'rotated' : ''}`}
              />
            </div>
          </button>

          {/* Submenu inline cho chế độ bình thường */}
          <div className={`menu-sub-items-wrapper ${openGroup === 'attendance' ? 'open' : ''}`}>
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
          </div>

          {/* Submenu flyout nổi cho chế độ thu gọn (mini-sidebar) */}
          {isCollapsed && (
            <div className="sidebar-flyout-menu">
              <div className="flyout-header">
                <ClipboardCheck size={16} />
                <span>Quản lý chấm công</span>
              </div>
              <div className="flyout-items">
                <button
                  className={`flyout-item ${activeTab === 'monthly' ? 'active' : ''}`}
                  onClick={() => handleTabClick('monthly')}
                >
                  <Calendar size={15} />
                  <span>Xem theo tháng</span>
                </button>
                <button
                  className={`flyout-item ${activeTab === 'daily' ? 'active' : ''}`}
                  onClick={() => handleTabClick('daily')}
                >
                  <Clock size={15} />
                  <span>Xem theo ngày</span>
                </button>
              </div>
            </div>
          )}
        </div>

        {/* NHÓM 2: THIẾT BỊ */}
        <div className={`sidebar-nav-item-wrap menu-group ${openGroup === 'device' ? 'open' : ''}`}>
          <button
            type="button"
            className={`menu-group-header ${openGroup === 'device' ? 'open' : ''} ${isDeviceActive ? 'has-active' : ''}`}
            onClick={() => handleToggleGroup('device')}
            title={isCollapsed ? 'Thiết bị' : undefined}
          >
            {/* Thanh trạng thái ẩn hiện ở cạnh trái */}
            <span
              className={`group-status-bar ${openGroup === 'device' ? 'open' : ''} ${isDeviceActive ? 'active' : ''}`}
            />
            <div className="menu-group-title">
              <Cpu size={19} className="group-icon" />
              <span className="menu-label">Thiết bị</span>
            </div>
            <div className="group-header-right">
              {isDeviceActive && openGroup !== 'device' && (
                <span className="group-active-dot" title="Có mục đang chọn" />
              )}
              <ChevronDown
                size={16}
                className={`group-chevron ${openGroup === 'device' ? 'rotated' : ''}`}
              />
            </div>
          </button>

          {/* Submenu inline cho chế độ bình thường */}
          <div className={`menu-sub-items-wrapper ${openGroup === 'device' ? 'open' : ''}`}>
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
              {isManagerOrAbove && (
                <button
                  className={`menu-item ${activeTab === 'banners' ? 'active' : ''}`}
                  onClick={() => handleTabClick('banners')}
                >
                  <ImageIcon size={16} className="item-icon" />
                  <span>Banner ứng dụng</span>
                </button>
              )}
            </div>
          </div>

          {/* Submenu flyout nổi cho chế độ thu gọn (mini-sidebar) */}
          {isCollapsed && (
            <div className="sidebar-flyout-menu">
              <div className="flyout-header">
                <Cpu size={16} />
                <span>Thiết bị</span>
              </div>
              <div className="flyout-items">
                <button
                  className={`flyout-item ${activeTab === 'devices' ? 'active' : ''}`}
                  onClick={() => handleTabClick('devices')}
                >
                  <Smartphone size={15} />
                  <span>Trạng thái thiết bị</span>
                </button>
                {isManagerOrAbove && (
                  <button
                    className={`flyout-item ${activeTab === 'updates' ? 'active' : ''}`}
                    onClick={() => handleTabClick('updates')}
                  >
                    <RefreshCw size={15} />
                    <span>Cập nhật ứng dụng</span>
                  </button>
                )}
                {isManagerOrAbove && (
                  <button
                    className={`flyout-item ${activeTab === 'banners' ? 'active' : ''}`}
                    onClick={() => handleTabClick('banners')}
                  >
                    <ImageIcon size={15} />
                    <span>Banner ứng dụng</span>
                  </button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* NHÓM 3: NGHIỆP VỤ */}
        <div className={`sidebar-nav-item-wrap menu-group ${openGroup === 'business' ? 'open' : ''}`}>
          <button
            type="button"
            className={`menu-group-header ${openGroup === 'business' ? 'open' : ''} ${isBusinessActive ? 'has-active' : ''}`}
            onClick={() => handleToggleGroup('business')}
            title={isCollapsed ? 'Nghiệp vụ' : undefined}
          >
            {/* Thanh trạng thái ẩn hiện ở cạnh trái */}
            <span
              className={`group-status-bar ${openGroup === 'business' ? 'open' : ''} ${isBusinessActive ? 'active' : ''}`}
            />
            <div className="menu-group-title">
              <Wrench size={19} className="group-icon" />
              <span className="menu-label">Nghiệp vụ</span>
            </div>
            <div className="group-header-right">
              {isBusinessActive && openGroup !== 'business' && (
                <span className="group-active-dot" title="Có mục đang chọn" />
              )}
              <ChevronDown
                size={16}
                className={`group-chevron ${openGroup === 'business' ? 'rotated' : ''}`}
              />
            </div>
          </button>

          {/* Submenu inline cho chế độ bình thường */}
          <div className={`menu-sub-items-wrapper ${openGroup === 'business' ? 'open' : ''}`}>
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
                <span>Kho bo mạch & Linh kiện</span>
              </button>
              <button
                className={`menu-item ${activeTab === 'locations' ? 'active' : ''}`}
                onClick={() => handleTabClick('locations')}
              >
                <MapPin size={16} className="item-icon" />
                <span>Vị trí & Kệ kho</span>
              </button>
            </div>
          </div>

          {/* Submenu flyout nổi cho chế độ thu gọn (mini-sidebar) */}
          {isCollapsed && (
            <div className="sidebar-flyout-menu">
              <div className="flyout-header">
                <Wrench size={16} />
                <span>Nghiệp vụ</span>
              </div>
              <div className="flyout-items">
                <button
                  className={`flyout-item ${activeTab === 'orders' ? 'active' : ''}`}
                  onClick={() => handleTabClick('orders')}
                >
                  <ClipboardList size={15} />
                  <span>Đơn sửa chữa</span>
                </button>
                <button
                  className={`flyout-item ${activeTab === 'warehouse' ? 'active' : ''}`}
                  onClick={() => handleTabClick('warehouse')}
                >
                  <Boxes size={15} />
                  <span>Kho bo mạch & Linh kiện</span>
                </button>
                <button
                  className={`flyout-item ${activeTab === 'locations' ? 'active' : ''}`}
                  onClick={() => handleTabClick('locations')}
                >
                  <MapPin size={15} />
                  <span>Vị trí & Kệ kho</span>
                </button>
              </div>
            </div>
          )}
        </div>

        {/* NHÓM 4: QUẢN LÝ TÀI KHOẢN — chỉ ADMIN+ */}
        {showAccountsTab && (
          <div className={`sidebar-nav-item-wrap menu-group ${openGroup === 'accounts' ? 'open' : ''}`}>
            <button
              type="button"
              className={`menu-group-header ${openGroup === 'accounts' ? 'open' : ''} ${isAccountsActive ? 'has-active' : ''}`}
              onClick={() => handleToggleGroup('accounts')}
              title={isCollapsed ? 'Phân quyền' : undefined}
            >
              {/* Thanh trạng thái ẩn hiện ở cạnh trái */}
              <span
                className={`group-status-bar ${openGroup === 'accounts' ? 'open' : ''} ${isAccountsActive ? 'active' : ''}`}
              />
              <div className="menu-group-title">
                <ShieldCheck size={19} className="group-icon" />
                <span className="menu-label">Phân quyền</span>
              </div>
              <div className="group-header-right">
                {isAccountsActive && openGroup !== 'accounts' && (
                  <span className="group-active-dot" title="Có mục đang chọn" />
                )}
                <ChevronDown
                  size={16}
                  className={`group-chevron ${openGroup === 'accounts' ? 'rotated' : ''}`}
                />
              </div>
            </button>

            {/* Submenu inline */}
            <div className={`menu-sub-items-wrapper ${openGroup === 'accounts' ? 'open' : ''}`}>
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

            {/* Submenu flyout nổi cho chế độ thu gọn */}
            {isCollapsed && (
              <div className="sidebar-flyout-menu">
                <div className="flyout-header">
                  <ShieldCheck size={16} />
                  <span>Phân quyền</span>
                </div>
                <div className="flyout-items">
                  <button
                    className={`flyout-item ${activeTab === 'accounts' ? 'active' : ''}`}
                    onClick={() => handleTabClick('accounts')}
                  >
                    <Users size={15} />
                    <span>Quản lý tài khoản</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </nav>

      {/* Footer của Sidebar */}
      <div className="sidebar-footer">
        {/* Nút chuyển đổi thu gọn / phóng to Sidebar ở Footer */}
        {onToggleCollapse && (
          <button
            type="button"
            className="sidebar-collapse-action desktop-only"
            onClick={onToggleCollapse}
            title={isCollapsed ? 'Phóng to sidebar (Ctrl+B)' : 'Thu gọn sidebar (Ctrl+B)'}
            aria-label={isCollapsed ? 'Phóng to sidebar' : 'Thu gọn sidebar'}
          >
            {isCollapsed ? (
              <PanelLeftOpen size={18} />
            ) : (
              <>
                <PanelLeftClose size={17} />
                <span className="collapse-action-text">Thu gọn sidebar</span>
                <kbd className="sidebar-shortcut-hint">Ctrl+B</kbd>
              </>
            )}
          </button>
        )}

        {currentUser && (
          <div
            className="sidebar-user-panel"
            title={isCollapsed ? `${currentUser.fullName || currentUser.username} (${getRoleLabel(currentUser.role)})` : undefined}
          >
            <div className="user-avatar">
              {currentUser.fullName
                ? currentUser.fullName.charAt(0).toUpperCase()
                : currentUser.username.charAt(0).toUpperCase()}
            </div>
            <div className="user-details">
              <span className="user-name" title={currentUser.fullName || currentUser.username}>
                {currentUser.fullName || currentUser.username}
              </span>
              <span className="user-role">{getRoleLabel(currentUser.role)}</span>
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
      </div>
    </aside>
  );
};

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
  Terminal as TerminalIcon,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { hasPermission, getRoleLabel } from '../utils/permissions';
import { canAccessTab } from '../utils/tabPermissions';
import { UserProfileModal } from './UserProfileModal';

export type SidebarTab =
  | 'dashboard'
  | 'monthly'
  | 'daily'
  | 'devices'
  | 'updates'
  | 'banners'
  | 'orders'
  | 'customers'
  | 'warehouse'
  | 'locations'
  | 'accounts'
  | 'terminal';

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
  const showAccountsTab = useMemo(() => canAccessTab(currentUser, 'accounts') || canAccessTab(currentUser, 'terminal'), [currentUser]);
  const canViewCustomers = useMemo(() => hasPermission(currentUser, 'CUSTOMER_VIEW'), [currentUser]);

  // Xác định nhóm cha tương ứng với tab
  const getGroupByTab = (tab: SidebarTab): GroupKey | null => {
    if (tab === 'monthly' || tab === 'daily') return 'attendance';
    if (tab === 'devices' || tab === 'updates' || tab === 'banners') return 'device';
    if (tab === 'orders' || tab === 'customers' || tab === 'warehouse' || tab === 'locations') return 'business';
    if (tab === 'accounts' || tab === 'terminal') return 'accounts';
    return null;
  };

  // Quản lý trạng thái mở của nhóm cha (Accordion: chỉ 1 nhóm mở tại 1 thời điểm)
  const [openGroup, setOpenGroup] = useState<GroupKey | null>(() => getGroupByTab(activeTab));
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);

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
  const isBusinessActive = activeTab === 'orders' || activeTab === 'customers' || activeTab === 'warehouse' || activeTab === 'locations';
  const isAccountsActive = activeTab === 'accounts' || activeTab === 'terminal';

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
                style={{ display: canAccessTab(currentUser, 'dashboard') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'monthly') ? undefined : 'none' }}
              >
                <Calendar size={16} className="item-icon" />
                <span>Xem theo tháng</span>
              </button>
              <button
                className={`menu-item ${activeTab === 'daily' ? 'active' : ''}`}
                onClick={() => handleTabClick('daily')}
                style={{ display: canAccessTab(currentUser, 'daily') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'monthly') ? undefined : 'none' }}
                >
                  <Calendar size={15} />
                  <span>Xem theo tháng</span>
                </button>
                <button
                  className={`flyout-item ${activeTab === 'daily' ? 'active' : ''}`}
                  onClick={() => handleTabClick('daily')}
                style={{ display: canAccessTab(currentUser, 'daily') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'devices') ? undefined : 'none' }}
              >
                <Smartphone size={16} className="item-icon" />
                <span>Trạng thái thiết bị</span>
              </button>
              {canAccessTab(currentUser, 'updates') && (
                <button
                  className={`menu-item ${activeTab === 'updates' ? 'active' : ''}`}
                  onClick={() => handleTabClick('updates')}
                style={{ display: canAccessTab(currentUser, 'updates') ? undefined : 'none' }}
                >
                  <RefreshCw size={16} className="item-icon" />
                  <span>Cập nhật ứng dụng</span>
                </button>
              )}
              {canAccessTab(currentUser, 'banners') && (
                <button
                  className={`menu-item ${activeTab === 'banners' ? 'active' : ''}`}
                  onClick={() => handleTabClick('banners')}
                style={{ display: canAccessTab(currentUser, 'banners') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'devices') ? undefined : 'none' }}
                >
                  <Smartphone size={15} />
                  <span>Trạng thái thiết bị</span>
                </button>
                {canAccessTab(currentUser, 'updates') && (
                <button
                    className={`flyout-item ${activeTab === 'updates' ? 'active' : ''}`}
                    onClick={() => handleTabClick('updates')}
                style={{ display: canAccessTab(currentUser, 'updates') ? undefined : 'none' }}
                  >
                    <RefreshCw size={15} />
                    <span>Cập nhật ứng dụng</span>
                  </button>
                )}
                {canAccessTab(currentUser, 'banners') && (
                <button
                    className={`flyout-item ${activeTab === 'banners' ? 'active' : ''}`}
                    onClick={() => handleTabClick('banners')}
                style={{ display: canAccessTab(currentUser, 'banners') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'orders') ? undefined : 'none' }}
              >
                <ClipboardList size={16} className="item-icon" />
                <span>Đơn sửa chữa</span>
              </button>
              {canViewCustomers && (
                <button
                  className={`menu-item ${activeTab === 'customers' ? 'active' : ''}`}
                  onClick={() => handleTabClick('customers')}
                style={{ display: canAccessTab(currentUser, 'customers') ? undefined : 'none' }}
                >
                  <Users size={16} className="item-icon" />
                  <span>Khách hàng</span>
                </button>
              )}
              <button
                className={`menu-item ${activeTab === 'warehouse' ? 'active' : ''}`}
                onClick={() => handleTabClick('warehouse')}
                style={{ display: canAccessTab(currentUser, 'warehouse') ? undefined : 'none' }}
              >
                <Boxes size={16} className="item-icon" />
                <span>Kho bo mạch & Linh kiện</span>
              </button>
              <button
                className={`menu-item ${activeTab === 'locations' ? 'active' : ''}`}
                onClick={() => handleTabClick('locations')}
                style={{ display: canAccessTab(currentUser, 'locations') ? undefined : 'none' }}
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
                style={{ display: canAccessTab(currentUser, 'orders') ? undefined : 'none' }}
                >
                  <ClipboardList size={15} />
                  <span>Đơn sửa chữa</span>
                </button>
                {canViewCustomers && (
                  <button
                    className={`flyout-item ${activeTab === 'customers' ? 'active' : ''}`}
                    onClick={() => handleTabClick('customers')}
                style={{ display: canAccessTab(currentUser, 'customers') ? undefined : 'none' }}
                  >
                    <Users size={15} />
                    <span>Khách hàng</span>
                  </button>
                )}
                <button
                  className={`flyout-item ${activeTab === 'warehouse' ? 'active' : ''}`}
                  onClick={() => handleTabClick('warehouse')}
                style={{ display: canAccessTab(currentUser, 'warehouse') ? undefined : 'none' }}
                >
                  <Boxes size={15} />
                  <span>Kho bo mạch & Linh kiện</span>
                </button>
                <button
                  className={`flyout-item ${activeTab === 'locations' ? 'active' : ''}`}
                  onClick={() => handleTabClick('locations')}
                style={{ display: canAccessTab(currentUser, 'locations') ? undefined : 'none' }}
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
                {canAccessTab(currentUser, 'accounts') && (
                  <button
                    className={`menu-item ${activeTab === 'accounts' ? 'active' : ''}`}
                    onClick={() => handleTabClick('accounts')}
                  >
                    <Users size={16} className="item-icon" />
                    <span>Quản lý tài khoản</span>
                  </button>
                )}
                {canAccessTab(currentUser, 'terminal') && (
                  <button
                    className={`menu-item ${activeTab === 'terminal' ? 'active' : ''}`}
                    onClick={() => handleTabClick('terminal')}
                  >
                    <TerminalIcon size={16} className="item-icon" />
                    <span>Terminal & Hoạt động</span>
                  </button>
                )}
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
                  {canAccessTab(currentUser, 'accounts') && (
                    <button
                      className={`flyout-item ${activeTab === 'accounts' ? 'active' : ''}`}
                      onClick={() => handleTabClick('accounts')}
                    >
                      <Users size={15} />
                      <span>Quản lý tài khoản</span>
                    </button>
                  )}
                  {canAccessTab(currentUser, 'terminal') && (
                    <button
                      className={`flyout-item ${activeTab === 'terminal' ? 'active' : ''}`}
                      onClick={() => handleTabClick('terminal')}
                    >
                      <TerminalIcon size={15} />
                      <span>Terminal & Hoạt động</span>
                    </button>
                  )}
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
            title={isCollapsed ? `${currentUser.fullName || currentUser.username} (${getRoleLabel(currentUser.role)}) — Nhấp để xem hồ sơ` : undefined}
          >
            <div
              className="user-avatar"
              onClick={() => setIsProfileModalOpen(true)}
              title="Xem và chỉnh sửa ảnh đại diện / thông tin cá nhân"
            >
              {currentUser.avatarUrl ? (
                <img
                  src={currentUser.avatarUrl}
                  alt={currentUser.fullName || currentUser.username}
                  className="user-avatar-img"
                  onError={(e) => {
                    e.currentTarget.style.display = 'none';
                  }}
                />
              ) : null}
              <span>
                {currentUser.fullName
                  ? currentUser.fullName.charAt(0).toUpperCase()
                  : currentUser.username.charAt(0).toUpperCase()}
              </span>
            </div>
            <div
              className="user-details user-details-clickable"
              onClick={() => setIsProfileModalOpen(true)}
              title="Nhấp để xem và chỉnh sửa thông tin cá nhân"
            >
              <span className="user-name" title={currentUser.fullName || currentUser.username}>
                {currentUser.fullName || currentUser.username}
              </span>
              <span className="user-role">{getRoleLabel(currentUser.role)}</span>
            </div>
            <button
              className="sidebar-logout-btn"
              onClick={(e) => {
                e.stopPropagation();
                handleLogout();
              }}
              title="Đăng xuất"
              aria-label="Logout"
            >
              <LogOut size={16} />
            </button>
          </div>
        )}
      </div>

      {currentUser && (
        <UserProfileModal
          isOpen={isProfileModalOpen}
          onClose={() => setIsProfileModalOpen(false)}
          currentUser={currentUser}
        />
      )}
    </aside>
  );
};

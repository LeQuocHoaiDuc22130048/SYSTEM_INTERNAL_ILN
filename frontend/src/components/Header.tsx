import React from 'react';
import {
  WifiOff,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  ChevronDown,
  Calendar,
  Clock,
  Menu,
  X,
  Sun,
  Moon,
  Zap,
  CalendarDays,
  CalendarRange,
  SlidersHorizontal,
} from 'lucide-react';
import { NotificationBell } from './NotificationBell';
import type { UserInfo } from '../mockData';
import type { ResolvedTheme } from '../utils/theme';
import type { TimeRangePreset } from './dashboardUtils';
import './Header.css';

interface HeaderProps {
  activeTab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'banners' | 'orders' | 'customers' | 'warehouse' | 'locations' | 'accounts' | 'terminal' | 'media-cleanup';
  currentMonth: number;
  currentYear: number;
  prevMonth: () => void;
  nextMonth: () => void;
  selectedDate: string;
  handleDateChange: (dateStr: string) => void;
  dataSource: 'api' | 'error' | 'loading';
  connectionError: string | null;
  handleRetryConnection: () => void;
  onToggleSidebar?: () => void;
  isSidebarOpen?: boolean;
  onRefreshData?: () => void;
  isRefreshing?: boolean;
  currentUser?: UserInfo | null;
  showToast?: (message: string) => void;
  onNavigateToTab?: (tab: any) => void;
  theme?: ResolvedTheme;
  onToggleTheme?: () => void;
  dashboardRangeType?: TimeRangePreset;
  onDashboardRangeChange?: (range: TimeRangePreset) => void;
}

export const Header: React.FC<HeaderProps> = ({
  activeTab,
  currentMonth,
  currentYear,
  prevMonth,
  nextMonth,
  selectedDate,
  handleDateChange,
  dataSource,
  connectionError,
  handleRetryConnection,
  onToggleSidebar,
  isSidebarOpen = false,
  onRefreshData,
  isRefreshing = false,
  currentUser,
  showToast,
  onNavigateToTab,
  theme = 'light',
  onToggleTheme,
  dashboardRangeType,
  onDashboardRangeChange,
}) => {
  // Định dạng ngày tháng tiếng Việt cho Header
  const getVietnameseDate = (): string => {
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

  return (
    <>
      {/* Banner cảnh báo ngắt kết nối */}
      {dataSource === 'error' && (
        <div className="connection-banner error">
          <div className="banner-content">
            <WifiOff size={20} className="banner-icon" />
            <div className="banner-text">
              <strong>Mất kết nối máy chủ!</strong>
              <span>
                {connectionError || 'Không thể kết nối đến Backend. Vui lòng kiểm tra lại dịch vụ.'}
              </span>
            </div>
          </div>
          <button className="banner-retry-btn" onClick={handleRetryConnection}>
            <RefreshCw size={16} />
            Thử lại
          </button>
        </div>
      )}

      <header className="header">
        <div className="header-left">
          {onToggleSidebar && (
            <button
              type="button"
              className="sidebar-toggle-btn mobile-only"
              onClick={onToggleSidebar}
              title={isSidebarOpen ? 'Ẩn thanh điều hướng' : 'Mở thanh điều hướng'}
              aria-label={isSidebarOpen ? 'Ẩn thanh điều hướng' : 'Mở thanh điều hướng'}
            >
              {isSidebarOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
          )}
          <div className="header-title-box">
            <h1 className="title">
              {activeTab === 'dashboard'
                ? 'Dashboard tổng hợp'
                : activeTab === 'monthly'
                ? 'Chấm công theo tháng'
                : activeTab === 'daily'
                ? 'Chấm công theo ngày'
                : activeTab === 'devices'
                ? 'Trạng thái Thiết bị'
                : activeTab === 'updates'
                ? 'Cập nhật ứng dụng'
                : activeTab === 'banners'
                ? 'Banner ứng dụng'
                : activeTab === 'orders'
                ? 'Quản lý đơn sửa chữa'
                : activeTab === 'customers'
                ? 'Hồ sơ khách hàng'
                : activeTab === 'locations'
                ? 'Vị trí & Kệ kho'
                : activeTab === 'accounts'
                ? 'Quản lý tài khoản'
                : activeTab === 'terminal'
                ? 'Quản trị Terminal & Hoạt động'
                : activeTab === 'media-cleanup'
                ? 'Media Cleanup Engine (S3 & PostgreSQL)'
                : 'Kho bo mạch & Linh kiện'}
            </h1>
            <span className="header-date">
              <Calendar size={13} className="header-date-icon" />
              <span>{getVietnameseDate()}</span>
            </span>
          </div>
        </div>

        <div className="header-right">
          {activeTab === 'monthly' ? (
            <div className="month-navigator">
              <button id="btn-prev-month" className="nav-btn" onClick={prevMonth}>
                <ChevronLeft size={18} />
              </button>
              <span className="month-display">Tháng {currentMonth} / {currentYear}</span>
              <button id="btn-next-month" className="nav-btn" onClick={nextMonth}>
                <ChevronRight size={18} />
              </button>
            </div>
          ) : activeTab === 'daily' ? (
            <div className="month-navigator date-picker-wrapper">
              <Calendar size={18} className="date-picker-icon" />
              <input
                id="header-date-picker"
                type="date"
                className="date-picker-input"
                value={selectedDate}
                onChange={(e) => handleDateChange(e.target.value)}
              />
            </div>
          ) : activeTab === 'dashboard' && dashboardRangeType && onDashboardRangeChange ? (
            <div className="header-dashboard-filters">
              {/* Desktop: thanh tab chọn nhanh */}
              <div className="header-preset-buttons" role="tablist" aria-label="Bộ lọc thời gian">
                <button
                  type="button"
                  role="tab"
                  aria-selected={dashboardRangeType === 'today'}
                  className={`header-preset-btn ${dashboardRangeType === 'today' ? 'active' : ''}`}
                  onClick={() => onDashboardRangeChange('today')}
                >
                  <Zap size={13} aria-hidden="true" />
                  <span>Hôm nay</span>
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={dashboardRangeType === '7days'}
                  className={`header-preset-btn ${dashboardRangeType === '7days' ? 'active' : ''}`}
                  onClick={() => onDashboardRangeChange('7days')}
                >
                  <CalendarDays size={13} aria-hidden="true" />
                  <span>7 ngày qua</span>
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={dashboardRangeType === 'month'}
                  className={`header-preset-btn ${dashboardRangeType === 'month' ? 'active' : ''}`}
                  onClick={() => onDashboardRangeChange('month')}
                >
                  <CalendarRange size={13} aria-hidden="true" />
                  <span>Tháng này</span>
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={dashboardRangeType === 'custom'}
                  className={`header-preset-btn ${dashboardRangeType === 'custom' ? 'active' : ''}`}
                  onClick={() => onDashboardRangeChange('custom')}
                >
                  <SlidersHorizontal size={13} aria-hidden="true" />
                  <span>Tùy chỉnh</span>
                </button>
              </div>

              {/* Mobile: Dropdown chọn nhanh gọn gàng */}
              <div className="header-mobile-filter-row">
                <span className="header-mobile-filter-label">
                  <Clock size={13} aria-hidden="true" />
                  <span>Khoảng thời gian</span>
                </span>
                <div className="header-mobile-select-wrap">
                  <Calendar size={13} className="header-mobile-select-icon" aria-hidden="true" />
                  <select
                    className="header-mobile-select"
                    aria-label="Chọn khoảng thời gian"
                    value={dashboardRangeType}
                    onChange={(e) => onDashboardRangeChange(e.target.value as TimeRangePreset)}
                  >
                    <option value="today">Hôm nay</option>
                    <option value="7days">7 ngày qua</option>
                    <option value="month">Tháng này</option>
                    <option value="custom">Tùy chỉnh</option>
                  </select>
                  <ChevronDown size={14} className="header-mobile-select-chevron" aria-hidden="true" />
                </div>
              </div>
            </div>
          ) : null}

          <div className="header-actions">
            {/* Chuyển giao diện Sáng / Tối */}
            {onToggleTheme && (
              <button
                type="button"
                className="btn-theme-toggle"
                onClick={onToggleTheme}
                title={theme === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối'}
                aria-label={theme === 'dark' ? 'Chuyển sang giao diện sáng' : 'Chuyển sang giao diện tối'}
              >
                {theme === 'dark' ? <Sun size={17} /> : <Moon size={17} />}
              </button>
            )}

            {/* Chuông thông báo hệ thống & cảnh báo thiết bị */}
            <NotificationBell
              currentUser={currentUser}
              showToast={showToast}
              onNavigateToTab={onNavigateToTab}
            />

            {/* Nút Làm mới dữ liệu đưa lên Header */}
            {onRefreshData && (
              <button
                type="button"
                className="btn-header-refresh"
                onClick={onRefreshData}
                disabled={isRefreshing}
                title="Làm mới dữ liệu"
              >
                <RefreshCw size={15} className={isRefreshing ? 'spin' : ''} />
                <span>Làm mới dữ liệu</span>
              </button>
            )}
          </div>
        </div>
      </header>
    </>
  );
};

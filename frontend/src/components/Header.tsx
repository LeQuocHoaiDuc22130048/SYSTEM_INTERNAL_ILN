import React from 'react';
import {
  WifiOff,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Calendar,
  Menu,
  X,
} from 'lucide-react';

interface HeaderProps {
  activeTab: 'dashboard' | 'monthly' | 'daily' | 'devices' | 'updates' | 'banners' | 'orders' | 'warehouse' | 'locations' | 'accounts';
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
                : activeTab === 'locations'
                ? 'Vị trí & Kệ kho'
                : activeTab === 'accounts'
                ? 'Quản lý tài khoản'
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
          ) : null}

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
      </header>
    </>
  );
};

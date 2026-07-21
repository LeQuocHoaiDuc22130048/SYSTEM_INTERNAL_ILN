import React from 'react';
import {
  WifiOff,
  RefreshCw,
  Wifi,
  ChevronLeft,
  ChevronRight,
  Calendar,
  Menu,
} from 'lucide-react';

interface HeaderProps {
  activeTab: 'monthly' | 'daily' | 'devices' | 'updates' | 'orders' | 'warehouse' | 'accounts';
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
}) => {

  return (
    <>
      {dataSource === 'error' && (
        <div className="connection-banner warning">
          <div className="banner-content">
            <WifiOff size={18} className="banner-icon--error" />
            <div className="banner-text">
              <strong className="banner-text--error">Lỗi kết nối Backend</strong>
              <span>
                {connectionError || 'Không thể kết nối'}
              </span>
            </div>
          </div>
          <button className="banner-retry-btn" onClick={handleRetryConnection}>
            <RefreshCw size={16} />
            Thử lại
          </button>
        </div>
      )}

      {/* Connection success banner removed as requested */}

      <header className="header">
        <div className="header-left">
          {onToggleSidebar && (
            <button className="sidebar-toggle-btn" onClick={onToggleSidebar} aria-label="Toggle sidebar">
              <Menu size={20} />
            </button>
          )}
          <h1 className="title">
            {activeTab === 'monthly'
              ? 'Chấm công theo tháng'
              : activeTab === 'daily'
              ? 'Chấm công theo ngày'
              : activeTab === 'devices'
              ? 'Trạng thái Thiết bị'
              : activeTab === 'updates'
              ? 'Cập nhật ứng dụng'
              : activeTab === 'orders'
              ? 'Quản lý đơn sửa chữa'
              : activeTab === 'accounts'
              ? 'Quản lý tài khoản'
              : 'Kho bo mạch'}
          </h1>
        </div>

        <div className="header-right">
          <div className="connection-indicator">
            {dataSource === 'api' ? (
              <span className="conn-badge connected"><Wifi size={14} /> API Connected</span>
            ) : dataSource === 'error' ? (
              <span
                className="conn-badge disconnected"
                onClick={handleRetryConnection}
                title="Click để thử kết nối lại"
              >
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
          ) : activeTab === 'devices' ? (
            <div className="month-navigator real-time-indicator">
              <span className="real-time-dot" />
              <span className="real-time-text">Thời gian thực</span>
            </div>
          ) : activeTab === 'updates' ? (
            <div className="month-navigator real-time-indicator" style={{ background: '#f5f3ff', border: '1px solid #ddd6fe' }}>
              <span className="real-time-dot" style={{ backgroundColor: '#8b5cf6', boxShadow: '0 0 0 0.15rem rgba(139, 92, 246, 0.4)' }} />
              <span className="real-time-text" style={{ color: '#6d28d9' }}>Phát hành phiên bản</span>
            </div>
          ) : activeTab === 'orders' ? (
            <div className="month-navigator real-time-indicator" style={{ background: '#ecfdf5', border: '1px solid #a7f3d0' }}>
              <span className="real-time-dot" style={{ backgroundColor: '#10b981', boxShadow: '0 0 0 0.15rem rgba(16, 185, 129, 0.4)' }} />
              <span className="real-time-text" style={{ color: '#047857' }}>Hệ thống sửa chữa</span>
            </div>
          ) : activeTab === 'accounts' ? (
            <div className="month-navigator real-time-indicator" style={{ background: '#eff6ff', border: '1px solid #bfdbfe' }}>
              <span className="real-time-dot" style={{ backgroundColor: '#3b82f6', boxShadow: '0 0 0 0.15rem rgba(59, 130, 246, 0.4)' }} />
              <span className="real-time-text" style={{ color: '#1d4ed8' }}>Quản lý tài khoản</span>
            </div>
          ) : (
            <div className="month-navigator real-time-indicator" style={{ background: '#fff7ed', border: '1px solid #ffedd5' }}>
              <span className="real-time-dot" style={{ backgroundColor: '#f97316', boxShadow: '0 0 0 0.15rem rgba(249, 115, 22, 0.4)' }} />
              <span className="real-time-text" style={{ color: '#c2410c' }}>Quản lý linh kiện</span>
            </div>
          )}
        </div>
      </header>
    </>
  );
};

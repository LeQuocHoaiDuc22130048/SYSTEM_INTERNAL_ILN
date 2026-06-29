import React from 'react';
import {
  WifiOff,
  RefreshCw,
  Database,
  Wifi,
  ChevronLeft,
  ChevronRight,
  Calendar,
  LogOut,
} from 'lucide-react';
import type { UserInfo } from '../mockData';

interface HeaderProps {
  activeTab: 'monthly' | 'daily';
  setActiveTab: (tab: 'monthly' | 'daily') => void;
  currentMonth: number;
  currentYear: number;
  prevMonth: () => void;
  nextMonth: () => void;
  selectedDate: string;
  handleDateChange: (dateStr: string) => void;
  dataSource: 'api' | 'error' | 'loading';
  connectionError: string | null;
  handleRetryConnection: () => void;
  currentUser: UserInfo | null;
  handleLogout: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  activeTab,
  setActiveTab,
  currentMonth,
  currentYear,
  prevMonth,
  nextMonth,
  selectedDate,
  handleDateChange,
  dataSource,
  connectionError,
  handleRetryConnection,
  currentUser,
  handleLogout,
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

      {dataSource === 'api' && (
        <div className="connection-banner success">
          <div className="banner-content">
            <Database size={18} />
            <div className="banner-text">
              <strong>Đã kết nối</strong>
            </div>
          </div>
          <div className="banner-status-dot connected" />
        </div>
      )}

      <header className="header">
        <div className="header-left">
          <h1 className="title">Quản lý Chấm công</h1>
          <div className="tab-buttons">
            <button
              id="tab-monthly"
              className={`tab-btn ${activeTab === 'monthly' ? 'active' : ''}`}
              onClick={() => setActiveTab('monthly')}
            >
              Xem theo tháng
            </button>
            <button
              id="tab-daily"
              className={`tab-btn ${activeTab === 'daily' ? 'active' : ''}`}
              onClick={() => setActiveTab('daily')}
            >
              Xem theo ngày
            </button>
          </div>
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
          ) : (
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
          )}

          {currentUser && (
            <button id="btn-logout" className="login-header-logout" onClick={handleLogout} title="Đăng xuất">
              <LogOut size={16} />
              <span>{currentUser.fullName || currentUser.username}</span>
            </button>
          )}
        </div>
      </header>
    </>
  );
};

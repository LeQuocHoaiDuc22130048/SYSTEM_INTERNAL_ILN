import React from 'react';
import { 
  WifiOff, 
  RefreshCw, 
  Database, 
  Wifi, 
  ChevronLeft, 
  ChevronRight, 
  Calendar, 
  LogOut 
} from 'lucide-react';

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
  currentUser: any;
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
      {/* Connection Status Banner */}
      {dataSource === 'error' && (
        <div className="connection-banner warning">
          <div className="banner-content">
            <WifiOff size={18} style={{ color: '#ef4444' }} />
            <div className="banner-text">
              <strong style={{ color: '#ef4444' }}>Lỗi kết nối Backend</strong>
              <span>{connectionError || 'Không thể kết nối đến backend API. Vui lòng kiểm tra Docker và backend đang chạy.'}</span>
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
              <strong>Đã kết nối Database</strong>
              <span>Dữ liệu được tải trực tiếp từ PostgreSQL qua API backend</span>
            </div>
          </div>
          <div className="banner-status-dot connected"></div>
        </div>
      )}

      {/* Header section */}
      <header className="header">
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <h1 className="title" style={{ fontSize: '22px', fontWeight: 'bold' }}>Quản lý Chấm công</h1>
          <div className="tab-buttons" style={{ display: 'flex', gap: '8px', background: '#f1f5f9', padding: '4px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
            <button 
              id="tab-monthly"
              className={`tab-btn ${activeTab === 'monthly' ? 'active' : ''}`}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '13px',
                background: activeTab === 'monthly' ? '#ffffff' : 'transparent',
                color: activeTab === 'monthly' ? 'var(--color-primary)' : 'var(--color-text-light)',
                boxShadow: activeTab === 'monthly' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.2s'
              }}
              onClick={() => setActiveTab('monthly')}
            >
              Xem theo tháng
            </button>
            <button 
              id="tab-daily"
              className={`tab-btn ${activeTab === 'daily' ? 'active' : ''}`}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                cursor: 'pointer',
                fontWeight: 600,
                fontSize: '13px',
                background: activeTab === 'daily' ? '#ffffff' : 'transparent',
                color: activeTab === 'daily' ? 'var(--color-primary)' : 'var(--color-text-light)',
                boxShadow: activeTab === 'daily' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.2s'
              }}
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
              <span className="conn-badge disconnected" onClick={handleRetryConnection} title="Click để thử kết nối lại">
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
              <span className="month-display">
                Tháng {currentMonth} / {currentYear}
              </span>
              <button id="btn-next-month" className="nav-btn" onClick={nextMonth}>
                <ChevronRight size={18} />
              </button>
            </div>
          ) : (
            <div className="month-navigator" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Calendar size={18} style={{ color: 'var(--color-text-light)' }} />
              <input 
                id="header-date-picker"
                type="date" 
                value={selectedDate}
                onChange={(e) => handleDateChange(e.target.value)}
                style={{
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  padding: '6px 10px',
                  fontSize: '13px',
                  fontWeight: 600,
                  color: 'var(--color-text-dark)',
                  outline: 'none',
                  fontFamily: 'inherit'
                }}
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

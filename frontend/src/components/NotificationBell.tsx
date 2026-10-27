import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Bell,
  WifiOff,
  Wifi,
  CheckCheck,
  AlertCircle,
  Info,
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import './NotificationBell.css';

export interface SystemNotification {
  id: string;
  recipientId: string;
  type: string;
  title: string;
  body: string;
  refType?: string;
  refId?: string;
  isRead: boolean;
  createdAt: string;
}

interface NotificationBellProps {
  currentUser?: UserInfo | null;
  showToast?: (message: string) => void;
  onNavigateToTab?: (tab: string) => void;
}

function playAlertChime() {
  try {
    const AudioCtx = window.AudioContext || (window as any).webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.type = 'sine';
    osc.frequency.setValueAtTime(880, ctx.currentTime);
    osc.frequency.setValueAtTime(440, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.25, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.45);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.45);
  } catch {
    // Audio context may not be allowed prior to user gesture
  }
}

function formatRelativeTime(dateStr?: string): string {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  const now = new Date();
  const diffSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (diffSeconds < 60) return 'Vừa xong';
  const diffMinutes = Math.floor(diffSeconds / 60);
  if (diffMinutes < 60) return `${diffMinutes} phút trước`;
  const diffHours = Math.floor(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours} giờ trước`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays} ngày trước`;
}

export const NotificationBell: React.FC<NotificationBellProps> = ({
  currentUser,
  showToast,
  onNavigateToTab,
}) => {
  const [unreadCount, setUnreadCount] = useState<number>(0);
  const [notifications, setNotifications] = useState<SystemNotification[]>([]);
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const [loading, setLoading] = useState<boolean>(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const seenAlertIdsRef = useRef<Set<string>>(new Set());

  // Không hiển thị cho tài khoản khách hàng cá nhân
  if (currentUser?.role === 'CUSTOMER') {
    return null;
  }

  // Lấy số lượng thông báo chưa đọc
  const fetchUnreadCount = useCallback(async () => {
    try {
      const res = await fetch('/api/v1/notifications/unread-count', {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        const count = data?.data?.unreadCount ?? 0;
        setUnreadCount(count);
      }
    } catch {
      // Bỏ qua lỗi mạng nền
    }
  }, []);

  // Lấy danh sách thông báo chi tiết
  const fetchNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/v1/notifications?size=15', {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const data = await res.json();
        const items: SystemNotification[] = data?.data?.content ?? [];
        setNotifications(items);

        // Kiểm tra xem có thông báo mất kết nối máy chấm công mới chưa đọc không
        for (const item of items) {
          if (!item.isRead && item.type === 'ATTENDANCE_DEVICE_DISCONNECTED') {
            if (!seenAlertIdsRef.current.has(item.id)) {
              seenAlertIdsRef.current.add(item.id);
              playAlertChime();
              showToast?.(`⚠️ CẢNH BÁO: ${item.title} - ${item.body}`);

              // Hiển thị Desktop browser notification nếu được cấp quyền
              if ('Notification' in window && Notification.permission === 'granted') {
                new Notification(item.title, {
                  body: item.body,
                  icon: '/favicon.ico',
                });
              }
            }
          }
        }
      }
    } catch (e) {
      console.error('Lỗi khi tải thông báo:', e);
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  // Yêu cầu quyền thông báo của trình duyệt khi mở chuông
  const handleToggle = () => {
    if (!isOpen) {
      if ('Notification' in window && Notification.permission === 'default') {
        Notification.requestPermission().catch(() => {});
      }
      fetchNotifications();
    }
    setIsOpen(prev => !prev);
  };

  // Đánh dấu 1 thông báo là đã đọc
  const handleMarkAsRead = async (item: SystemNotification) => {
    if (!item.isRead) {
      try {
        await fetch(`/api/v1/notifications/${item.id}/read`, {
          method: 'PUT',
          headers: getAuthHeaders(),
        });
        setNotifications(prev =>
          prev.map(n => (n.id === item.id ? { ...n, isRead: true } : n))
        );
        setUnreadCount(prev => Math.max(0, prev - 1));
      } catch {
        // Bỏ qua
      }
    }

    if (item.type.startsWith('ATTENDANCE_') || item.refType === 'ATTENDANCE_TABLET') {
      onNavigateToTab?.('devices');
      setIsOpen(false);
    }
  };

  // Đánh dấu tất cả đã đọc
  const handleMarkAllRead = async () => {
    try {
      await fetch('/api/v1/notifications/read-all', {
        method: 'PUT',
        headers: getAuthHeaders(),
      });
      setNotifications(prev => prev.map(n => ({ ...n, isRead: true })));
      setUnreadCount(0);
      showToast?.('Đã đánh dấu tất cả thông báo là đã đọc.');
    } catch {
      showToast?.('Không thể cập nhật trạng thái thông báo.');
    }
  };

  // Tự động đóng dropdown khi click ra ngoài
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, [isOpen]);

  // Quét chu kỳ mỗi 15 giây
  useEffect(() => {
    fetchUnreadCount();
    fetchNotifications();

    const timer = setInterval(() => {
      if (document.visibilityState !== 'hidden') {
        fetchUnreadCount();
        fetchNotifications();
      }
    }, 15000);

    const handleFocus = () => {
      fetchUnreadCount();
      fetchNotifications();
    };

    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', handleFocus);
    };
  }, [fetchUnreadCount, fetchNotifications]);

  const getVisual = (type: string) => {
    if (type === 'ATTENDANCE_DEVICE_DISCONNECTED') {
      return {
        icon: <WifiOff size={16} />,
        className: 'critical',
      };
    }
    if (type === 'ATTENDANCE_DEVICE_RECONNECTED') {
      return {
        icon: <Wifi size={16} />,
        className: 'success',
      };
    }
    if (type.includes('ALERT') || type.includes('OVERDUE')) {
      return {
        icon: <AlertCircle size={16} />,
        className: 'critical',
      };
    }
    return {
      icon: <Info size={16} />,
      className: 'info',
    };
  };

  return (
    <div className="notif-bell-container" ref={containerRef}>
      <button
        type="button"
        className="notif-bell-btn"
        onClick={handleToggle}
        title="Thông báo hệ thống"
        aria-label="Thông báo hệ thống"
      >
        <Bell size={18} />
        {unreadCount > 0 && (
          <span className="notif-badge">
            {unreadCount > 9 ? '9+' : unreadCount}
          </span>
        )}
      </button>

      {isOpen && (
        <div className="notif-dropdown">
          <div className="notif-dropdown-header">
            <div className="notif-header-title">
              <span>Thông báo</span>
              {unreadCount > 0 && (
                <span className="notif-unread-tag">{unreadCount} mới</span>
              )}
            </div>
            {unreadCount > 0 && (
              <button
                type="button"
                className="notif-mark-all-btn"
                onClick={handleMarkAllRead}
              >
                <CheckCheck size={14} />
                Đọc tất cả
              </button>
            )}
          </div>

          <div className="notif-list">
            {loading && notifications.length === 0 ? (
              <div className="notif-empty">Đang tải thông báo...</div>
            ) : notifications.length === 0 ? (
              <div className="notif-empty">
                <Bell size={28} style={{ opacity: 0.3 }} />
                <span>Không có thông báo nào</span>
              </div>
            ) : (
              notifications.map(item => {
                const visual = getVisual(item.type);
                return (
                  <div
                    key={item.id}
                    className={`notif-item ${item.isRead ? '' : 'unread'} ${visual.className}`}
                    onClick={() => handleMarkAsRead(item)}
                  >
                    <div className={`notif-icon-box ${visual.className}`}>
                      {visual.icon}
                    </div>
                    <div className="notif-content">
                      <div className="notif-title">
                        <span>{item.title}</span>
                        {!item.isRead && <span className="notif-unread-dot" />}
                      </div>
                      <div className="notif-body">{item.body}</div>
                      <div className="notif-time">
                        {formatRelativeTime(item.createdAt)}
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}
    </div>
  );
};

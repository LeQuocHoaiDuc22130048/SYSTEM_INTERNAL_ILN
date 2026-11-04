import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Sparkles, RefreshCw, X, ArrowRight } from 'lucide-react';
import './WebUpdateBanner.css';

interface WebVersionData {
  latestVersion: string;
  changelog?: string;
  mandatory?: boolean;
}

export const WebUpdateBanner: React.FC = () => {
  const [newVersion, setNewVersion] = useState<WebVersionData | null>(null);
  const [isDismissed, setIsDismissed] = useState<boolean>(false);
  const initialVersionRef = useRef<string | null>(null);
  const checkTimerRef = useRef<number | null>(null);

  const checkWebUpdate = useCallback(async () => {
    try {
      const response = await fetch('/api/v1/app-updates/web-version', {
        headers: { 'Accept': 'application/json' },
        cache: 'no-cache'
      });

      if (!response.ok) return;

      const result = await response.json();
      const data: WebVersionData | undefined = result?.data;
      if (!data?.latestVersion) return;

      const remoteVersion = data.latestVersion.trim();

      // Lưu lại phiên bản ban đầu khi ứng dụng vừa khởi tạo
      if (!initialVersionRef.current) {
        initialVersionRef.current = remoteVersion;
        return;
      }

      // Nếu máy chủ trả về phiên bản khác phiên bản lúc load trang
      if (remoteVersion !== initialVersionRef.current) {
        setNewVersion(data);
      }
    } catch {
      // Yên lặng bỏ qua lỗi mạng / offline
    }
  }, []);

  useEffect(() => {
    // Kiểm tra ngay khi mount
    checkWebUpdate();

    // Định kỳ kiểm tra mỗi 3 phút (180,000ms)
    checkTimerRef.current = window.setInterval(checkWebUpdate, 180000);

    // Kiểm tra thêm mỗi khi người dùng chuyển lại tab
    const handleFocus = () => {
      if (document.visibilityState === 'visible') {
        checkWebUpdate();
      }
    };
    window.addEventListener('focus', handleFocus);
    document.addEventListener('visibilitychange', handleFocus);

    return () => {
      if (checkTimerRef.current) clearInterval(checkTimerRef.current);
      window.removeEventListener('focus', handleFocus);
      document.removeEventListener('visibilitychange', handleFocus);
    };
  }, [checkWebUpdate]);

  if (!newVersion || isDismissed) {
    return null;
  }

  const handleReload = () => {
    // Tải lại trang và bỏ qua cache
    window.location.reload();
  };

  const handleDismiss = () => {
    setIsDismissed(true);
    // Tự động nhắc lại sau 15 phút nếu người dùng chưa tải lại
    setTimeout(() => {
      setIsDismissed(false);
    }, 15 * 60 * 1000);
  };

  return (
    <aside className="web-update-banner-container" aria-live="polite" role="status">
      <div className="web-update-banner-card">
        <div className="web-update-banner-left">
          <div className="web-update-icon-wrapper">
            <Sparkles size={18} className="web-update-sparkle-icon" />
          </div>
          <div className="web-update-text-content">
            <div className="web-update-title-row">
              <span className="web-update-badge">Cập nhật Web</span>
              <strong className="web-update-title">Phiên bản mới v{newVersion.latestVersion}</strong>
            </div>
            <p className="web-update-desc">
              {newVersion.changelog?.trim()
                ? newVersion.changelog.split('\n')[0]
                : 'Hệ thống đã có bản cập nhật giao diện mới. Vui lòng tải lại trang để áp dụng các sửa đổi và tính năng mới.'}
            </p>
          </div>
        </div>

        <div className="web-update-banner-actions">
          <button
            type="button"
            className="web-update-reload-btn"
            onClick={handleReload}
            title="Tải lại trang web để áp dụng ngay"
          >
            <RefreshCw size={14} className="reload-icon" />
            <span>Tải lại trang</span>
            <ArrowRight size={13} className="arrow-icon" />
          </button>

          {!newVersion.mandatory && (
            <button
              type="button"
              className="web-update-dismiss-btn"
              onClick={handleDismiss}
              title="Đóng thông báo (sẽ nhắc lại sau)"
              aria-label="Đóng thông báo cập nhật"
            >
              <X size={16} />
            </button>
          )}
        </div>
      </div>
    </aside>
  );
};


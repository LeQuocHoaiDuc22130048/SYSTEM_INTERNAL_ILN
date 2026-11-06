import React, { useState, useEffect } from 'react';
import { PhoneCall, MessageSquare, Clock, MapPin, X, Save, AlertCircle, Navigation, Globe } from 'lucide-react';
import {
  getPortalSupportConfig,
  updatePortalSupportConfig,
  type PortalSupportConfig,
} from '../utils/portalConfigApi';
import './PortalSupportConfigModal.css';

interface PortalSupportConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  showToast: (msg: string) => void;
}

export const PortalSupportConfigModal: React.FC<PortalSupportConfigModalProps> = ({
  isOpen,
  onClose,
  showToast,
}) => {
  const [loading, setLoading] = useState<boolean>(true);
  const [saving, setSaving] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const [hotlineNumber, setHotlineNumber] = useState<string>('0964 266 771');
  const [hotlineLabel, setHotlineLabel] = useState<string>('Liên hệ kỹ thuật');
  const [zaloUrl, setZaloUrl] = useState<string>('https://zalo.me');
  const [zaloLabel, setZaloLabel] = useState<string>('Chat Zalo Tiếp Nhận');
  const [workingHours, setWorkingHours] = useState<string>('08:00 - 17:30 (Thứ 2 - Thứ 7)');
  const [workshopAddress, setWorkshopAddress] = useState<string>(
    '243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh, Việt Nam'
  );
  const [mapUrl, setMapUrl] = useState<string>(
    'https://www.google.com/maps/search/?api=1&query=243+Quốc+Lộ+1A,+Tam+Bình,+TP+Hồ+Chí+Minh'
  );
  const [latitude, setLatitude] = useState<string>('10.854611');
  const [longitude, setLongitude] = useState<string>('106.703212');
  const [mapImageUrl, setMapImageUrl] = useState<string>('');

  useEffect(() => {
    if (!isOpen) return;
    setLoading(true);
    setErrorMsg(null);
    getPortalSupportConfig()
      .then((cfg: PortalSupportConfig) => {
        if (cfg) {
          setHotlineNumber(cfg.hotlineNumber || '0964 266 771');
          setHotlineLabel(cfg.hotlineLabel || 'Liên hệ kỹ thuật');
          setZaloUrl(cfg.zaloUrl || '');
          setZaloLabel(cfg.zaloLabel || '');
          setWorkingHours(cfg.workingHours || '');
          setWorkshopAddress(cfg.workshopAddress || '');
          setMapUrl(cfg.mapUrl || '');
          setLatitude(cfg.latitude !== undefined && cfg.latitude !== null ? String(cfg.latitude) : '10.854611');
          setLongitude(cfg.longitude !== undefined && cfg.longitude !== null ? String(cfg.longitude) : '106.703212');
          setMapImageUrl(cfg.mapImageUrl || '');
        }
      })
      .catch((err) => {
        setErrorMsg(err.message || 'Lỗi khi tải cấu hình');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!hotlineNumber.trim()) {
      setErrorMsg('Vui lòng nhập Số điện thoại liên hệ.');
      return;
    }

    setSaving(true);
    setErrorMsg(null);
    try {
      await updatePortalSupportConfig({
        hotlineNumber: hotlineNumber.trim(),
        hotlineLabel: hotlineLabel.trim(),
        zaloUrl: zaloUrl.trim(),
        zaloLabel: zaloLabel.trim(),
        workingHours: workingHours.trim(),
        workshopAddress: workshopAddress.trim(),
        mapUrl: mapUrl.trim(),
        latitude: latitude ? parseFloat(latitude) : undefined,
        longitude: longitude ? parseFloat(longitude) : undefined,
        mapImageUrl: mapImageUrl.trim(),
      });
      showToast('Cập nhật kênh hỗ trợ Cổng Khách Hàng thành công!');
      onClose();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Lỗi khi lưu cấu hình';
      setErrorMsg(msg);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="portal-config-modal-backdrop">
      <div className="portal-config-modal-card">
        <div className="portal-config-modal-header">
          <div className="header-title-wrap">
            <div className="header-icon-circle">
              <PhoneCall size={20} className="header-icon" />
            </div>
            <div>
              <h3>Quản lý Kênh Hỗ Trợ Khách Hàng</h3>
              <p className="header-sub">
                Tùy chỉnh số Hotline và đường dẫn Zalo OA hiển thị trên App Mobile & Web Portal
              </p>
            </div>
          </div>
          <button type="button" className="btn-close-modal" onClick={onClose} disabled={saving}>
            <X size={18} />
          </button>
        </div>

        {errorMsg && (
          <div className="portal-config-alert-error">
            <AlertCircle size={16} />
            <span>{errorMsg}</span>
          </div>
        )}

        {loading ? (
          <div className="portal-config-loading">Đang tải cấu hình hiện tại...</div>
        ) : (
          <form onSubmit={handleSubmit}>
            <div className="portal-config-modal-body">
              <div className="config-section-title">
                <PhoneCall size={16} />
                <span>Kênh Hotline Tiếp Nhận</span>
              </div>
              <div className="form-row-2">
                <div className="form-group">
                  <label>
                    Số điện thoại Hotline <span className="required">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="VD: 0909123456"
                    value={hotlineNumber}
                    onChange={(e) => setHotlineNumber(e.target.value)}
                  />
                  <span className="field-hint">Khi khách hàng bấm gọi, app sẽ quay số này</span>
                </div>
                <div className="form-group">
                  <label>Tên hiển thị nút Hotline</label>
                  <input
                    type="text"
                    placeholder="VD: Hotline Kỹ Thuật"
                    value={hotlineLabel}
                    onChange={(e) => setHotlineLabel(e.target.value)}
                  />
                </div>
              </div>

              <div className="config-section-title" style={{ marginTop: 14 }}>
                <MessageSquare size={16} />
                <span>Kênh Zalo Tư Vấn & Báo Giá</span>
              </div>
              <div className="form-row-2">
                <div className="form-group">
                  <label>
                    Link Zalo / Zalo OA <span className="required">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="VD: https://zalo.me/0909123456 hoặc link OA"
                    value={zaloUrl}
                    onChange={(e) => setZaloUrl(e.target.value)}
                  />
                  <span className="field-hint">Link mở trực tiếp ứng dụng Zalo trên máy khách</span>
                </div>
                <div className="form-group">
                  <label>Tên hiển thị nút Zalo</label>
                  <input
                    type="text"
                    placeholder="VD: Chat Zalo Tiếp Nhận"
                    value={zaloLabel}
                    onChange={(e) => setZaloLabel(e.target.value)}
                  />
                </div>
              </div>

              <div className="config-section-title" style={{ marginTop: 14 }}>
                <Clock size={16} />
                <span>Thời Gian & Địa Chỉ Tiếp Nhận</span>
              </div>
              <div className="form-group">
                <label>Khung giờ làm việc</label>
                <input
                  type="text"
                  placeholder="VD: 08:00 - 17:30 (Thứ 2 - Thứ 7)"
                  value={workingHours}
                  onChange={(e) => setWorkingHours(e.target.value)}
                />
              </div>
              <div className="form-group" style={{ marginTop: 10 }}>
                <label>
                  <MapPin size={14} style={{ display: 'inline', marginRight: 4, verticalAlign: 'text-bottom' }} />
                  Địa chỉ trung tâm kỹ thuật
                </label>
                <input
                  type="text"
                  placeholder="VD: 243 Quốc Lộ 1A, Khu phố 4, Phường Tam Bình, TP. Hồ Chí Minh"
                  value={workshopAddress}
                  onChange={(e) => setWorkshopAddress(e.target.value)}
                />
              </div>

              <div className="config-section-title" style={{ marginTop: 14 }}>
                <Navigation size={16} />
                <span>Bản Đồ Google Maps & Tọa Độ Dẫn Đường</span>
              </div>
              <div className="form-group">
                <label>
                  <Globe size={14} style={{ display: 'inline', marginRight: 4, verticalAlign: 'text-bottom' }} />
                  Đường dẫn Google Maps (Share link hoặc vị trí)
                </label>
                <input
                  type="url"
                  placeholder="https://maps.google.com/?q=..."
                  value={mapUrl}
                  onChange={(e) => setMapUrl(e.target.value)}
                />
                <span className="field-hint" style={{ fontSize: 11, color: '#64748b', marginTop: 3, display: 'block' }}>
                  * Khách hàng bấm "Chỉ đường" hoặc "Mở bản đồ" sẽ chuyển thẳng tới liên kết này.
                </span>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 8 }}>
                <div className="form-group">
                  <label>Vĩ độ (Latitude)</label>
                  <input
                    type="number"
                    step="any"
                    placeholder="10.854611"
                    value={latitude}
                    onChange={(e) => setLatitude(e.target.value)}
                  />
                </div>
                <div className="form-group">
                  <label>Kinh độ (Longitude)</label>
                  <input
                    type="number"
                    step="any"
                    placeholder="106.703212"
                    value={longitude}
                    onChange={(e) => setLongitude(e.target.value)}
                  />
                </div>
              </div>
              <div className="form-group" style={{ marginTop: 8 }}>
                <label>Ảnh bản đồ / Sơ đồ đường đi (URL tùy chọn)</label>
                <input
                  type="url"
                  placeholder="https://... hoặc để trống để sử dụng bản đồ vector mặc định"
                  value={mapImageUrl}
                  onChange={(e) => setMapImageUrl(e.target.value)}
                />
                <span className="field-hint" style={{ fontSize: 11, color: '#64748b', marginTop: 3, display: 'block' }}>
                  * Nếu cung cấp URL ảnh sơ đồ, app sẽ ưu tiên hiển thị ảnh này cho khách hàng.
                </span>
              </div>
            </div>

            <div className="portal-config-modal-footer">
              <button
                type="button"
                className="btn-cancel"
                onClick={onClose}
                disabled={saving}
              >
                Hủy
              </button>
              <button
                type="submit"
                className="btn-save"
                disabled={saving}
              >
                <Save size={16} />
                {saving ? 'Đang lưu...' : 'Lưu cấu hình'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
};

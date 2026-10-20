import React, { useState, useEffect } from 'react';
import { PhoneCall, MessageSquare, Clock, MapPin, X, Save, AlertCircle } from 'lucide-react';
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

  const [hotlineNumber, setHotlineNumber] = useState<string>('0909000000');
  const [hotlineLabel, setHotlineLabel] = useState<string>('Hotline Kỹ Thuật');
  const [zaloUrl, setZaloUrl] = useState<string>('https://zalo.me');
  const [zaloLabel, setZaloLabel] = useState<string>('Chat Zalo Tiếp Nhận');
  const [workingHours, setWorkingHours] = useState<string>('08:00 - 17:30 (Thứ 2 - Thứ 7)');
  const [workshopAddress, setWorkshopAddress] = useState<string>(
    'Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp'
  );

  useEffect(() => {
    if (!isOpen) return;
    setLoading(true);
    setErrorMsg(null);
    getPortalSupportConfig()
      .then((cfg: PortalSupportConfig) => {
        if (cfg) {
          setHotlineNumber(cfg.hotlineNumber || '');
          setHotlineLabel(cfg.hotlineLabel || 'Hotline Kỹ Thuật');
          setZaloUrl(cfg.zaloUrl || '');
          setZaloLabel(cfg.zaloLabel || 'Chat Zalo Tiếp Nhận');
          setWorkingHours(cfg.workingHours || '');
          setWorkshopAddress(cfg.workshopAddress || '');
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
    if (!hotlineNumber.trim() || !zaloUrl.trim()) {
      setErrorMsg('Vui lòng nhập đầy đủ Số hotline và Đường dẫn Zalo.');
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
                  placeholder="VD: Trung tâm kỹ thuật sửa chữa thiết bị công nghiệp"
                  value={workshopAddress}
                  onChange={(e) => setWorkshopAddress(e.target.value)}
                />
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

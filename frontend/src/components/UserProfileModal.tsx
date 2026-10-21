import React, { useState, useRef, useEffect } from 'react';
import {
  X,
  Camera,
  User,
  Phone,
  Briefcase,
  Shield,
  Check,
  AlertCircle,
  RefreshCw,
  Hash,
  Sparkles,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { getRoleLabel } from '../utils/permissions';
import './UserProfileModal.css';

interface UserProfileModalProps {
  isOpen: boolean;
  onClose: () => void;
  currentUser: UserInfo | null;
  onProfileUpdated?: (updatedUser: UserInfo) => void;
  showToast?: (message: string) => void;
}

export const UserProfileModal: React.FC<UserProfileModalProps> = ({
  isOpen,
  onClose,
  currentUser,
  onProfileUpdated,
  showToast,
}) => {
  const [fullName, setFullName] = useState(currentUser?.fullName || '');
  const [phone, setPhone] = useState(currentUser?.phone || '');
  const [department, setDepartment] = useState(
    typeof currentUser?.department === 'string' ? currentUser.department : ''
  );
  const [avatarUrl, setAvatarUrl] = useState(currentUser?.avatarUrl || '');
  const [avatarError, setAvatarError] = useState(false);

  const [isUploadingAvatar, setIsUploadingAvatar] = useState(false);
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [statusMessage, setStatusMessage] = useState<{
    type: 'success' | 'error';
    text: string;
  } | null>(null);

  const fileInputRef = useRef<HTMLInputElement | null>(null);

  // Sync state when currentUser changes or modal opens
  useEffect(() => {
    if (currentUser) {
      setFullName(currentUser.fullName || '');
      setPhone(currentUser.phone || '');
      setDepartment(
        typeof currentUser.department === 'string' ? currentUser.department : ''
      );
      setAvatarUrl(currentUser.avatarUrl || '');
      setAvatarError(false);
      setStatusMessage(null);
    }
  }, [currentUser, isOpen]);

  if (!isOpen || !currentUser) return null;

  const handleAvatarFileSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Reset input so the same file can be picked again if needed
    e.target.value = '';

    // Validate size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      setStatusMessage({
        type: 'error',
        text: 'Kích thước tệp quá lớn. Vui lòng chọn ảnh dưới 5MB.',
      });
      return;
    }

    // Validate format
    if (!['image/jpeg', 'image/png', 'image/webp', 'image/gif'].includes(file.type)) {
      setStatusMessage({
        type: 'error',
        text: 'Định dạng ảnh không hỗ trợ. Vui lòng chọn tệp JPG, PNG, WEBP hoặc GIF.',
      });
      return;
    }

    setIsUploadingAvatar(true);
    setStatusMessage(null);

    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch('/api/v1/employees/me/avatar', {
        method: 'POST',
        headers: getAuthHeaders(),
        body: formData,
      });

      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.message || 'Không thể tải lên ảnh đại diện');
      }

      const newAvatarUrl = result.data?.avatarUrl || avatarUrl;
      setAvatarUrl(newAvatarUrl);
      setAvatarError(false);

      // Cập nhật localStorage và phát event đồng bộ toàn ứng dụng
      const updatedUser: UserInfo = {
        ...currentUser,
        avatarUrl: newAvatarUrl,
      };
      localStorage.setItem('currentUser', JSON.stringify(updatedUser));
      window.dispatchEvent(new Event('permissions-updated'));

      if (onProfileUpdated) {
        onProfileUpdated(updatedUser);
      }

      setStatusMessage({
        type: 'success',
        text: 'Cập nhật ảnh đại diện thành công!',
      });
      showToast?.('Đã cập nhật ảnh đại diện');
    } catch (err: any) {
      setStatusMessage({
        type: 'error',
        text: err.message || 'Lỗi khi tải lên ảnh đại diện',
      });
    } finally {
      setIsUploadingAvatar(false);
    }
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!currentUser.id) {
      setStatusMessage({
        type: 'error',
        text: 'Không xác định được ID nhân viên',
      });
      return;
    }

    setIsSavingProfile(true);
    setStatusMessage(null);

    try {
      const payload: Record<string, any> = {
        fullName: fullName.trim(),
        phone: phone.trim() || null,
        department: department.trim() || null,
      };

      const response = await fetch(`/api/v1/employees/${currentUser.id}`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify(payload),
      });

      const result = await response.json();
      if (!response.ok) {
        throw new Error(result.message || 'Không thể lưu thông tin hồ sơ');
      }

      const updatedUser: UserInfo = {
        ...currentUser,
        fullName: fullName.trim(),
        phone: phone.trim() || undefined,
        department: department.trim() || undefined,
        avatarUrl: result.data?.avatarUrl || avatarUrl,
      };
      localStorage.setItem('currentUser', JSON.stringify(updatedUser));
      window.dispatchEvent(new Event('permissions-updated'));

      if (onProfileUpdated) {
        onProfileUpdated(updatedUser);
      }

      setStatusMessage({
        type: 'success',
        text: 'Lưu thông tin cá nhân thành công!',
      });
      showToast?.('Đã lưu thông tin cá nhân');
    } catch (err: any) {
      setStatusMessage({
        type: 'error',
        text: err.message || 'Lỗi khi lưu thông tin',
      });
    } finally {
      setIsSavingProfile(false);
    }
  };

  const displayInitial = (fullName || currentUser.username).charAt(0).toUpperCase();

  return (
    <div className="upm-backdrop" onClick={onClose} role="dialog" aria-modal="true">
      <div className="upm-modal" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="upm-header">
          <div className="upm-header-title">
            <div className="upm-header-icon">
              <Sparkles size={20} />
            </div>
            <div>
              <h3>Hồ sơ cá nhân</h3>
              <p>Quản lý ảnh đại diện và thông tin tài khoản công ty</p>
            </div>
          </div>
          <button
            type="button"
            className="upm-close-btn"
            onClick={onClose}
            aria-label="Đóng"
          >
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="upm-body">
          {/* Avatar Showcase */}
          <div className="upm-avatar-section">
            <div className="upm-avatar-wrapper">
              <div className="upm-avatar-frame">
                {avatarUrl && !avatarError ? (
                  <img
                    src={avatarUrl}
                    alt={fullName || currentUser.username}
                    className="upm-avatar-image"
                    onError={() => setAvatarError(true)}
                  />
                ) : (
                  <div className="upm-avatar-placeholder">
                    {displayInitial}
                  </div>
                )}
                {isUploadingAvatar && (
                  <div className="upm-avatar-loading-overlay">
                    <RefreshCw size={24} className="upm-spin" />
                  </div>
                )}
              </div>
              <button
                type="button"
                className="upm-camera-badge"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploadingAvatar}
                title="Thay đổi ảnh đại diện"
                aria-label="Tải ảnh đại diện mới"
              >
                <Camera size={16} />
              </button>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/png,image/jpeg,image/webp,image/gif"
                style={{ display: 'none' }}
                onChange={handleAvatarFileSelected}
              />
            </div>

            <div className="upm-avatar-meta">
              <div className="upm-primary-info">
                <span className="upm-user-display-name">
                  {fullName || currentUser.username}
                </span>
                <span className="upm-user-username">@{currentUser.username}</span>
              </div>
              <div className="upm-badge-group">
                <span className="upm-role-pill">
                  <Shield size={12} />
                  {getRoleLabel(currentUser.role)}
                </span>
                <span className="upm-status-pill">
                  <span className="upm-status-dot" />
                  {currentUser.status === 'ACTIVE' ? 'Đang hoạt động' : currentUser.status || 'Hoạt động'}
                </span>
              </div>
              <div className="upm-avatar-action-row">
                <button
                  type="button"
                  className="upm-upload-action-btn"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={isUploadingAvatar}
                >
                  <Camera size={14} />
                  <span>{isUploadingAvatar ? 'Đang tải lên...' : 'Tải ảnh mới'}</span>
                </button>
                <span className="upm-upload-hint">Định dạng JPG, PNG, WEBP (tối đa 5MB)</span>
              </div>
            </div>
          </div>

          {/* Alert Message */}
          {statusMessage && (
            <div className={`upm-alert upm-alert-${statusMessage.type}`}>
              {statusMessage.type === 'success' ? (
                <Check size={16} className="upm-alert-icon" />
              ) : (
                <AlertCircle size={16} className="upm-alert-icon" />
              )}
              <span>{statusMessage.text}</span>
            </div>
          )}

          {/* Information Form */}
          <form id="upm-form" onSubmit={handleSaveProfile} className="upm-form">
            <div className="upm-form-grid">
              <div className="upm-form-group">
                <label htmlFor="upm-fullname">
                  <User size={14} />
                  Họ và tên
                </label>
                <input
                  id="upm-fullname"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="Nhập họ và tên đầy đủ"
                  required
                />
              </div>

              <div className="upm-form-group">
                <label htmlFor="upm-phone">
                  <Phone size={14} />
                  Số điện thoại
                </label>
                <input
                  id="upm-phone"
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="Ví dụ: 0912345678"
                />
              </div>

              <div className="upm-form-group">
                <label htmlFor="upm-department">
                  <Briefcase size={14} />
                  Phòng ban / Bộ phận
                </label>
                <input
                  id="upm-department"
                  type="text"
                  value={department}
                  onChange={(e) => setDepartment(e.target.value)}
                  placeholder="Ví dụ: Kỹ thuật, Kho vận, Kinh doanh"
                />
              </div>

              {currentUser.employeeCode && (
                <div className="upm-form-group">
                  <label htmlFor="upm-empcode">
                    <Hash size={14} />
                    Mã nhân viên
                  </label>
                  <input
                    id="upm-empcode"
                    type="text"
                    value={currentUser.employeeCode}
                    disabled
                    readOnly
                    className="upm-input-disabled"
                  />
                </div>
              )}
            </div>
          </form>
        </div>

        {/* Footer */}
        <div className="upm-footer">
          <button
            type="button"
            className="upm-btn upm-btn-secondary"
            onClick={onClose}
            disabled={isSavingProfile || isUploadingAvatar}
          >
            Đóng
          </button>
          <button
            type="submit"
            form="upm-form"
            className="upm-btn upm-btn-primary"
            disabled={isSavingProfile || isUploadingAvatar}
          >
            {isSavingProfile ? (
              <>
                <RefreshCw size={15} className="upm-spin" />
                <span>Đang lưu...</span>
              </>
            ) : (
              <>
                <Check size={16} />
                <span>Lưu thông tin</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

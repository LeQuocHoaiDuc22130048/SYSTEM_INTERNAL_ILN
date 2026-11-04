import React, { useState } from 'react';
import { X, KeyRound, Eye, EyeOff, ShieldCheck, Dices, Check, AlertCircle } from 'lucide-react';
import { getJsonAuthHeaders } from '../utils/auth';
import { getRoleLabel } from '../utils/permissions';
import './ResetPasswordModal.css';

interface ResetPasswordUser {
  id: string;
  fullName: string;
  username: string;
  role: string;
  department?: string;
  employeeCode?: string;
}

interface ResetPasswordModalProps {
  user: ResetPasswordUser;
  onClose: () => void;
  onSuccess: () => void;
  showToast: (msg: string) => void;
}

export const ResetPasswordModal: React.FC<ResetPasswordModalProps> = ({
  user,
  onClose,
  onSuccess,
  showToast,
}) => {
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  // Sinh mật khẩu ngẫu nhiên an toàn (chữ hoa, chữ thường, số, ký tự đặc biệt)
  const handleGenerateRandom = () => {
    const uppers = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lowers = 'abcdefghijkmnpqrstuvwxyz';
    const numbers = '23456789';
    const symbols = '@#$';

    let pass = '';
    // Đảm bảo đủ các thành phần bắt buộc
    pass += uppers[Math.floor(Math.random() * uppers.length)];
    pass += lowers[Math.floor(Math.random() * lowers.length)];
    pass += numbers[Math.floor(Math.random() * numbers.length)];
    pass += symbols[Math.floor(Math.random() * symbols.length)];

    const allChars = uppers + lowers + numbers;
    for (let i = 0; i < 6; i++) {
      pass += allChars[Math.floor(Math.random() * allChars.length)];
    }

    // Trộn ngẫu nhiên
    const shuffled = pass.split('').sort(() => 0.5 - Math.random()).join('');
    setNewPassword(shuffled);
    setConfirmPassword(shuffled);
    setShowPassword(true); // Hiển thị mật khẩu để admin tiện xem và copy
    setError(null);
  };

  const handleCopy = () => {
    if (!newPassword) return;
    navigator.clipboard.writeText(newPassword);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!newPassword) {
      setError('Vui lòng nhập mật khẩu mới');
      return;
    }

    // Regex: ít nhất 8 ký tự, có chữ hoa, chữ thường và số
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/;
    if (!passwordRegex.test(newPassword)) {
      setError('Mật khẩu tối thiểu 8 ký tự, bao gồm ít nhất 1 chữ hoa, 1 chữ thường và 1 chữ số');
      return;
    }

    if (newPassword !== confirmPassword) {
      setError('Mật khẩu xác nhận không khớp');
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`/api/v1/auth/users/${user.id}/reset-password`, {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          newPassword,
          confirmPassword,
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message || `Lỗi ${res.status}: Không thể đặt lại mật khẩu`);
      }

      showToast(`Đã đổi mật khẩu cho nhân viên ${user.fullName || user.username} thành công`);
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err.message || 'Đã có lỗi xảy ra khi đổi mật khẩu');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="reset-pwd-backdrop" onClick={onClose}>
      <div className="reset-pwd-modal" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="reset-pwd-header">
          <div className="reset-pwd-header-title">
            <div className="reset-pwd-header-icon">
              <KeyRound size={20} />
            </div>
            <div>
              <h3>Đổi mật khẩu nhân viên</h3>
              <p>Chỉ Super Admin mới có quyền thực hiện thao tác này</p>
            </div>
          </div>
          <button className="reset-pwd-close-btn" onClick={onClose} title="Đóng">
            <X size={18} />
          </button>
        </div>

        {/* User Card */}
        <div className="reset-pwd-user-card">
          <div className="reset-pwd-user-avatar">
            {(user.fullName || user.username).charAt(0).toUpperCase()}
          </div>
          <div className="reset-pwd-user-info">
            <div className="reset-pwd-user-name">
              {user.fullName || user.username}
              {user.employeeCode && (
                <span className="reset-pwd-emp-code">({user.employeeCode})</span>
              )}
            </div>
            <div className="reset-pwd-user-meta">
              <span className="reset-pwd-username">@{user.username}</span>
              <span className="reset-pwd-separator">•</span>
              <span className="reset-pwd-role-badge">
                <ShieldCheck size={12} />
                {getRoleLabel(user.role)}
              </span>
              {user.department && (
                <>
                  <span className="reset-pwd-separator">•</span>
                  <span className="reset-pwd-dept">{user.department}</span>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="reset-pwd-form">
          {error && (
            <div className="reset-pwd-error-alert">
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}

          <div className="reset-pwd-field">
            <div className="reset-pwd-label-row">
              <label htmlFor="new-password">Mật khẩu mới</label>
              <button
                type="button"
                className="reset-pwd-random-btn"
                onClick={handleGenerateRandom}
                title="Tạo ngẫu nhiên mật khẩu mạnh"
              >
                <Dices size={13} />
                <span>Tạo ngẫu nhiên</span>
              </button>
            </div>
            <div className="reset-pwd-input-wrap">
              <input
                id="new-password"
                type={showPassword ? 'text' : 'password'}
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
                placeholder="Nhập mật khẩu mới..."
                autoComplete="new-password"
                disabled={loading}
              />
              <button
                type="button"
                className="reset-pwd-eye-btn"
                onClick={() => setShowPassword(!showPassword)}
                title={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            {newPassword && showPassword && (
              <div className="reset-pwd-copy-hint">
                <button type="button" onClick={handleCopy} className="reset-pwd-btn-copy">
                  {copied ? <Check size={13} style={{ color: '#10b981' }} /> : null}
                  <span>{copied ? 'Đã sao chép mật khẩu!' : 'Sao chép mật khẩu'}</span>
                </button>
              </div>
            )}
          </div>

          <div className="reset-pwd-field">
            <label htmlFor="confirm-password">Xác nhận mật khẩu mới</label>
            <div className="reset-pwd-input-wrap">
              <input
                id="confirm-password"
                type={showPassword ? 'text' : 'password'}
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                placeholder="Nhập lại mật khẩu mới..."
                autoComplete="new-password"
                disabled={loading}
              />
            </div>
          </div>

          <div className="reset-pwd-note">
            <span className="reset-pwd-note-dot">•</span>
            <span>Mật khẩu phải có tối thiểu 8 ký tự, bao gồm ít nhất 1 chữ hoa (A-Z), 1 chữ thường (a-z) và 1 chữ số (0-9).</span>
          </div>

          <div className="reset-pwd-actions">
            <button
              type="button"
              className="reset-pwd-btn-cancel"
              onClick={onClose}
              disabled={loading}
            >
              Hủy bỏ
            </button>
            <button
              type="submit"
              className="reset-pwd-btn-submit"
              disabled={loading}
            >
              {loading ? (
                <>
                  <div className="reset-pwd-spinner" />
                  <span>Đang cập nhật...</span>
                </>
              ) : (
                <span>Lưu mật khẩu mới</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};


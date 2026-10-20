import React, { useState, useEffect, useCallback } from 'react';
import {
  Key,
  ShieldCheck,
  Lock,
  Unlock,
  Copy,
  Plus,
  RefreshCw,
  AlertCircle,
  CheckCircle2,
  Share2,
  Eye,
  EyeOff,
  UserCheck,
  Sparkles,
} from 'lucide-react';
import type { Customer, CustomerAccount, CreateCustomerAccountRequest } from '../types/customer';
import {
  getCustomerAccounts,
  createCustomerAccount,
  resetCustomerPassword,
  updateCustomerAccountStatus,
} from '../utils/customerApi';
import './CustomerAccountsSection.css';

interface CustomerAccountsSectionProps {
  customer: Customer;
  showToast: (msg: string) => void;
  canManage: boolean;
}

function generateRandomPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
  let pwd = '';
  // Ensure at least one upper, one lower, one digit, one special
  pwd += 'ABCDEFGHJKLMNPQRSTUVWXYZ'[Math.floor(Math.random() * 24)];
  pwd += 'abcdefghijkmnpqrstuvwxyz'[Math.floor(Math.random() * 24)];
  pwd += '23456789'[Math.floor(Math.random() * 8)];
  pwd += '!@#$%'[Math.floor(Math.random() * 5)];
  for (let i = 0; i < 4; i++) {
    pwd += chars[Math.floor(Math.random() * chars.length)];
  }
  // Shuffle
  return pwd.split('').sort(() => 0.5 - Math.random()).join('');
}

export const CustomerAccountsSection: React.FC<CustomerAccountsSectionProps> = ({
  customer,
  showToast,
  canManage,
}) => {
  const [accounts, setAccounts] = useState<CustomerAccount[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Create Modal
  const [isCreateOpen, setIsCreateOpen] = useState<boolean>(false);
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [showPassword, setShowPassword] = useState<boolean>(true);
  const [contactName, setContactName] = useState<string>('');
  const [phone, setPhone] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [mustChangePassword, setMustChangePassword] = useState<boolean>(true);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [formErrors, setFormErrors] = useState<Record<string, string>>({});

  // Success Share Modal
  const [shareData, setShareData] = useState<{
    account: CustomerAccount;
    plainPassword: string;
    shareableMessage: string;
  } | null>(null);

  // Reset Password Modal
  const [resetTargetAccount, setResetTargetAccount] = useState<CustomerAccount | null>(null);
  const [newPassword, setNewPassword] = useState<string>('');
  const [resetting, setResetting] = useState<boolean>(false);

  // Fetch accounts list
  const fetchAccounts = useCallback(async () => {
    setLoading(true);
    setErrorMsg(null);
    const res = await getCustomerAccounts(customer.id);
    if (res.success && res.data) {
      setAccounts(res.data);
    } else {
      setErrorMsg(res.message || 'Không thể tải danh sách tài khoản');
    }
    setLoading(false);
  }, [customer.id]);

  useEffect(() => {
    fetchAccounts();
  }, [fetchAccounts]);

  // Open Create Form with smart defaults
  const handleOpenCreate = () => {
    // Default username: customer phone or customer code without special chars
    const defaultUsername = (customer.phone || customer.customerCode || 'khach')
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '');

    setUsername(defaultUsername);
    setPassword(generateRandomPassword());
    setShowPassword(true);
    setContactName(customer.customerName);
    setPhone(customer.phone || '');
    setEmail(customer.email || '');
    setMustChangePassword(true);
    setFormErrors({});
    setIsCreateOpen(true);
  };

  // Submit Create Account
  const handleSubmitCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submitting) return;

    const errors: Record<string, string> = {};
    const cleanUsername = username.trim();
    if (!cleanUsername) {
      errors.username = 'Tên đăng nhập không được để trống';
    } else if (cleanUsername.length < 3 || cleanUsername.length > 50) {
      errors.username = 'Tên đăng nhập từ 3 - 50 ký tự';
    } else if (!/^[a-zA-Z0-9._-]+$/.test(cleanUsername)) {
      errors.username = 'Tên đăng nhập chỉ chứa chữ cái, số, dấu chấm, gạch dưới';
    }

    if (!password || password.length < 6) {
      errors.password = 'Mật khẩu tối thiểu 6 ký tự';
    }

    if (!contactName.trim()) {
      errors.contactName = 'Tên người liên hệ không được để trống';
    }

    if (Object.keys(errors).length > 0) {
      setFormErrors(errors);
      return;
    }

    setSubmitting(true);
    setFormErrors({});

    const req: CreateCustomerAccountRequest = {
      username: cleanUsername,
      password,
      contactName: contactName.trim(),
      phone: phone.trim() || undefined,
      email: email.trim() || undefined,
      mustChangePassword,
    };

    const res = await createCustomerAccount(customer.id, req);
    setSubmitting(false);

    if (res.success && res.data) {
      showToast('Tạo tài khoản portal thành công!');
      setIsCreateOpen(false);
      fetchAccounts();

      // Show Share Dialog
      const origin = window.location.origin;
      const portalUrl = `${origin}/#portal`;
      const shareMsg =
        res.data.shareableMessage ||
        `Kính gửi Quý khách ${req.contactName},\n\nThông tin tài khoản tra cứu đơn sửa chữa:\n- Cổng tra cứu: ${portalUrl}\n- Tên đăng nhập: ${res.data.account.username}\n- Mật khẩu: ${res.data.plainPassword}\n\nQuý khách vui lòng đổi mật khẩu ở lần đầu đăng nhập. Trân trọng!`;

      setShareData({
        account: res.data.account,
        plainPassword: res.data.plainPassword,
        shareableMessage: shareMsg,
      });
    } else {
      if (res.errors && res.errors.length > 0) {
        const beErrors: Record<string, string> = {};
        res.errors.forEach((e) => {
          beErrors[e.field] = e.message;
        });
        setFormErrors(beErrors);
      }
      showToast(res.message || 'Không thể tạo tài khoản');
    }
  };

  // Toggle Account Active Status
  const handleToggleStatus = async (account: CustomerAccount) => {
    const nextState = !account.active;
    const actionText = nextState ? 'mở khóa' : 'tạm khóa';
    if (!window.confirm(`Bạn có chắc muốn ${actionText} tài khoản "${account.username}"?`)) {
      return;
    }

    const res = await updateCustomerAccountStatus(customer.id, account.id, nextState);
    if (res.success) {
      showToast(res.message || `Đã ${actionText} tài khoản`);
      fetchAccounts();
    } else {
      showToast(res.message || 'Lỗi cập nhật trạng thái');
    }
  };

  // Open Reset Password
  const handleOpenReset = (account: CustomerAccount) => {
    setResetTargetAccount(account);
    setNewPassword(generateRandomPassword());
  };

  // Submit Reset Password
  const handleSubmitReset = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!resetTargetAccount || resetting) return;
    if (!newPassword || newPassword.length < 6) {
      showToast('Mật khẩu tối thiểu 6 ký tự');
      return;
    }

    setResetting(true);
    const res = await resetCustomerPassword(customer.id, resetTargetAccount.id, { newPassword });
    setResetting(false);

    if (res.success) {
      showToast('Đổi mật khẩu thành công!');
      const origin = window.location.origin;
      const portalUrl = `${origin}/#portal`;
      const shareMsg = `Kính gửi Quý khách ${resetTargetAccount.contactName},\n\nMật khẩu Cổng tra cứu của Quý khách đã được đặt lại:\n- Cổng tra cứu: ${portalUrl}\n- Tên đăng nhập: ${resetTargetAccount.username}\n- Mật khẩu mới: ${newPassword}\n\nTrân trọng cảm ơn!`;

      setShareData({
        account: resetTargetAccount,
        plainPassword: newPassword,
        shareableMessage: shareMsg,
      });
      setResetTargetAccount(null);
      fetchAccounts();
    } else {
      showToast(res.message || 'Không thể đổi mật khẩu');
    }
  };

  // Copy to clipboard
  const copyToClipboard = (text: string, label: string) => {
    navigator.clipboard.writeText(text);
    showToast(`Đã sao chép ${label}!`);
  };

  return (
    <div className="customer-accounts-container">
      <div className="customer-accounts-header">
        <div>
          <h4 className="accounts-section-title">
            <Key size={16} className="text-blue-500" />
            Tài khoản Cổng khách hàng (Customer Portal)
          </h4>
          <p className="accounts-section-desc">
            Cung cấp tài khoản để khách hàng tự theo dõi tiến độ, xem ảnh/video và lịch sử đơn hàng.
          </p>
        </div>
        {canManage && (
          <button
            type="button"
            className="btn-create-account"
            onClick={handleOpenCreate}
            disabled={!customer.active}
            title={!customer.active ? 'Khách hàng đang ngừng hoạt động' : undefined}
          >
            <Plus size={15} />
            Cấp tài khoản mới
          </button>
        )}
      </div>

      {loading ? (
        <div className="accounts-loading">
          <RefreshCw size={18} className="animate-spin" />
          Đang tải danh sách tài khoản...
        </div>
      ) : errorMsg ? (
        <div className="accounts-error">
          <AlertCircle size={16} />
          {errorMsg}
        </div>
      ) : accounts.length === 0 ? (
        <div className="accounts-empty">
          <UserCheck size={36} className="empty-icon" />
          <p className="empty-title">Chưa có tài khoản nào được tạo cho khách hàng này</p>
          <p className="empty-desc">
            Bấm "Cấp tài khoản mới" để tạo tên đăng nhập và mật khẩu, sau đó gửi thông tin cho khách hàng qua Zalo hoặc SMS.
          </p>
        </div>
      ) : (
        <div className="accounts-list">
          {accounts.map((acc) => (
            <div key={acc.id} className={`account-card ${!acc.active ? 'inactive' : ''}`}>
              <div className="account-info">
                <div className="account-title-row">
                  <span className="account-username font-mono">{acc.username}</span>
                  {acc.active ? (
                    <span className="account-badge active">
                      <ShieldCheck size={12} /> Hoạt động
                    </span>
                  ) : (
                    <span className="account-badge locked">
                      <Lock size={12} /> Đang khóa
                    </span>
                  )}
                  {acc.mustChangePassword && (
                    <span className="account-badge warn" title="Khách cần đổi mật khẩu ở lần đăng nhập tiếp theo">
                      Cần đổi MK
                    </span>
                  )}
                </div>
                <div className="account-meta">
                  <span><strong>Người nhận:</strong> {acc.contactName}</span>
                  {acc.phone && <span><strong>SĐT:</strong> {acc.phone}</span>}
                  {acc.email && <span><strong>Email:</strong> {acc.email}</span>}
                  {acc.createdAt && (
                    <span>
                      <strong>Ngày cấp:</strong> {new Date(acc.createdAt).toLocaleDateString('vi-VN')}
                    </span>
                  )}
                </div>
              </div>

              {canManage && (
                <div className="account-actions">
                  <button
                    type="button"
                    className="btn-account-action reset"
                    onClick={() => handleOpenReset(acc)}
                    title="Đặt lại mật khẩu"
                  >
                    <Key size={14} />
                    Đổi mật khẩu
                  </button>
                  <button
                    type="button"
                    className={`btn-account-action ${acc.active ? 'lock' : 'unlock'}`}
                    onClick={() => handleToggleStatus(acc)}
                    title={acc.active ? 'Khóa tài khoản này' : 'Mở khóa tài khoản'}
                  >
                    {acc.active ? <Lock size={14} /> : <Unlock size={14} />}
                    {acc.active ? 'Khóa' : 'Mở khóa'}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* CREATE MODAL */}
      {isCreateOpen && (
        <div className="modal-overlay" style={{ zIndex: 1100 }}>
          <div className="modal-content modal-account-form">
            <div className="modal-header">
              <h3>
                <Key size={18} className="text-blue-500" />
                Cấp tài khoản Cổng khách hàng
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => setIsCreateOpen(false)}
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSubmitCreate}>
              <div className="modal-body form-body">
                <div className="form-group">
                  <label>
                    Tên đăng nhập <span className="req">*</span>
                  </label>
                  <input
                    type="text"
                    className={`form-input ${formErrors.username ? 'error' : ''}`}
                    placeholder="ví dụ: sdt_khach hoặc ma_khach"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                  />
                  {formErrors.username && (
                    <span className="field-error-msg">{formErrors.username}</span>
                  )}
                </div>

                <div className="form-group">
                  <label>
                    Mật khẩu ban đầu <span className="req">*</span>
                  </label>
                  <div className="password-input-group">
                    <input
                      type={showPassword ? 'text' : 'password'}
                      className={`form-input font-mono ${formErrors.password ? 'error' : ''}`}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="btn-icon-addon"
                      onClick={() => setShowPassword(!showPassword)}
                      title={showPassword ? 'Ẩn' : 'Hiện'}
                    >
                      {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                    <button
                      type="button"
                      className="btn-random-pwd"
                      onClick={() => setPassword(generateRandomPassword())}
                      title="Tạo ngẫu nhiên"
                    >
                      <Sparkles size={14} /> Sinh ngẫu nhiên
                    </button>
                  </div>
                  {formErrors.password && (
                    <span className="field-error-msg">{formErrors.password}</span>
                  )}
                </div>

                <div className="form-group">
                  <label>
                    Tên người liên hệ / nhận tài khoản <span className="req">*</span>
                  </label>
                  <input
                    type="text"
                    className={`form-input ${formErrors.contactName ? 'error' : ''}`}
                    value={contactName}
                    onChange={(e) => setContactName(e.target.value)}
                  />
                  {formErrors.contactName && (
                    <span className="field-error-msg">{formErrors.contactName}</span>
                  )}
                </div>

                <div className="form-row-2">
                  <div className="form-group">
                    <label>Số điện thoại</label>
                    <input
                      type="text"
                      className="form-input"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                    />
                  </div>
                  <div className="form-group">
                    <label>Email</label>
                    <input
                      type="email"
                      className="form-input"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-checkbox-group">
                  <label className="checkbox-label">
                    <input
                      type="checkbox"
                      checked={mustChangePassword}
                      onChange={(e) => setMustChangePassword(e.target.checked)}
                    />
                    <span>Yêu cầu đổi mật khẩu ở lần đăng nhập đầu tiên</span>
                  </label>
                </div>
              </div>

              <div className="modal-footer">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={() => setIsCreateOpen(false)}
                  disabled={submitting}
                >
                  Hủy
                </button>
                <button type="submit" className="btn-submit" disabled={submitting}>
                  {submitting ? (
                    <>
                      <RefreshCw size={14} className="animate-spin" /> Đang tạo...
                    </>
                  ) : (
                    <>
                      <CheckCircle2 size={15} /> Tạo tài khoản & Lấy tin nhắn gửi khách
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* RESET PASSWORD MODAL */}
      {resetTargetAccount && (
        <div className="modal-overlay" style={{ zIndex: 1100 }}>
          <div className="modal-content modal-account-form">
            <div className="modal-header">
              <h3>
                <Key size={18} className="text-amber-500" />
                Đặt lại mật khẩu cho: {resetTargetAccount.username}
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => setResetTargetAccount(null)}
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSubmitReset}>
              <div className="modal-body form-body">
                <p style={{ fontSize: '0.88rem', color: '#64748b', marginBottom: '12px' }}>
                  Hệ thống sẽ cập nhật mật khẩu mới cho tài khoản của khách hàng. Hãy sao chép tin nhắn để gửi cho khách sau khi đổi xong.
                </p>

                <div className="form-group">
                  <label>Mật khẩu mới</label>
                  <div className="password-input-group">
                    <input
                      type="text"
                      className="form-input font-mono"
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                    />
                    <button
                      type="button"
                      className="btn-random-pwd"
                      onClick={() => setNewPassword(generateRandomPassword())}
                    >
                      <Sparkles size={14} /> Sinh ngẫu nhiên
                    </button>
                  </div>
                </div>
              </div>

              <div className="modal-footer">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={() => setResetTargetAccount(null)}
                  disabled={resetting}
                >
                  Hủy
                </button>
                <button type="submit" className="btn-submit" disabled={resetting}>
                  {resetting ? 'Đang cập nhật...' : 'Xác nhận đổi mật khẩu'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* SUCCESS SHARE MODAL */}
      {shareData && (
        <div className="modal-overlay" style={{ zIndex: 1200 }}>
          <div className="modal-content modal-share-card">
            <div className="modal-header">
              <h3 style={{ color: '#10b981', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <CheckCircle2 size={20} />
                Tài khoản đã sẵn sàng!
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => setShareData(null)}
              >
                ✕
              </button>
            </div>

            <div className="modal-body">
              <div className="credentials-highlight">
                <div className="cred-row">
                  <span className="cred-label">Tên đăng nhập:</span>
                  <span className="cred-val font-mono">{shareData.account.username}</span>
                  <button
                    type="button"
                    className="btn-mini-copy"
                    onClick={() => copyToClipboard(shareData.account.username, 'Tên đăng nhập')}
                  >
                    <Copy size={13} />
                  </button>
                </div>
                <div className="cred-row">
                  <span className="cred-label">Mật khẩu:</span>
                  <span className="cred-val font-mono highlight">{shareData.plainPassword}</span>
                  <button
                    type="button"
                    className="btn-mini-copy"
                    onClick={() => copyToClipboard(shareData.plainPassword, 'Mật khẩu')}
                  >
                    <Copy size={13} />
                  </button>
                </div>
              </div>

              <div className="share-template-box">
                <div className="share-template-header">
                  <Share2 size={14} />
                  <span>Tin nhắn soạn sẵn để gửi Zalo / SMS cho khách</span>
                </div>
                <textarea
                  className="share-template-text"
                  rows={6}
                  readOnly
                  value={shareData.shareableMessage}
                />
              </div>
            </div>

            <div className="modal-footer">
              <button
                type="button"
                className="btn-copy-share"
                onClick={() => copyToClipboard(shareData.shareableMessage, 'Tin nhắn gửi khách')}
              >
                <Copy size={16} /> Sao chép toàn bộ tin nhắn
              </button>
              <button
                type="button"
                className="btn-submit"
                onClick={() => setShareData(null)}
              >
                Hoàn tất
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

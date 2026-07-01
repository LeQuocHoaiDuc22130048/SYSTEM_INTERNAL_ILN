import React, { useState } from 'react';
import { 
  User, 
  Lock, 
  Phone, 
  ShieldCheck, 
  Eye, 
  EyeOff, 
  AlertCircle, 
  X 
} from 'lucide-react';

interface LoginScreenProps {
  onLoginSuccess: (userInfo: any) => void;
  showToast: (message: string) => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({ onLoginSuccess, showToast }) => {
  // Mode state: login or register
  const [isRegisterMode, setIsRegisterMode] = useState<boolean>(false);

  // Login Form State
  const [username, setUsername] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [showPassword, setShowPassword] = useState<boolean>(false);
  const [error, setError] = useState<string>('');
  const [loginLoading, setLoginLoading] = useState<boolean>(false);

  // Register Form State
  const [fullName, setFullName] = useState<string>('');
  const [phone, setPhone] = useState<string>('');
  const [registerUsername, setRegisterUsername] = useState<string>('');
  const [registerPassword, setRegisterPassword] = useState<string>('');
  const [registerShowPassword, setRegisterShowPassword] = useState<boolean>(false);
  const [registerLoading, setRegisterLoading] = useState<boolean>(false);

  // Forgot Password State
  const [forgotUsername, setForgotUsername] = useState<string>('');
  const [forgotPhone, setForgotPhone] = useState<string>('');
  const [forgotOtp, setForgotOtp] = useState<string>('');
  const [forgotNewPassword, setForgotNewPassword] = useState<string>('');
  const [forgotConfirmPassword, setForgotConfirmPassword] = useState<string>('');
  const [forgotOtpRequested, setForgotOtpRequested] = useState<boolean>(false);
  const [forgotError, setForgotError] = useState<string>('');
  const [forgotLoading, setForgotLoading] = useState<boolean>(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState<boolean>(false);

  // Login handler
  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoginLoading(true);
    try {
      const response = await fetch('/api/v1/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password }),
      });
      
      if (!response.ok) {
        const errResult = await response.json();
        throw new Error(errResult.message || 'Sai tên đăng nhập hoặc mật khẩu.');
      }
      
      const result = await response.json();
      if (result && result.data) {
        const { accessToken, refreshToken, userInfo } = result.data;
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('refreshToken', refreshToken);
        localStorage.setItem('currentUser', JSON.stringify(userInfo));
        onLoginSuccess(userInfo);
        showToast(`Đăng nhập thành công! Chào mừng ${userInfo.fullName || userInfo.username}`);
      } else {
        throw new Error('Dữ liệu đăng nhập không hợp lệ.');
      }
    } catch (err: any) {
      setError(err.message || 'Không thể kết nối đến máy chủ.');
    } finally {
      setLoginLoading(false);
    }
  };

  // Register handler
  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    if (!fullName.trim() || !phone.trim() || !registerUsername.trim() || !registerPassword) {
      setError('Vui lòng điền đầy đủ thông tin.');
      return;
    }

    // Strong password check: same regex as Flutter mobile client
    const strongPassword = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/.test(registerPassword);
    if (!strongPassword) {
      setError('Mật khẩu cần tối thiểu 8 ký tự, có chữ hoa, chữ thường và số.');
      return;
    }

    setRegisterLoading(true);
    try {
      const response = await fetch('/api/v1/auth/register', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          username: registerUsername.trim(),
          password: registerPassword,
          fullName: fullName.trim(),
          phone: phone.trim(),
          department: 'Nhân viên',
        }),
      });

      if (!response.ok) {
        const errResult = await response.json();
        throw new Error(errResult.message || 'Đăng ký thất bại. Tên đăng nhập có thể đã tồn tại.');
      }

      showToast('Đăng ký thành công! Vui lòng chờ duyệt trước khi đăng nhập.');
      
      // Reset registration form fields and toggle back to login mode
      setFullName('');
      setPhone('');
      setRegisterUsername('');
      setRegisterPassword('');
      setIsRegisterMode(false);
    } catch (err: any) {
      setError(err.message || 'Không thể đăng ký. Vui lòng thử lại.');
    } finally {
      setRegisterLoading(false);
    }
  };

  // Forgot password handler
  const handleForgotPasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setForgotError('');
    setForgotLoading(true);
    try {
      if (!forgotOtpRequested) {
        // Request OTP
        const response = await fetch('/api/v1/auth/forgot-password/otp', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username: forgotUsername, phone: forgotPhone })
        });
        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.message || 'Yêu cầu OTP thất bại.');
        }
        setForgotOtpRequested(true);
      } else {
        // Submit reset password
        if (forgotNewPassword !== forgotConfirmPassword) {
          throw new Error('Mật khẩu xác nhận không khớp.');
        }
        const response = await fetch('/api/v1/auth/forgot-password', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            username: forgotUsername,
            otp: forgotOtp,
            newPassword: forgotNewPassword
          })
        });
        if (!response.ok) {
          const errData = await response.json();
          throw new Error(errData.message || 'Đặt lại mật khẩu thất bại.');
        }
        showToast('Đặt lại mật khẩu thành công! Vui lòng đăng nhập.');
        setShowForgotPasswordModal(false);
        setForgotOtpRequested(false);
      }
    } catch (err: any) {
      setForgotError(err.message);
    } finally {
      setForgotLoading(false);
    }
  };

  return (
    <div className="login-screen-container">
      <div className="login-grid-overlay"></div>
      <div className="login-content-wrapper">
        <div className="login-split-layout">
          {/* Left side branding */}
          <div className="login-branding-section">
            <img src="/app_logo.png" alt="App Logo" className="login-logo" />
            <h1 className="login-title-h1">HỆ THỐNG INTERNAL ILN</h1>
            <p className="login-subtitle-p">Ứng dụng quản lý giám sát chấm công và thiết bị IoT nội bộ.</p>
          </div>

          {/* Right side form */}
          <div className="login-form-container">
            <div className="login-card">
              {!isRegisterMode ? (
                // Login Form Layout
                <>
                  <h2 className="login-card-title">Đăng nhập Quản trị</h2>
                  <p className="login-card-subtitle">Vui lòng điền thông tin tài khoản của bạn</p>

                  {error && (
                    <div className="login-error-card">
                      <AlertCircle size={18} style={{ color: '#ef4444' }} />
                      <span className="login-error-text">{error}</span>
                    </div>
                  )}

                  <form onSubmit={handleLoginSubmit}>
                    <div className="login-form-group">
                      <label className="login-input-label">Tên đăng nhập</label>
                      <div className="login-input-wrapper">
                        <User className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập username..."
                          value={username}
                          onChange={(e) => setUsername(e.target.value)}
                          required
                          disabled={loginLoading}
                        />
                      </div>
                    </div>

                    <div className="login-form-group">
                      <label className="login-input-label">Mật khẩu</label>
                      <div className="login-input-wrapper">
                        <Lock className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type={showPassword ? "text" : "password"} 
                          className="login-input-field" 
                          placeholder="Nhập mật khẩu..."
                          value={password}
                          onChange={(e) => setPassword(e.target.value)}
                          required
                          disabled={loginLoading}
                        />
                        <button 
                          type="button" 
                          className="login-password-toggle"
                          onClick={() => setShowPassword(!showPassword)}
                          style={{ border: 'none', background: 'none', cursor: 'pointer' }}
                        >
                          {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                        </button>
                      </div>
                    </div>

                    <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '20px' }}>
                      <button 
                        type="button" 
                        className="login-forgot-pwd-btn"
                        onClick={() => setShowForgotPasswordModal(true)}
                        style={{ border: 'none', background: 'none', cursor: 'pointer' }}
                      >
                        Quên mật khẩu?
                      </button>
                    </div>

                    <button 
                      type="submit" 
                      className="login-btn-primary"
                      disabled={loginLoading}
                    >
                      {loginLoading ? <span className="login-spinner"></span> : 'Đăng nhập'}
                    </button>
                  </form>

                  <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px' }}>
                    <button 
                      type="button" 
                      className="login-forgot-pwd-btn"
                      onClick={() => {
                        setIsRegisterMode(true);
                        setError('');
                      }}
                      style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '14px', fontWeight: '600' }}
                    >
                      Chưa có tài khoản? Đăng ký ngay
                    </button>
                  </div>
                </>
              ) : (
                // Register Form Layout
                <>
                  <h2 className="login-card-title">Đăng ký Tài khoản</h2>
                  <p className="login-card-subtitle">Vui lòng điền thông tin cá nhân của bạn</p>

                  {error && (
                    <div className="login-error-card">
                      <AlertCircle size={18} style={{ color: '#ef4444' }} />
                      <span className="login-error-text">{error}</span>
                    </div>
                  )}

                  <form onSubmit={handleRegisterSubmit}>
                    <div className="login-form-group">
                      <label className="login-input-label">Họ và tên</label>
                      <div className="login-input-wrapper">
                        <User className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập họ và tên..."
                          value={fullName}
                          onChange={(e) => setFullName(e.target.value)}
                          required
                          disabled={registerLoading}
                        />
                      </div>
                    </div>

                    <div className="login-form-group">
                      <label className="login-input-label">Số điện thoại</label>
                      <div className="login-input-wrapper">
                        <Phone className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập số điện thoại..."
                          value={phone}
                          onChange={(e) => setPhone(e.target.value)}
                          required
                          disabled={registerLoading}
                        />
                      </div>
                    </div>

                    <div className="login-form-group">
                      <label className="login-input-label">Tên đăng nhập</label>
                      <div className="login-input-wrapper">
                        <User className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập tên đăng nhập..."
                          value={registerUsername}
                          onChange={(e) => setRegisterUsername(e.target.value)}
                          required
                          disabled={registerLoading}
                        />
                      </div>
                    </div>

                    <div className="login-form-group">
                      <label className="login-input-label">Mật khẩu</label>
                      <div className="login-input-wrapper">
                        <Lock className="login-input-icon-left" size={18} style={{ color: 'var(--color-text-light)' }} />
                        <input 
                          type={registerShowPassword ? "text" : "password"} 
                          className="login-input-field" 
                          placeholder="Nhập mật khẩu..."
                          value={registerPassword}
                          onChange={(e) => setRegisterPassword(e.target.value)}
                          required
                          disabled={registerLoading}
                        />
                        <button 
                          type="button" 
                          className="login-password-toggle"
                          onClick={() => setRegisterShowPassword(!registerShowPassword)}
                          style={{ border: 'none', background: 'none', cursor: 'pointer' }}
                        >
                          {registerShowPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                        </button>
                      </div>
                    </div>

                    <button 
                      type="submit" 
                      className="login-btn-primary"
                      disabled={registerLoading}
                      style={{ marginTop: '10px' }}
                    >
                      {registerLoading ? <span className="login-spinner"></span> : 'Đăng ký'}
                    </button>
                  </form>

                  <div style={{ display: 'flex', justifyContent: 'center', marginTop: '20px' }}>
                    <button 
                      type="button" 
                      className="login-forgot-pwd-btn"
                      onClick={() => {
                        setIsRegisterMode(false);
                        setError('');
                      }}
                      style={{ border: 'none', background: 'none', cursor: 'pointer', fontSize: '14px', fontWeight: '600' }}
                    >
                      Đã có tài khoản? Đăng nhập ngay
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Forgot Password Modal */}
      {showForgotPasswordModal && (
        <div className="login-modal-overlay">
          <div className="login-modal-card">
            <div className="login-modal-header">
              <h3 className="login-modal-title">Đặt lại mật khẩu</h3>
              <button className="modal-close" onClick={() => {
                setShowForgotPasswordModal(false);
                setForgotOtpRequested(false);
                setForgotError('');
              }} style={{ background: 'none', border: 'none', cursor: 'pointer' }}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleForgotPasswordSubmit}>
              <div className="login-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {forgotError && (
                  <div className="login-error-card">
                    <AlertCircle size={18} style={{ color: '#ef4444' }} />
                    <span className="login-error-text">{forgotError}</span>
                  </div>
                )}

                {!forgotOtpRequested ? (
                  <>
                    <div className="login-form-group">
                      <label className="login-input-label">Tên tài khoản</label>
                      <div className="login-input-wrapper">
                        <User className="login-input-icon-left" size={18} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập tên đăng nhập..."
                          value={forgotUsername}
                          onChange={(e) => setForgotUsername(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="login-form-group">
                      <label className="login-input-label">Số điện thoại đăng ký</label>
                      <div className="login-input-wrapper">
                        <Phone className="login-input-icon-left" size={18} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập số điện thoại..."
                          value={forgotPhone}
                          onChange={(e) => setForgotPhone(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                  </>
                ) : (
                  <>
                    <div style={{ fontSize: '13px', color: 'var(--color-success)', background: 'var(--color-success-light)', padding: '10px', borderRadius: '6px' }}>
                      Mã OTP đã được gửi đến số điện thoại của bạn!
                    </div>
                    <div className="login-form-group">
                      <label className="login-input-label">Mã OTP</label>
                      <div className="login-input-wrapper">
                        <ShieldCheck className="login-input-icon-left" size={18} />
                        <input 
                          type="text" 
                          className="login-input-field" 
                          placeholder="Nhập mã OTP 6 số..."
                          value={forgotOtp}
                          onChange={(e) => setForgotOtp(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="login-form-group">
                      <label className="login-input-label">Mật khẩu mới</label>
                      <div className="login-input-wrapper">
                        <Lock className="login-input-icon-left" size={18} />
                        <input 
                          type="password" 
                          className="login-input-field" 
                          placeholder="Mật khẩu mới..."
                          value={forgotNewPassword}
                          onChange={(e) => setForgotNewPassword(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                    <div className="login-form-group">
                      <label className="login-input-label">Xác nhận mật khẩu</label>
                      <div className="login-input-wrapper">
                        <Lock className="login-input-icon-left" size={18} />
                        <input 
                          type="password" 
                          className="login-input-field" 
                          placeholder="Nhập lại mật khẩu..."
                          value={forgotConfirmPassword}
                          onChange={(e) => setForgotConfirmPassword(e.target.value)}
                          required
                        />
                      </div>
                    </div>
                  </>
                )}
              </div>
              <div className="login-modal-footer">
                <button 
                  type="button" 
                  className="login-modal-btn-cancel"
                  onClick={() => {
                    setShowForgotPasswordModal(false);
                    setForgotOtpRequested(false);
                    setForgotError('');
                  }}
                  disabled={forgotLoading}
                >
                  Hủy
                </button>
                <button 
                  type="submit" 
                  className="login-modal-btn-submit"
                  disabled={forgotLoading}
                >
                  {forgotLoading ? <span className="login-spinner"></span> : (forgotOtpRequested ? 'Cập nhật' : 'Gửi mã OTP')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

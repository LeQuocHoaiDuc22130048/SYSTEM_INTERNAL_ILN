import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Wrench,
  Search,
  CheckCircle2,
  Clock,
  Package,
  Cpu,
  Image,
  MessageSquare,
  ArrowLeft,
  RefreshCw,
  LogOut,
  LogIn,
  AlertCircle,
  User,
  Key,
  Eye,
  EyeOff,
  ChevronDown,
  Camera,
  UserCog,
  Building2,
} from 'lucide-react';
import type { UserInfo } from '../../mockData';
import type {
  Customer,
  CustomerOrderResponse,
  CustomerOrderDetailResponse,
  CustomerAccountProfileResponse,
} from '../../types/customer';
import {
  trackPortalOrder,
  getMyCustomerOrders,
  getMyCustomerOrderDetail,
  getMyCustomerProfile,
  changeCustomerPassword,
  getCustomerAccountProfile,
  updateCustomerAccountProfile,
  uploadCustomerAvatar,
} from '../../utils/portalApi';
import './CustomerPortalApp.css';

interface CustomerPortalAppProps {
  currentUser?: UserInfo | null;
  onLogout?: () => void;
  onNavigateLogin?: () => void;
}

export const CustomerPortalApp: React.FC<CustomerPortalAppProps> = ({
  currentUser,
  onLogout,
  onNavigateLogin,
}) => {
  const isAuth = !!currentUser && currentUser.role === 'CUSTOMER';

  // Navigation tab: 'orders' | 'track'
  const [activeTab, setActiveTab] = useState<'orders' | 'track'>(isAuth ? 'orders' : 'track');

  // Customer Profile (when logged in)
  const [customerProfile, setCustomerProfile] = useState<Customer | null>(null);

  // Quick Track State
  const [trackOrderCode, setTrackOrderCode] = useState('');
  const [trackPhone, setTrackPhone] = useState('');
  const [trackLoading, setTrackLoading] = useState(false);
  const [trackError, setTrackError] = useState<string | null>(null);

  // Active Detail View State (from either My Orders or Quick Track)
  const [selectedOrder, setSelectedOrder] = useState<CustomerOrderDetailResponse | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);
  const [previewMedia, setPreviewMedia] = useState<{ url: string; caption?: string | null; isVideo?: boolean } | null>(null);


  // My Orders State
  const [orders, setOrders] = useState<CustomerOrderResponse[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(false);
  const [orderSearchKeyword, setOrderSearchKeyword] = useState('');

  // User Menu State
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);

  // Click outside to close user dropdown
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (userMenuRef.current && !userMenuRef.current.contains(event.target as Node)) {
        setIsUserMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Robust Logout Handler
  const handleLogoutAction = async () => {
    try {
      if (onLogout) {
        await onLogout();
      }
    } catch (err) {
      console.error('Logout error:', err);
    } finally {
      // Safeguard: Ensure local storage tokens are removed
      localStorage.removeItem('accessToken');
      localStorage.removeItem('refreshToken');
      localStorage.removeItem('currentUser');
      window.location.hash = '';
      if (!onLogout) {
        window.location.reload();
      }
    }
  };

  // Fetch customer profile if logged in
  useEffect(() => {
    if (isAuth) {
      getMyCustomerProfile().then((res) => {
        if (res.success && res.data) {
          setCustomerProfile(res.data);
        }
      });
    }
  }, [isAuth]);

  // Fetch orders list if logged in and in orders tab
  const fetchOrders = useCallback(async () => {
    if (!isAuth) return;
    setOrdersLoading(true);
    const res = await getMyCustomerOrders({ keyword: orderSearchKeyword });
    if (res.success && res.data) {
      setOrders(res.data.content || []);
    }
    setOrdersLoading(false);
  }, [isAuth, orderSearchKeyword]);

  useEffect(() => {
    if (isAuth && activeTab === 'orders' && !selectedOrder) {
      fetchOrders();
    }
  }, [isAuth, activeTab, selectedOrder, fetchOrders]);

  // Handle Quick Track Submit
  const handleTrackSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!trackOrderCode.trim() || !trackPhone.trim() || trackLoading) return;

    setTrackLoading(true);
    setTrackError(null);
    const res = await trackPortalOrder({
      orderCode: trackOrderCode.trim().toUpperCase(),
      phone: trackPhone.trim(),
    });
    setTrackLoading(false);

    if (res.success && res.data) {
      setSelectedOrder(res.data);
    } else {
      setTrackError(res.message || 'Không tìm thấy đơn hàng phù hợp với thông tin đã nhập.');
    }
  };

  // Change Password State
  const [isChangePasswordOpen, setIsChangePasswordOpen] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPwd, setShowPwd] = useState(false);
  const [changePwdLoading, setChangePwdLoading] = useState(false);
  const [changePwdError, setChangePwdError] = useState<string | null>(null);
  const [changePwdSuccess, setChangePwdSuccess] = useState<string | null>(null);

  const handleChangePasswordSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setChangePwdError(null);
    setChangePwdSuccess(null);

    if (newPassword.length < 8) {
      setChangePwdError('Mật khẩu mới tối thiểu 8 ký tự');
      return;
    }
    if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(newPassword)) {
      setChangePwdError('Mật khẩu mới phải bao gồm chữ hoa, chữ thường và chữ số');
      return;
    }
    if (newPassword !== confirmPassword) {
      setChangePwdError('Xác nhận mật khẩu mới không khớp');
      return;
    }

    setChangePwdLoading(true);
    const res = await changeCustomerPassword({
      currentPassword,
      newPassword,
      confirmPassword,
    });
    setChangePwdLoading(false);

    if (res.success) {
      setChangePwdSuccess('Đổi mật khẩu thành công!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setTimeout(() => {
        setIsChangePasswordOpen(false);
        setChangePwdSuccess(null);
      }, 1500);
    } else {
      setChangePwdError(res.message || 'Không thể đổi mật khẩu');
    }
  };

  // Customer Account Profile & Avatar State
  const [accountProfile, setAccountProfile] = useState<CustomerAccountProfileResponse | null>(null);
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [profileContactName, setProfileContactName] = useState('');
  const [profilePhone, setProfilePhone] = useState('');
  const [profileEmail, setProfileEmail] = useState('');
  const [profileLoading, setProfileLoading] = useState(false);
  const [profileError, setProfileError] = useState<string | null>(null);
  const [profileSuccess, setProfileSuccess] = useState<string | null>(null);
  const [avatarUploading, setAvatarUploading] = useState(false);
  const avatarInputRef = useRef<HTMLInputElement>(null);

  const fetchAccountProfile = useCallback(async () => {
    if (!isAuth) return;
    const res = await getCustomerAccountProfile();
    if (res.success && res.data) {
      setAccountProfile(res.data);
      setProfileContactName(res.data.contactName || '');
      setProfilePhone(res.data.phone || '');
      setProfileEmail(res.data.email || '');

      try {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
          const userObj = JSON.parse(stored);
          userObj.fullName = res.data.contactName;
          if (res.data.avatarUrl) {
            userObj.avatarUrl = res.data.avatarUrl;
          }
          localStorage.setItem('currentUser', JSON.stringify(userObj));
        }
      } catch (e) {}
    }
  }, [isAuth]);

  useEffect(() => {
    if (isAuth) {
      void fetchAccountProfile();
    }
  }, [isAuth, fetchAccountProfile]);

  const handleAvatarFileSelected = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setProfileError('Vui lòng chọn tệp định dạng hình ảnh (JPG, PNG, WEBP,...)');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setProfileError('Ảnh đại diện không được vượt quá 10 MB');
      return;
    }

    setAvatarUploading(true);
    setProfileError(null);
    setProfileSuccess(null);

    const res = await uploadCustomerAvatar(file);
    setAvatarUploading(false);

    if (res.success && res.data) {
      setAccountProfile(res.data);
      setProfileSuccess('Cập nhật ảnh đại diện thành công!');
      try {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
          const userObj = JSON.parse(stored);
          userObj.avatarUrl = res.data.avatarUrl;
          localStorage.setItem('currentUser', JSON.stringify(userObj));
        }
      } catch (e) {}
    } else {
      setProfileError(res.message || 'Không thể tải lên ảnh đại diện');
    }

    if (avatarInputRef.current) {
      avatarInputRef.current.value = '';
    }
  };

  const handleProfileSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profileContactName.trim()) {
      setProfileError('Vui lòng nhập tên người liên hệ');
      return;
    }

    setProfileLoading(true);
    setProfileError(null);
    setProfileSuccess(null);

    const res = await updateCustomerAccountProfile({
      contactName: profileContactName.trim(),
      phone: profilePhone.trim() || undefined,
      email: profileEmail.trim() || undefined,
    });
    setProfileLoading(false);

    if (res.success && res.data) {
      setAccountProfile(res.data);
      setProfileSuccess('Cập nhật thông tin tài khoản thành công!');
      try {
        const stored = localStorage.getItem('currentUser');
        if (stored) {
          const userObj = JSON.parse(stored);
          userObj.fullName = res.data.contactName;
          localStorage.setItem('currentUser', JSON.stringify(userObj));
        }
      } catch (e) {}
      setTimeout(() => {
        setProfileSuccess(null);
      }, 2000);
    } else {
      setProfileError(res.message || 'Không thể cập nhật thông tin');
    }
  };


  // Open Order Detail from My Orders
  const handleOpenMyOrderDetail = async (orderId: string) => {
    setDetailLoading(true);
    const res = await getMyCustomerOrderDetail(orderId);
    setDetailLoading(false);
    if (res.success && res.data) {
      setSelectedOrder(res.data);
    }
  };

  // Status mapping for badge and stepper
  const getStatusBadgeClass = (status: string) => {
    switch (status) {
      case 'PENDING':
        return 'pending';
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return 'checking';
      case 'IN_PROGRESS':
        return 'progress';
      case 'COMPLETED':
        return 'completed';
      case 'DELIVERED':
        return 'delivered';
      case 'CANCELLED':
        return 'cancelled';
      default:
        return 'progress';
    }
  };

  // Calculate step index for stepper
  // Steps: 0: Tiếp nhận, 1: Kiểm tra, 2: Đang sửa, 3: Hoàn thành, 4: Đã giao
  const getStepIndex = (status: string): number => {
    switch (status) {
      case 'PENDING':
        return 0;
      case 'WAITING_FOR_CHECK':
      case 'CHECKING':
      case 'CHECKED':
        return 1;
      case 'IN_PROGRESS':
        return 2;
      case 'COMPLETED':
        return 3;
      case 'DELIVERED':
        return 4;
      default:
        return 1;
    }
  };

  return (
    <div className="portal-root">
      {/* HEADER / NAVBAR */}
      <header className="portal-navbar">
        <div className="portal-navbar-inner">
          <div
            className="portal-brand"
            onClick={() => {
              setSelectedOrder(null);
              if (isAuth) setActiveTab('orders');
            }}
          >
            <div className="portal-logo-icon">
              <Wrench size={22} />
            </div>
            <div className="portal-brand-text">
              <h1>Cổng Tra Cứu Khách Hàng</h1>
              <span>Trung Tâm Dịch Vụ & Sửa Chữa Biến Tần</span>
            </div>
          </div>

          <div className="portal-nav-actions">
            {isAuth ? (
              <>
                {/* USER PROFILE DROPDOWN */}
                <div className="portal-user-dropdown-wrapper" ref={userMenuRef}>
                  <button
                    type="button"
                    className={`portal-user-chip ${isUserMenuOpen ? 'active' : ''}`}
                    onClick={() => setIsUserMenuOpen(prev => !prev)}
                    title="Menu tài khoản khách hàng"
                  >
                    <div className="portal-user-avatar">
                      {accountProfile?.avatarUrl || currentUser?.avatarUrl ? (
                        <img
                          src={accountProfile?.avatarUrl || currentUser?.avatarUrl}
                          alt="Avatar"
                          className="portal-avatar-img"
                        />
                      ) : (
                        <User size={14} />
                      )}
                    </div>
                    <span className="portal-user-name">
                      {accountProfile?.contactName || customerProfile?.customerName || currentUser?.fullName || currentUser?.username}
                    </span>
                    <ChevronDown size={14} className={`portal-chevron ${isUserMenuOpen ? 'rotate' : ''}`} />
                  </button>

                  {isUserMenuOpen && (
                    <div className="portal-user-dropdown-menu">
                      <div className="portal-user-menu-header">
                        <div className="portal-user-menu-avatar">
                          {accountProfile?.avatarUrl || currentUser?.avatarUrl ? (
                            <img
                              src={accountProfile?.avatarUrl || currentUser?.avatarUrl}
                              alt="Avatar"
                              className="portal-avatar-menu-img"
                            />
                          ) : (
                            <User size={18} />
                          )}
                        </div>
                        <div className="portal-user-menu-info">
                          <p className="portal-user-menu-name">
                            {accountProfile?.contactName || customerProfile?.customerName || currentUser?.fullName || currentUser?.username}
                          </p>
                          <span className="portal-user-menu-sub">
                            {accountProfile?.customerName || currentUser?.username}
                          </span>
                        </div>
                      </div>

                      <div className="portal-user-menu-divider" />

                      <button
                        type="button"
                        className="portal-user-menu-item"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          setProfileError(null);
                          setProfileSuccess(null);
                          setProfileContactName(accountProfile?.contactName || currentUser?.fullName || '');
                          setProfilePhone(accountProfile?.phone || '');
                          setProfileEmail(accountProfile?.email || '');
                          setIsProfileModalOpen(true);
                        }}
                      >
                        <UserCog size={15} />
                        <span>Hồ sơ & Ảnh đại diện</span>
                      </button>

                      <button
                        type="button"
                        className="portal-user-menu-item"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          setIsChangePasswordOpen(true);
                        }}
                      >
                        <Key size={15} />
                        <span>Đổi mật khẩu</span>
                      </button>

                      <button
                        type="button"
                        className="portal-user-menu-item"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          setActiveTab('orders');
                          setSelectedOrder(null);
                        }}
                      >
                        <Package size={15} />
                        <span>Đơn hàng của tôi</span>
                      </button>

                      <div className="portal-user-menu-divider" />

                      <button
                        type="button"
                        className="portal-user-menu-item portal-user-menu-logout"
                        onClick={() => {
                          setIsUserMenuOpen(false);
                          void handleLogoutAction();
                        }}
                      >
                        <LogOut size={15} />
                        <span>Đăng xuất</span>
                      </button>
                    </div>
                  )}
                </div>

                {/* QUICK ACTION: ĐỔI MẬT KHẨU */}
                <button
                  type="button"
                  className="btn-portal-change-pwd"
                  onClick={() => setIsChangePasswordOpen(true)}
                  title="Đổi mật khẩu tài khoản"
                >
                  <Key size={13} />
                  <span>Đổi MK</span>
                </button>

                {/* QUICK ACTION: ĐĂNG XUẤT */}
                <button
                  type="button"
                  className="btn-portal-logout"
                  onClick={() => void handleLogoutAction()}
                  title="Đăng xuất khỏi cổng thông tin"
                >
                  <LogOut size={14} />
                  <span>Đăng xuất</span>
                </button>
              </>
            ) : (
              onNavigateLogin && (
                <button type="button" className="btn-portal-login" onClick={onNavigateLogin}>
                  <LogIn size={15} />
                  Đăng nhập
                </button>
              )
            )}
          </div>
        </div>
      </header>

      {/* MAIN CONTAINER */}
      <main className="portal-main">
        {/* TABS (When authenticated or switching between list & track) */}
        {isAuth && !selectedOrder && (
          <div className="portal-tabs-nav">
            <button
              type="button"
              className={`portal-nav-btn ${activeTab === 'orders' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('orders');
                setSelectedOrder(null);
              }}
            >
              <Package size={16} />
              Đơn hàng của tôi
            </button>
            <button
              type="button"
              className={`portal-nav-btn ${activeTab === 'track' ? 'active' : ''}`}
              onClick={() => {
                setActiveTab('track');
                setSelectedOrder(null);
              }}
            >
              <Search size={16} />
              Tra cứu theo mã
            </button>
          </div>
        )}

        {/* VIEW 1: DETAIL VIEW (When an order is selected) */}
        {detailLoading ? (
          <div style={{ textAlign: 'center', padding: '60px', color: '#64748b' }}>
            <RefreshCw size={28} className="animate-spin" style={{ margin: '0 auto 12px' }} />
            <p>Đang tải chi tiết đơn hàng...</p>
          </div>
        ) : selectedOrder ? (
          <div className="portal-detail-card">
            <div className="detail-header-bar">
              <div className="detail-header-left">
                <button
                  type="button"
                  className="btn-back-portal"
                  onClick={() => setSelectedOrder(null)}
                >
                  <ArrowLeft size={15} />
                  Quay lại danh sách
                </button>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span className="order-code-badge">{selectedOrder.orderCode}</span>
                    <span className={`portal-status-pill ${getStatusBadgeClass(selectedOrder.status)}`}>
                      {selectedOrder.friendlyStatus}
                    </span>
                  </div>
                  <h3 style={{ margin: '6px 0 0', fontSize: '1.25rem', color: '#0f172a' }}>
                    {selectedOrder.orderTitle}
                  </h3>
                </div>
              </div>

              <div style={{ fontSize: '0.82rem', color: '#64748b', textAlign: 'right' }}>
                <div>Ngày nhận: {new Date(selectedOrder.receivedDate).toLocaleDateString('vi-VN')}</div>
                {selectedOrder.expectedDeliveryDate && (
                  <div>
                    Dự kiến giao: {new Date(selectedOrder.expectedDeliveryDate).toLocaleDateString('vi-VN')}
                  </div>
                )}
              </div>
            </div>

            {/* STEPPER PROGRESS */}
            {selectedOrder.status !== 'CANCELLED' ? (
              <div className="portal-stepper">
                {[
                  { label: 'Tiếp nhận', step: 0 },
                  { label: 'Kiểm tra', step: 1 },
                  { label: 'Đang sửa chữa', step: 2 },
                  { label: 'Hoàn tất', step: 3 },
                  { label: 'Đã giao hàng', step: 4 },
                ].map((s) => {
                  const currentStep = getStepIndex(selectedOrder.status);
                  const isDone = s.step < currentStep;
                  const isCurr = s.step === currentStep;
                  return (
                    <div
                      key={s.step}
                      className={`portal-step-item ${isDone ? 'completed' : ''} ${
                        isCurr ? 'current' : ''
                      }`}
                    >
                      <div className="step-circle">
                        {isDone ? <CheckCircle2 size={18} /> : s.step + 1}
                      </div>
                      <span className="step-label">{s.label}</span>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div className="track-error-banner" style={{ marginBottom: '20px' }}>
                <AlertCircle size={18} />
                <span>Đơn hàng này đã được xác nhận hủy xử lý.</span>
              </div>
            )}

            {/* DEVICES IN ORDER */}
            <div className="detail-section-block">
              <h4 className="detail-section-title">
                <Cpu size={18} className="text-blue-500" />
                Thiết bị sửa chữa ({selectedOrder.devices?.length || 0})
              </h4>
              <div className="portal-devices-list">
                {selectedOrder.devices?.map((dev) => (
                  <div key={dev.id} className="portal-device-card">
                    <div className="portal-device-name">{dev.deviceName}</div>
                    <div className="portal-device-meta">
                      {dev.model && <span><strong>Model:</strong> {dev.model}</span>}
                      {dev.serialNumber && <span><strong>Số serial:</strong> {dev.serialNumber}</span>}
                      {dev.symptom && <span><strong>Mô tả lỗi:</strong> {dev.symptom}</span>}
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* PROGRESS UPDATES FROM WORKSHOP */}
            <div className="detail-section-block">
              <h4 className="detail-section-title">
                <MessageSquare size={18} className="text-blue-500" />
                Nhật ký tiến độ từ kỹ thuật viên ({selectedOrder.updates?.length || 0})
              </h4>
              {selectedOrder.updates && selectedOrder.updates.length > 0 ? (
                <div className="portal-timeline-flow">
                  {selectedOrder.updates.map((upd) => (
                    <div key={upd.id} className="portal-timeline-node">
                      <div className="timeline-node-header">
                        <span className="timeline-node-title">{upd.title}</span>
                        <span className="timeline-node-time">
                          <Clock size={12} style={{ display: 'inline', marginRight: '4px' }} />
                          {upd.publishedAt && !isNaN(new Date(upd.publishedAt).getTime())
                            ? new Date(upd.publishedAt).toLocaleString('vi-VN')
                            : 'Vừa xong'}
                        </span>
                      </div>
                      <p className="timeline-node-content">{upd.content || upd.message}</p>
                    </div>
                  ))}
                </div>
              ) : (
                <p style={{ fontSize: '0.85rem', color: '#94a3b8', fontStyle: 'italic' }}>
                  Kỹ thuật viên đang xử lý và sẽ cập nhật thông tin kiểm tra tại đây.
                </p>
              )}
            </div>

            {/* MEDIA GALLERY */}
            <div className="detail-section-block">
              <h4 className="detail-section-title">
                <Image size={18} className="text-blue-500" />
                Hình ảnh kiểm tra & linh kiện ({selectedOrder.media?.length || 0})
              </h4>
              {selectedOrder.media && selectedOrder.media.length > 0 ? (
                <div className="portal-gallery-grid">
                  {selectedOrder.media.map((med) => {
                    const mediaUrl = med.fileUrl || med.mediaUrl || '';
                    const isVideo = med.mediaType?.startsWith('video') ||
                      /\.(mp4|mov|webm|avi)$/i.test(mediaUrl);
                    return (
                      <div
                        key={med.id}
                        className="portal-gallery-item"
                        onClick={() => setPreviewMedia({ url: mediaUrl, caption: med.caption, isVideo })}
                        title="Click để phóng to ảnh"
                      >
                        {isVideo ? (
                          <div className="portal-video-thumb-container">
                            <video src={mediaUrl} preload="metadata" />
                            <div className="portal-video-play-badge">▶</div>
                          </div>
                        ) : (
                          <img
                            src={mediaUrl}
                            alt={med.caption || 'Ảnh thiết bị'}
                            loading="lazy"
                            onError={(e) => {
                              const target = e.currentTarget;
                              target.style.display = 'none';
                              if (target.parentElement) {
                                target.parentElement.classList.add('media-load-error');
                              }
                            }}
                          />
                        )}
                        {med.caption && <span className="portal-gallery-caption">{med.caption}</span>}
                      </div>
                    );
                  })}
                </div>
              ) : (
                <p style={{ fontSize: '0.85rem', color: '#94a3b8', fontStyle: 'italic' }}>
                  Chưa có hình ảnh kiểm tra nào được chia sẻ.
                </p>
              )}
            </div>
          </div>
        ) : activeTab === 'track' ? (
          /* VIEW 2: QUICK TRACK FORM */
          <div className="track-hero-card">
            <div className="track-hero-header">
              <h2>Tra Cứu Nhanh Tiến Độ Sửa Chữa</h2>
              <p>Nhập mã đơn hàng và số điện thoại đăng ký nhận máy để xem tình trạng sửa chữa</p>
            </div>

            <form onSubmit={handleTrackSubmit} className="track-form">
              <div className="track-input-row">
                <div className="track-field">
                  <label htmlFor="track-order-code">Mã đơn sửa chữa *</label>
                  <input
                    id="track-order-code"
                    type="text"
                    required
                    placeholder="VD: SC-20261017-001"
                    value={trackOrderCode}
                    onChange={(e) => setTrackOrderCode(e.target.value)}
                  />
                </div>
                <div className="track-field">
                  <label htmlFor="track-phone">Số điện thoại (hoặc 4 số cuối) *</label>
                  <input
                    id="track-phone"
                    type="text"
                    required
                    placeholder="VD: 0912345678 hoặc 5678"
                    value={trackPhone}
                    onChange={(e) => setTrackPhone(e.target.value)}
                  />
                </div>
              </div>

              {trackError && (
                <div className="track-error-banner">
                  <AlertCircle size={16} />
                  <span>{trackError}</span>
                </div>
              )}

              <button
                id="btn-portal-search-order"
                type="submit"
                className="btn-track-submit"
                disabled={trackLoading}
              >
                {trackLoading ? (
                  <>
                    <RefreshCw size={18} className="animate-spin" /> Đang tra cứu...
                  </>
                ) : (
                  <>
                    <Search size={18} /> Tra cứu tiến độ ngay
                  </>
                )}
              </button>
            </form>
          </div>
        ) : (
          /* VIEW 3: MY ORDERS LIST (When Authenticated) */
          <div>
            <div className="portal-orders-header">
              <h2 className="portal-orders-title">
                Đơn hàng của Quý khách ({orders.length})
              </h2>
              <div className="portal-orders-search">
                <Search size={15} className="search-icon" />
                <input
                  type="text"
                  placeholder="Tìm mã đơn, tên máy..."
                  value={orderSearchKeyword}
                  onChange={(e) => setOrderSearchKeyword(e.target.value)}
                />
              </div>
            </div>

            {ordersLoading ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>
                <RefreshCw size={24} className="animate-spin" style={{ margin: '0 auto 8px' }} />
                Đang tải danh sách đơn hàng của bạn...
              </div>
            ) : orders.length === 0 ? (
              <div className="track-hero-card" style={{ textAlign: 'center' }}>
                <Package size={36} style={{ color: '#94a3b8', margin: '0 auto 12px' }} />
                <h3>Chưa tìm thấy đơn hàng nào</h3>
                <p>Quý khách chưa có đơn sửa chữa nào hoặc từ khóa tìm kiếm không khớp.</p>
              </div>
            ) : (
              <div className="portal-orders-grid">
                {orders.map((ord) => (
                  <div
                    key={ord.id}
                    className="portal-order-card"
                    onClick={() => handleOpenMyOrderDetail(ord.id)}
                  >
                    <div>
                      <div className="card-top-row">
                        <span className="order-code-badge">{ord.orderCode}</span>
                        <span className={`portal-status-pill ${getStatusBadgeClass(ord.status)}`}>
                          {ord.friendlyStatus}
                        </span>
                      </div>
                      <h4 className="order-title">{ord.orderTitle}</h4>
                    </div>

                    <div className="order-meta-info">
                      <div className="meta-row">
                        <span>Số lượng thiết bị:</span>
                        <strong>{ord.devicesCount} máy</strong>
                      </div>
                      <div className="meta-row">
                        <span>Ngày nhận:</span>
                        <span>{new Date(ord.receivedDate).toLocaleDateString('vi-VN')}</span>
                      </div>
                      {ord.expectedDeliveryDate && (
                        <div className="meta-row">
                          <span>Dự kiến giao:</span>
                          <span style={{ color: '#2563eb', fontWeight: 600 }}>
                            {new Date(ord.expectedDeliveryDate).toLocaleDateString('vi-VN')}
                          </span>
                        </div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </main>

      {/* FOOTER */}
      <footer className="portal-footer">
        <p>© 2026 Hệ Thống Sửa Chữa Biến Tần — Cổng thông tin & tra cứu khách hàng trực tuyến.</p>
        {isAuth && (
          <div className="portal-footer-account">
            <span>Tài khoản: <strong>{customerProfile?.customerName || currentUser?.fullName || currentUser?.username}</strong></span>
            <span className="portal-footer-dot">•</span>
            <button
              type="button"
              className="portal-footer-link"
              onClick={() => setIsChangePasswordOpen(true)}
            >
              <Key size={12} />
              Đổi mật khẩu
            </button>
            <span className="portal-footer-dot">•</span>
            <button
              type="button"
              className="portal-footer-link portal-footer-logout"
              onClick={() => void handleLogoutAction()}
            >
              <LogOut size={12} />
              Đăng xuất
            </button>
          </div>
        )}
      </footer>

      {/* MODAL: HỒ SƠ TÀI KHOẢN & AVATAR */}
      {isProfileModalOpen && (
        <div className="portal-modal-overlay">
          <div className="portal-modal-card">
            <div className="portal-modal-header">
              <h3>
                <UserCog size={18} className="text-blue-600" />
                Hồ sơ tài khoản & Ảnh đại diện
              </h3>
              <button
                type="button"
                className="portal-modal-close"
                onClick={() => {
                  setIsProfileModalOpen(false);
                  setProfileError(null);
                  setProfileSuccess(null);
                }}
              >
                ✕
              </button>
            </div>

            <div className="portal-modal-body">
              {profileSuccess && (
                <div className="portal-success-banner">
                  <CheckCircle2 size={16} />
                  <span>{profileSuccess}</span>
                </div>
              )}

              {profileError && (
                <div className="track-error-banner" style={{ marginBottom: '14px' }}>
                  <AlertCircle size={16} />
                  <span>{profileError}</span>
                </div>
              )}

              {/* AVATAR UPLOAD SECTION */}
              <div className="portal-avatar-upload-section">
                <input
                  type="file"
                  ref={avatarInputRef}
                  style={{ display: 'none' }}
                  accept="image/png,image/jpeg,image/jpg,image/webp"
                  onChange={handleAvatarFileSelected}
                />
                <div
                  className="portal-avatar-large-wrapper"
                  onClick={() => avatarInputRef.current?.click()}
                  title="Nhấn để đổi ảnh đại diện"
                >
                  {accountProfile?.avatarUrl || currentUser?.avatarUrl ? (
                    <img
                      src={accountProfile?.avatarUrl || currentUser?.avatarUrl}
                      alt="Avatar"
                      className="portal-avatar-large-img"
                    />
                  ) : (
                    <div className="portal-avatar-large-placeholder">
                      <User size={38} />
                    </div>
                  )}
                  <div className="portal-avatar-overlay">
                    <Camera size={20} />
                    <span>{avatarUploading ? 'Đang tải...' : 'Đổi ảnh'}</span>
                  </div>
                </div>

                <button
                  type="button"
                  className="btn-portal-change-avatar"
                  onClick={() => avatarInputRef.current?.click()}
                  disabled={avatarUploading}
                >
                  <Camera size={14} />
                  <span>{avatarUploading ? 'Đang cập nhật ảnh...' : 'Tải lên ảnh mới'}</span>
                </button>
                <span className="portal-avatar-hint">
                  Hỗ trợ PNG, JPG, JPEG, WEBP. Tối đa 10 MB.
                </span>
              </div>

              {/* PROFILE FORM */}
              <form onSubmit={handleProfileSubmit}>
                <div className="portal-field-group">
                  <label>Tên người liên hệ (Họ và tên) *</label>
                  <input
                    type="text"
                    required
                    maxLength={100}
                    placeholder="Nhập họ và tên người liên hệ"
                    value={profileContactName}
                    onChange={(e) => setProfileContactName(e.target.value)}
                  />
                </div>

                <div className="portal-field-group">
                  <label>Số điện thoại liên hệ</label>
                  <input
                    type="tel"
                    placeholder="Ví dụ: 0912345678"
                    value={profilePhone}
                    onChange={(e) => setProfilePhone(e.target.value)}
                  />
                </div>

                <div className="portal-field-group">
                  <label>Email liên hệ</label>
                  <input
                    type="email"
                    placeholder="Ví dụ: contact@company.com"
                    value={profileEmail}
                    onChange={(e) => setProfileEmail(e.target.value)}
                  />
                </div>

                {/* READ-ONLY COMPANY INFO */}
                <div className="portal-info-box">
                  <div className="portal-info-box-title">
                    <Building2 size={15} />
                    <span>Thông tin doanh nghiệp liên kết</span>
                  </div>
                  <div className="portal-info-box-row">
                    <span>Khách hàng / Công ty:</span>
                    <span className="portal-info-box-val">
                      {accountProfile?.customerName || customerProfile?.customerName || 'Đang cập nhật'}
                    </span>
                  </div>
                  <div className="portal-info-box-row">
                    <span>Mã khách hàng:</span>
                    <span className="portal-info-box-val">
                      {accountProfile?.customerCode || customerProfile?.customerCode || '—'}
                    </span>
                  </div>
                  {accountProfile?.companyTaxCode && (
                    <div className="portal-info-box-row">
                      <span>Mã số thuế:</span>
                      <span className="portal-info-box-val">{accountProfile.companyTaxCode}</span>
                    </div>
                  )}
                  {accountProfile?.companyAddress && (
                    <div className="portal-info-box-row">
                      <span>Địa chỉ:</span>
                      <span className="portal-info-box-val" style={{ textAlign: 'right', maxWidth: '60%' }}>
                        {accountProfile.companyAddress}
                      </span>
                    </div>
                  )}
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                  <button
                    type="button"
                    className="btn-portal-logout"
                    onClick={() => setIsProfileModalOpen(false)}
                    disabled={profileLoading}
                  >
                    Đóng
                  </button>
                  <button
                    type="submit"
                    className="btn-portal-login"
                    disabled={profileLoading}
                  >
                    {profileLoading ? 'Đang lưu...' : 'Lưu thông tin'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: ĐỔI MẬT KHẨU */}
      {isChangePasswordOpen && (
        <div className="portal-modal-overlay">
          <div className="portal-modal-card">
            <div className="portal-modal-header">
              <h3>
                <Key size={18} className="text-blue-600" />
                Đổi mật khẩu tài khoản
              </h3>
              <button
                type="button"
                className="portal-modal-close"
                onClick={() => {
                  setIsChangePasswordOpen(false);
                  setChangePwdError(null);
                  setChangePwdSuccess(null);
                }}
              >
                ✕
              </button>
            </div>
            <form onSubmit={handleChangePasswordSubmit} className="portal-modal-body">
              {changePwdSuccess && (
                <div className="portal-success-banner">
                  <CheckCircle2 size={16} />
                  <span>{changePwdSuccess}</span>
                </div>
              )}

              {changePwdError && (
                <div className="track-error-banner" style={{ marginBottom: '14px' }}>
                  <AlertCircle size={16} />
                  <span>{changePwdError}</span>
                </div>
              )}

              <div className="portal-field-group">
                <label>Mật khẩu hiện tại *</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showPwd ? 'text' : 'password'}
                    required
                    placeholder="Nhập mật khẩu hiện tại"
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPwd(!showPwd)}
                    style={{
                      position: 'absolute',
                      right: '10px',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: '#64748b',
                    }}
                  >
                    {showPwd ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              <div className="portal-field-group">
                <label>Mật khẩu mới (tối thiểu 8 ký tự, gồm chữ hoa, thường & số) *</label>
                <input
                  type={showPwd ? 'text' : 'password'}
                  required
                  placeholder="Nhập mật khẩu mới"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                />
              </div>

              <div className="portal-field-group">
                <label>Xác nhận mật khẩu mới *</label>
                <input
                  type={showPwd ? 'text' : 'password'}
                  required
                  placeholder="Nhập lại mật khẩu mới"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '20px' }}>
                <button
                  type="button"
                  className="btn-portal-logout"
                  onClick={() => setIsChangePasswordOpen(false)}
                  disabled={changePwdLoading}
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  className="btn-portal-login"
                  disabled={changePwdLoading}
                >
                  {changePwdLoading ? 'Đang cập nhật...' : 'Cập nhật mật khẩu'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* LIGHTBOX PREVIEW MODAL */}
      {previewMedia && (
        <div className="portal-lightbox-overlay" onClick={() => setPreviewMedia(null)}>
          <div className="portal-lightbox-content" onClick={(e) => e.stopPropagation()}>
            <div className="portal-lightbox-header">
              <span className="portal-lightbox-title">{previewMedia.caption || 'Chi tiết phương tiện'}</span>
              <div className="portal-lightbox-actions">
                <a
                  href={previewMedia.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="portal-lightbox-openbtn"
                  title="Mở trong tab mới"
                >
                  Mở tab mới
                </a>
                <button
                  type="button"
                  className="portal-lightbox-closebtn"
                  onClick={() => setPreviewMedia(null)}
                >
                  ✕
                </button>
              </div>
            </div>
            <div className="portal-lightbox-body">
              {previewMedia.isVideo ? (
                <video src={previewMedia.url} controls autoPlay className="portal-lightbox-media" />
              ) : (
                <img src={previewMedia.url} alt={previewMedia.caption || 'Chi tiết'} className="portal-lightbox-media" />
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};


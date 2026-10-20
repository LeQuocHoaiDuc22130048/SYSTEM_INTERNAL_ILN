import { usePermissionCheck } from '../utils/permissionContext';
import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Users,
  Search,
  Plus,
  RefreshCw,
  Building2,
  User,
  CheckCircle2,
  XCircle,
  Eye,
  Edit2,
  Power,
  ChevronLeft,
  ChevronRight,
  X,
  Copy,
  Phone,
  PhoneCall,
  Mail,
  MapPin,
  AlertCircle,
  Wrench,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { hasPermission } from '../utils/permissions';
import type {
  Customer,
  CustomerRequest,
  CustomerType,
  CustomerPageResponse,
} from '../types/customer';
import {
  getCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  updateCustomerStatus,
  getCustomerRepairOrders,
} from '../utils/customerApi';
import { normalizeCustomerName } from '../utils/customerNameHelper';
import './CustomersTab.css';
import { CustomerOrderLinkModal } from './CustomerOrderLinkModal';
import { CustomerAccountsSection } from './CustomerAccountsSection';
import { PortalSupportConfigModal } from './PortalSupportConfigModal';

interface CustomersTabProps {
  showToast: (msg: string) => void;
  currentUser?: UserInfo | null;
  onNavigateToOrder?: (orderId: string) => void;
}

export const CustomersTab: React.FC<CustomersTabProps> = ({
  showToast,
  currentUser,
}) => {
  const canAction = usePermissionCheck();
  const canManage = hasPermission(currentUser ?? null, 'CUSTOMER_MANAGE');
  const canManagePortalSupport = hasPermission(currentUser ?? null, 'CUSTOMER_ACCOUNTS_MANAGE') || canManage;

  // Search & Filter state
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [debouncedKeyword, setDebouncedKeyword] = useState<string>('');
  const [activeFilter, setActiveFilter] = useState<string>('ALL'); // 'ALL' | 'ACTIVE' | 'INACTIVE'
  const [typeFilter, setTypeFilter] = useState<string>('ALL'); // 'ALL' | 'INDIVIDUAL' | 'COMPANY'
  const [page, setPage] = useState<number>(0);
  const pageSize = 20;

  // Data state
  const [customerPage, setCustomerPage] = useState<CustomerPageResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Modals state
  const [isFormModalOpen, setIsFormModalOpen] = useState<boolean>(false);
  const [editingCustomer, setEditingCustomer] = useState<Customer | null>(null);
  const [isDetailModalOpen, setIsDetailModalOpen] = useState<boolean>(false);
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null);
  const [detailTab, setDetailTab] = useState<'info' | 'orders' | 'portal'>('info');

  // Customer orders state
  const [customerOrders, setCustomerOrders] = useState<any[]>([]);
  const [customerOrdersLoading, setCustomerOrdersLoading] = useState<boolean>(false);
  const [customerOrdersPage, setCustomerOrdersPage] = useState<number>(0);
  const [customerOrdersTotal, setCustomerOrdersTotal] = useState<number>(0);
  const [linkOrdersOpen, setLinkOrdersOpen] = useState(false);
  const [isSupportConfigModalOpen, setIsSupportConfigModalOpen] = useState(false);

  // Form input state
  const [formName, setFormName] = useState<string>('');
  const [formType, setFormType] = useState<CustomerType>('INDIVIDUAL');
  const [formPhone, setFormPhone] = useState<string>('');
  const [formEmail, setFormEmail] = useState<string>('');
  const [formAddress, setFormAddress] = useState<string>('');
  const [formTaxCode, setFormTaxCode] = useState<string>('');
  const [formNotes, setFormNotes] = useState<string>('');
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  // Status toggle confirmation
  const [statusTargetCustomer, setStatusTargetCustomer] = useState<Customer | null>(null);
  const [statusToggling, setStatusToggling] = useState<boolean>(false);

  // Debounce search term by 300ms
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedKeyword(searchTerm);
      setPage(0);
    }, 300);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  // Request race condition prevention token
  const requestSeqRef = useRef<number>(0);

  // Fetch customers
  const fetchCustomersList = useCallback(async () => {
    const seq = ++requestSeqRef.current;
    setLoading(true);
    setErrorMsg(null);

    let activeParam: boolean | null = null;
    if (activeFilter === 'ACTIVE') activeParam = true;
    if (activeFilter === 'INACTIVE') activeParam = false;

    const res = await getCustomers({
      keyword: debouncedKeyword,
      active: activeParam,
      type: (typeFilter === 'ALL' ? '' : typeFilter) as CustomerType | '',
      page,
      size: pageSize,
    });

    // Check if this is still the latest request
    if (seq !== requestSeqRef.current) return;

    if (res.success && res.data) {
      setCustomerPage(res.data);
    } else {
      setErrorMsg(res.message || 'Không thể tải danh sách khách hàng');
      showToast(res.message || 'Lỗi tải danh sách khách hàng');
    }
    setLoading(false);
  }, [debouncedKeyword, activeFilter, typeFilter, page, showToast]);

  useEffect(() => {
    fetchCustomersList();
  }, [fetchCustomersList]);

  // Fetch customer orders when detail modal is opened to 'orders' tab
  const fetchOrders = useCallback(async (customerId: string, orderPage = 0) => {
    setCustomerOrdersLoading(true);
    const res = await getCustomerRepairOrders(customerId, orderPage, 20);
    if (res.success && res.data) {
      setCustomerOrders(res.data.content || []);
      setCustomerOrdersTotal(res.data.totalElements || 0);
      setCustomerOrdersPage(res.data.number || 0);
    }
    setCustomerOrdersLoading(false);
  }, []);

  useEffect(() => {
    if (isDetailModalOpen && selectedCustomer && detailTab === 'orders') {
      fetchOrders(selectedCustomer.id, customerOrdersPage);
    }
  }, [isDetailModalOpen, selectedCustomer, detailTab, customerOrdersPage, fetchOrders]);

  // Open Create Form
  const handleOpenCreateModal = () => {
    setEditingCustomer(null);
    setFormName('');
    setFormType('INDIVIDUAL');
    setFormPhone('');
    setFormEmail('');
    setFormAddress('');
    setFormTaxCode('');
    setFormNotes('');
    setFieldErrors({});
    setIsFormModalOpen(true);
  };

  // Open Edit Form
  const handleOpenEditModal = (c: Customer) => {
    setEditingCustomer(c);
    setFormName(normalizeCustomerName(c.customerName, c.type));
    setFormType(c.type);
    setFormPhone(c.phone || '');
    setFormEmail(c.email || '');
    setFormAddress(c.address || '');
    setFormTaxCode(c.taxCode || '');
    setFormNotes(c.notes || '');
    setFieldErrors({});
    setIsFormModalOpen(true);
  };

  // Open Detail Modal
  const handleOpenDetailModal = async (c: Customer) => {
    setSelectedCustomer(c);
    setDetailTab('info');
    setIsDetailModalOpen(true);
    // Refresh latest customer data
    const res = await getCustomerById(c.id);
    if (res.success && res.data) {
      setSelectedCustomer(res.data);
    }
  };

  // Submit Form (Create / Update)
  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault();
    if (submitting) return;

    const cleanName = normalizeCustomerName(formName, formType);

    // Client-side quick checks
    const errors: Record<string, string> = {};
    if (!cleanName) {
      errors.customerName = 'Tên khách hàng không được để trống';
    } else if (cleanName.length > 100) {
      errors.customerName = 'Tên khách hàng tối đa 100 ký tự';
    }
    if (formPhone.trim().length > 20) {
      errors.phone = 'Số điện thoại tối đa 20 ký tự';
    }
    if (formEmail.trim()) {
      if (formEmail.trim().length > 254) {
        errors.email = 'Email tối đa 254 ký tự';
      } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formEmail.trim())) {
        errors.email = 'Định dạng email không hợp lệ';
      }
    }
    if (formTaxCode.trim().length > 30) {
      errors.taxCode = 'Mã số thuế tối đa 30 ký tự';
    }
    if (formAddress.trim().length > 500) {
      errors.address = 'Địa chỉ tối đa 500 ký tự';
    }
    if (formNotes.trim().length > 2000) {
      errors.notes = 'Ghi chú tối đa 2000 ký tự';
    }

    if (Object.keys(errors).length > 0) {
      setFieldErrors(errors);
      return;
    }

    setSubmitting(true);
    setFieldErrors({});

    const payload: CustomerRequest = {
      customerName: cleanName,
      type: formType,
      phone: formPhone.trim() || null,
      email: formEmail.trim() || null,
      address: formAddress.trim() || null,
      taxCode: formTaxCode.trim() || null,
      notes: formNotes.trim() || null,
    };

    let res;
    if (editingCustomer) {
      res = await updateCustomer(editingCustomer.id, payload);
    } else {
      res = await createCustomer(payload);
    }

    setSubmitting(false);

    if (res.success && res.data) {
      showToast(res.message || (editingCustomer ? 'Cập nhật thành công!' : 'Tạo mới thành công!'));
      setIsFormModalOpen(false);
      fetchCustomersList();
      if (selectedCustomer && selectedCustomer.id === res.data.id) {
        setSelectedCustomer(res.data);
      }
    } else {
      if (res.errors && res.errors.length > 0) {
        const backendErrors: Record<string, string> = {};
        res.errors.forEach((err) => {
          backendErrors[err.field] = err.message;
        });
        setFieldErrors(backendErrors);
      }
      showToast(res.message || 'Thao tác không thành công');
    }
  };

  // Toggle status action
  const handleConfirmToggleStatus = async () => {
    if (!statusTargetCustomer || statusToggling) return;
    setStatusToggling(true);
    const nextActive = !statusTargetCustomer.active;

    const res = await updateCustomerStatus(statusTargetCustomer.id, nextActive);
    setStatusToggling(false);

    if (res.success) {
      showToast(res.message || (nextActive ? 'Đã kích hoạt khách hàng' : 'Đã ngừng hoạt động khách hàng'));
      setStatusTargetCustomer(null);
      fetchCustomersList();
      if (selectedCustomer && selectedCustomer.id === statusTargetCustomer.id) {
        setSelectedCustomer({ ...selectedCustomer, active: nextActive });
      }
    } else {
      showToast(res.message || 'Lỗi khi đổi trạng thái');
    }
  };

  const copyToClipboard = (text: string, label = 'Đã sao chép') => {
    navigator.clipboard?.writeText(text);
    showToast(`${label}: ${text}`);
  };

  return (
    <div className="customers-container">
      {/* Header Row */}
      <div className="customers-header-row">
        <div className="customers-title-area">
          <h2>
            <Users size={24} className="text-blue-600" />
            Hồ sơ khách hàng
          </h2>
          <div className="customers-subtitle">
            Quản lý thông tin đối tác, cá nhân và doanh nghiệp liên kết đơn sửa chữa
          </div>
        </div>

        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          <button
            type="button"
            className="btn-secondary-refresh"
            onClick={fetchCustomersList}
            title="Làm mới dữ liệu"
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
            Làm mới
          </button>
          {canManagePortalSupport && (
            <button
              type="button"
              className="btn-secondary-refresh"
              onClick={() => setIsSupportConfigModalOpen(true)}
              title="Cấu hình kênh hỗ trợ Portal (Hotline, Zalo)"
              style={{ color: '#0284c7', borderColor: '#bae6fd', background: '#f0f9ff' }}
            >
              <PhoneCall size={16} />
              Kênh hỗ trợ Portal
            </button>
          )}
          {canManage && (
            (canAction('CUSTOMER_CREATE') && (<button
              type="button"
              className="btn-primary-add"
              onClick={handleOpenCreateModal}
            >
              <Plus size={16} />
              Thêm khách hàng
            </button>))
          )}
        </div>
      </div>

      {/* Toolbar / Filters */}
      <div className="customers-toolbar-card">
        <div className="customers-filters-row">
          <div className="customer-search-wrap">
            <Search size={16} className="customer-search-icon" />
            <input
              type="text"
              className="customer-search-input"
              placeholder="Tìm theo tên, mã khách, SĐT, email, MST..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <select
            className="filter-select"
            value={typeFilter}
            onChange={(e) => {
              setTypeFilter(e.target.value);
              setPage(0);
            }}
          >
            <option value="ALL">Tất cả phân loại</option>
            <option value="INDIVIDUAL">Cá nhân</option>
            <option value="COMPANY">Doanh nghiệp</option>
          </select>

          <select
            className="filter-select"
            value={activeFilter}
            onChange={(e) => {
              setActiveFilter(e.target.value);
              setPage(0);
            }}
          >
            <option value="ALL">Tất cả trạng thái</option>
            <option value="ACTIVE">Đang hoạt động</option>
            <option value="INACTIVE">Ngừng hoạt động</option>
          </select>
        </div>
      </div>

      {/* Table Data */}
      <div className="customers-table-card">
        <div className="table-responsive">
          <table className="customers-table">
            <thead>
              <tr>
                <th>Mã khách</th>
                <th>Tên khách hàng</th>
                <th>Phân loại</th>
                <th>Số điện thoại</th>
                <th>Email</th>
                <th>Mã số thuế</th>
                <th>Trạng thái</th>
                <th style={{ textAlign: 'right' }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {loading && (!customerPage || customerPage.content.length === 0) ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '36px', color: '#64748b' }}>
                    <RefreshCw size={24} className="animate-spin" style={{ margin: '0 auto 8px' }} />
                    Đang tải danh sách khách hàng...
                  </td>
                </tr>
              ) : errorMsg && (!customerPage || customerPage.content.length === 0) ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '36px', color: '#dc2626' }}>
                    <AlertCircle size={24} style={{ margin: '0 auto 8px' }} />
                    {errorMsg}
                  </td>
                </tr>
              ) : !customerPage || customerPage.content.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#64748b' }}>
                    <Users size={32} style={{ margin: '0 auto 8px', opacity: 0.5 }} />
                    <div>Không tìm thấy khách hàng nào phù hợp</div>
                  </td>
                </tr>
              ) : (
                customerPage.content.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <span
                        className="customer-code-badge"
                        title={c.customerCode}
                        onClick={() => copyToClipboard(c.customerCode, 'Mã khách')}
                        style={{ cursor: 'pointer' }}
                      >
                        {c.customerCode.length > 15
                          ? `${c.customerCode.slice(0, 12)}...`
                          : c.customerCode}
                      </span>
                    </td>
                    <td>
                      <div className="customer-name-cell">{c.customerName}</div>
                      {c.address && (
                        <div style={{ fontSize: '0.76rem', color: '#64748b' }}>{c.address}</div>
                      )}
                    </td>
                    <td>
                      {c.type === 'COMPANY' ? (
                        <span className="type-pill company">
                          <Building2 size={12} />
                          Doanh nghiệp
                        </span>
                      ) : (
                        <span className="type-pill individual">
                          <User size={12} />
                          Cá nhân
                        </span>
                      )}
                    </td>
                    <td>{c.phone || <span style={{ color: '#94a3b8' }}>—</span>}</td>
                    <td>{c.email || <span style={{ color: '#94a3b8' }}>—</span>}</td>
                    <td>{c.taxCode || <span style={{ color: '#94a3b8' }}>—</span>}</td>
                    <td>
                      {c.active ? (
                        <span className="status-pill active">
                          <CheckCircle2 size={12} />
                          Hoạt động
                        </span>
                      ) : (
                        <span className="status-pill inactive">
                          <XCircle size={12} />
                          Ngừng
                        </span>
                      )}
                    </td>
                    <td>
                      <div className="actions-cell" style={{ justifyContent: 'flex-end' }}>
                        <button
                          type="button"
                          className="btn-icon-action"
                          title="Xem chi tiết & lịch sử"
                          onClick={() => handleOpenDetailModal(c)}
                        >
                          <Eye size={15} />
                        </button>
                        {canManage && (
                          <>
                            {canAction('CUSTOMER_UPDATE') && (<button
                              type="button"
                              className="btn-icon-action"
                              title="Chỉnh sửa hồ sơ"
                              onClick={() => handleOpenEditModal(c)}
                            >
                              <Edit2 size={15} />
                            </button>) }
                            {canAction('CUSTOMER_STATUS_UPDATE') && (<button
                              type="button"
                              className={`btn-icon-action ${c.active ? 'danger' : 'success'}`}
                              title={c.active ? 'Ngừng hoạt động' : 'Kích hoạt lại'}
                              onClick={() => setStatusTargetCustomer(c)}
                            >
                              <Power size={15} />
                            </button>) }
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Bar */}
        {customerPage && customerPage.totalElements > 0 && (
          <div className="customers-pagination-bar">
            <div>
              Hiển thị <strong>{customerPage.content.length}</strong> trên{' '}
              <strong>{customerPage.totalElements}</strong> khách hàng (Trang {customerPage.number + 1} /{' '}
              {customerPage.totalPages || 1})
            </div>
            <div className="pagination-controls">
              <button
                type="button"
                className="btn-page"
                disabled={customerPage.number === 0 || loading}
                onClick={() => setPage((prev) => Math.max(0, prev - 1))}
              >
                <ChevronLeft size={16} />
                Trước
              </button>
              <button
                type="button"
                className="btn-page"
                disabled={customerPage.last || loading}
                onClick={() => setPage((prev) => prev + 1)}
              >
                Sau
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Modal: Thêm / Sửa khách hàng */}
      {isFormModalOpen && (
        <div className="customer-modal-backdrop">
          <div className="customer-modal-card">
            <div className="customer-modal-header">
              <h3>
                {editingCustomer ? <Edit2 size={18} /> : <Plus size={18} />}
                {editingCustomer ? 'Chỉnh sửa khách hàng' : 'Thêm mới khách hàng'}
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => !submitting && setIsFormModalOpen(false)}
              >
                <X size={18} />
              </button>
            </div>

            {(editingCustomer ? canAction('CUSTOMER_UPDATE') : canAction('CUSTOMER_CREATE')) && (<form onSubmit={handleSubmitForm}>
              <div className="customer-modal-body">
                <div className="form-group">
                  <label>
                    Tên khách hàng / Đơn vị <span className="required">*</span>
                  </label>
                  <input
                    type="text"
                    required
                    maxLength={100}
                    placeholder="VD: Nguyễn Văn A hoặc Công ty TNHH Minh Anh"
                    value={formName}
                    autoComplete="off"
                    autoCorrect="off"
                    autoCapitalize="none"
                    spellCheck={false}
                    onChange={(e) => setFormName(e.target.value)}
                    onBlur={() => setFormName((prev) => normalizeCustomerName(prev, formType))}
                  />
                  {fieldErrors.customerName && (
                    <span className="field-error">{fieldErrors.customerName}</span>
                  )}
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>
                      Phân loại <span className="required">*</span>
                    </label>
                    <select
                      value={formType}
                      onChange={(e) => setFormType(e.target.value as CustomerType)}
                    >
                      <option value="INDIVIDUAL">Cá nhân (INDIVIDUAL)</option>
                      <option value="COMPANY">Doanh nghiệp (COMPANY)</option>
                    </select>
                  </div>

                  <div className="form-group">
                    <label>Số điện thoại</label>
                    <input
                      type="text"
                      maxLength={20}
                      placeholder="VD: 0901234567"
                      value={formPhone}
                      onChange={(e) => setFormPhone(e.target.value)}
                    />
                    {fieldErrors.phone && <span className="field-error">{fieldErrors.phone}</span>}
                  </div>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label>Email</label>
                    <input
                      type="email"
                      maxLength={254}
                      placeholder="VD: contact@example.com"
                      value={formEmail}
                      onChange={(e) => setFormEmail(e.target.value)}
                    />
                    {fieldErrors.email && <span className="field-error">{fieldErrors.email}</span>}
                  </div>

                  <div className="form-group">
                    <label>Mã số thuế</label>
                    <input
                      type="text"
                      maxLength={30}
                      placeholder="VD: 0312345678"
                      value={formTaxCode}
                      onChange={(e) => setFormTaxCode(e.target.value)}
                    />
                    {fieldErrors.taxCode && (
                      <span className="field-error">{fieldErrors.taxCode}</span>
                    )}
                  </div>
                </div>

                <div className="form-group">
                  <label>Địa chỉ</label>
                  <input
                    type="text"
                    maxLength={500}
                    placeholder="VD: Số 123 Đường ABC, Quận 1, TP. HCM"
                    value={formAddress}
                    onChange={(e) => setFormAddress(e.target.value)}
                  />
                  {fieldErrors.address && (
                    <span className="field-error">{fieldErrors.address}</span>
                  )}
                </div>

                <div className="form-group">
                  <label>Ghi chú nội bộ</label>
                  <textarea
                    rows={3}
                    maxLength={2000}
                    placeholder="Ghi chú thêm về người liên hệ, thời gian giao dịch..."
                    value={formNotes}
                    onChange={(e) => setFormNotes(e.target.value)}
                  />
                  {fieldErrors.notes && <span className="field-error">{fieldErrors.notes}</span>}
                </div>
              </div>

              <div className="customer-modal-footer">
                <button
                  type="button"
                  className="btn-cancel"
                  disabled={submitting}
                  onClick={() => setIsFormModalOpen(false)}
                >
                  Hủy
                </button>
                {(editingCustomer ? canAction('CUSTOMER_UPDATE') : canAction('CUSTOMER_CREATE')) && (<button type="submit" className="btn-submit" disabled={submitting}>
                  {submitting && <RefreshCw size={14} className="animate-spin" />}
                  {editingCustomer ? 'Lưu thay đổi' : 'Tạo khách hàng'}
                </button>) }
              </div>
            </form>) }
          </div>
        </div>
      )}

      {/* Modal: Xem chi tiết khách hàng & Lịch sử đơn */}
      {isDetailModalOpen && selectedCustomer && (
        <div className="customer-modal-backdrop">
          <div className="customer-modal-card" style={{ maxWidth: '720px' }}>
            <div className="customer-modal-header">
              <h3>
                <Users size={18} />
                Hồ sơ khách hàng: {selectedCustomer.customerName}
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => setIsDetailModalOpen(false)}
              >
                <X size={18} />
              </button>
            </div>

            <div className="customer-modal-body">
              {/* Tabs */}
              <div className="customer-tabs-bar">
                <button
                  type="button"
                  className={`customer-tab-btn ${detailTab === 'info' ? 'active' : ''}`}
                  onClick={() => setDetailTab('info')}
                >
                  Thông tin cơ bản
                </button>
                {canAction('CUSTOMER_HISTORY_VIEW') && (<button
                  type="button"
                  className={`customer-tab-btn ${detailTab === 'orders' ? 'active' : ''}`}
                  onClick={() => setDetailTab('orders')}
                >
                  Lịch sử đơn sửa chữa ({customerOrdersTotal})
                </button>) }
                <button
                  type="button"
                  className={`customer-tab-btn ${detailTab === 'portal' ? 'active' : ''}`}
                  onClick={() => setDetailTab('portal')}
                >
                  Tài khoản Portal
                </button>
              </div>

              {detailTab === 'info' ? (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  <div className="detail-grid">
                    <div className="detail-item">
                      <span className="detail-lbl">Mã khách hàng:</span>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span className="detail-val font-mono">{selectedCustomer.customerCode}</span>
                        <button
                          type="button"
                          className="btn-icon-action"
                          style={{ padding: '2px' }}
                          title="Sao chép mã"
                          onClick={() => copyToClipboard(selectedCustomer.customerCode, 'Mã khách')}
                        >
                          <Copy size={13} />
                        </button>
                      </div>
                    </div>

                    <div className="detail-item">
                      <span className="detail-lbl">Phân loại & Trạng thái:</span>
                      <div style={{ display: 'flex', gap: '6px', alignItems: 'center', marginTop: '2px' }}>
                        {selectedCustomer.type === 'COMPANY' ? (
                          <span className="type-pill company">Doanh nghiệp</span>
                        ) : (
                          <span className="type-pill individual">Cá nhân</span>
                        )}
                        {selectedCustomer.active ? (
                          <span className="status-pill active">Hoạt động</span>
                        ) : (
                          <span className="status-pill inactive">Ngừng hoạt động</span>
                        )}
                      </div>
                    </div>

                    <div className="detail-item">
                      <span className="detail-lbl">Số điện thoại:</span>
                      <span className="detail-val">
                        {selectedCustomer.phone ? (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <Phone size={13} className="text-gray-500" />
                            {selectedCustomer.phone}
                          </span>
                        ) : (
                          'Chưa có'
                        )}
                      </span>
                    </div>

                    <div className="detail-item">
                      <span className="detail-lbl">Email:</span>
                      <span className="detail-val">
                        {selectedCustomer.email ? (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <Mail size={13} className="text-gray-500" />
                            {selectedCustomer.email}
                          </span>
                        ) : (
                          'Chưa có'
                        )}
                      </span>
                    </div>

                    <div className="detail-item">
                      <span className="detail-lbl">Mã số thuế:</span>
                      <span className="detail-val">{selectedCustomer.taxCode || 'Chưa có'}</span>
                    </div>

                    <div className="detail-item">
                      <span className="detail-lbl">Ngày tạo:</span>
                      <span className="detail-val">
                        {selectedCustomer.createdAt
                          ? new Date(selectedCustomer.createdAt).toLocaleString('vi-VN')
                          : '—'}
                      </span>
                    </div>

                    <div className="detail-item" style={{ gridColumn: 'span 2' }}>
                      <span className="detail-lbl">Địa chỉ:</span>
                      <span className="detail-val">
                        {selectedCustomer.address ? (
                          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                            <MapPin size={13} className="text-gray-500" />
                            {selectedCustomer.address}
                          </span>
                        ) : (
                          'Chưa cập nhật'
                        )}
                      </span>
                    </div>

                    <div className="detail-item" style={{ gridColumn: 'span 2' }}>
                      <span className="detail-lbl">Ghi chú nội bộ:</span>
                      <span className="detail-val" style={{ whiteSpace: 'pre-wrap' }}>
                        {selectedCustomer.notes || 'Không có ghi chú'}
                      </span>
                    </div>
                  </div>

                  {canManage && (
                    <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                  {canManage && selectedCustomer.active && (
                    ((canAction('CUSTOMER_ASSIGN') || canAction('CUSTOMER_TRANSFER')) && (<button type="button" className="btn-submit" onClick={() => setLinkOrdersOpen(true)}>
                      <Plus size={16} /> Gán đơn đã có
                    </button>))
                  )}
                      {canAction('CUSTOMER_UPDATE') && (<button
                        type="button"
                        className="btn-page"
                        onClick={() => {
                          setIsDetailModalOpen(false);
                          handleOpenEditModal(selectedCustomer);
                        }}
                      >
                        <Edit2 size={14} />
                        Sửa thông tin
                      </button>) }
                      {canAction('CUSTOMER_STATUS_UPDATE') && (<button
                        type="button"
                        className={`btn-page ${selectedCustomer.active ? 'text-red-600' : 'text-green-600'}`}
                        onClick={() => setStatusTargetCustomer(selectedCustomer)}
                      >
                        <Power size={14} />
                        {selectedCustomer.active ? 'Ngừng hoạt động' : 'Kích hoạt lại'}
                      </button>) }
                    </div>
                  )}
                </div>
              ) : detailTab === 'orders' ? (
                (canAction('CUSTOMER_HISTORY_VIEW') && (<div>
                  {customerOrdersLoading ? (
                    <div style={{ padding: '24px', textAlign: 'center', color: '#64748b' }}>
                      <RefreshCw size={20} className="animate-spin" style={{ margin: '0 auto 8px' }} />
                      Đang tải danh sách đơn của khách...
                    </div>
                  ) : customerOrders.length === 0 ? (
                    <div style={{ padding: '32px', textAlign: 'center', color: '#64748b' }}>
                      <Wrench size={24} style={{ margin: '0 auto 8px', opacity: 0.5 }} />
                      Khách hàng này chưa có đơn sửa chữa nào trong phạm vi quản lý của bạn.
                    </div>
                  ) : (
                    <div>
                      <table className="orders-mini-table">
                        <thead>
                          <tr>
                            <th>Mã đơn</th>
                            <th>Thiết bị</th>
                            <th>Trạng thái</th>
                            <th>Ngày tiếp nhận</th>
                          </tr>
                        </thead>
                        <tbody>
                          {customerOrders.map((ord: any) => (
                            <tr key={ord.id}>
                              <td style={{ fontWeight: 600 }}>{ord.orderCode}</td>
                              <td>{ord.deviceName}</td>
                              <td>
                                <span className="status-pill active" style={{ fontSize: '0.72rem' }}>
                                  {ord.status}
                                </span>
                              </td>
                              <td style={{ color: '#64748b' }}>
                                {ord.createdAt ? new Date(ord.createdAt).toLocaleDateString('vi-VN') : '—'}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>

                      {customerOrdersTotal > 20 && (
                        <div
                          style={{
                            display: 'flex',
                            justifyContent: 'flex-end',
                            gap: '8px',
                            marginTop: '12px',
                          }}
                        >
                          <button
                            type="button"
                            className="btn-page"
                            disabled={customerOrdersPage === 0}
                            onClick={() => setCustomerOrdersPage((p) => Math.max(0, p - 1))}
                          >
                            Trước
                          </button>
                          <button
                            type="button"
                            className="btn-page"
                            disabled={(customerOrdersPage + 1) * 20 >= customerOrdersTotal}
                            onClick={() => setCustomerOrdersPage((p) => p + 1)}
                          >
                            Sau
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </div>))
              ) : (
                <CustomerAccountsSection
                  customer={selectedCustomer}
                  showToast={showToast}
                  canManage={canManage || canAction('CUSTOMER_ACCOUNT_MANAGE')}
                />
              )}
            </div>

            <div className="customer-modal-footer">
              <button
                type="button"
                className="btn-cancel"
                onClick={() => setIsDetailModalOpen(false)}
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}

      {linkOrdersOpen && isDetailModalOpen && selectedCustomer && (
        <CustomerOrderLinkModal customer={selectedCustomer}
          onClose={() => setLinkOrdersOpen(false)}
          onLinked={() => {
            setLinkOrdersOpen(false);
            setCustomerOrdersPage(0);
            void fetchOrders(selectedCustomer.id, 0);
            showToast('Đã gán đơn và cập nhật tên khách hàng trên đơn');
          }} />
      )}
      {/* Confirmation Dialog: Toggle Status */}
      {statusTargetCustomer && (
        <div className="customer-modal-backdrop">
          <div className="customer-modal-card" style={{ maxWidth: '460px' }}>
            <div className="customer-modal-header">
              <h3>
                <AlertCircle size={18} className="text-amber-500" />
                Xác nhận đổi trạng thái
              </h3>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => !statusToggling && setStatusTargetCustomer(null)}
              >
                <X size={18} />
              </button>
            </div>
            <div className="customer-modal-body">
              <p style={{ margin: 0, color: '#334155', fontSize: '0.9rem', lineHeight: '1.5' }}>
                {statusTargetCustomer.active ? (
                  <>
                    Bạn có chắc muốn <strong>ngừng hoạt động</strong> khách hàng{' '}
                    <strong>{statusTargetCustomer.customerName}</strong>?
                    <br />
                    <span style={{ fontSize: '0.8rem', color: '#64748b', display: 'block', marginTop: '8px' }}>
                      * Hồ sơ ngừng hoạt động sẽ không thể liên kết vào đơn sửa chữa mới, nhưng các
                      đơn cũ đã liên kết vẫn được bảo toàn.
                    </span>
                  </>
                ) : (
                  <>
                    Kích hoạt lại khách hàng <strong>{statusTargetCustomer.customerName}</strong>?
                    <br />
                    <span style={{ fontSize: '0.8rem', color: '#64748b', display: 'block', marginTop: '8px' }}>
                      * Khách hàng sẽ có thể được chọn và liên kết vào đơn sửa chữa mới.
                    </span>
                  </>
                )}
              </p>
            </div>
            <div className="customer-modal-footer">
              <button
                type="button"
                className="btn-cancel"
                disabled={statusToggling}
                onClick={() => setStatusTargetCustomer(null)}
              >
                Hủy
              </button>
              {canAction('CUSTOMER_STATUS_UPDATE') && (<button
                type="button"
                className={`btn-submit ${statusTargetCustomer.active ? 'danger' : ''}`}
                style={statusTargetCustomer.active ? { background: '#dc2626' } : {}}
                disabled={statusToggling}
                onClick={handleConfirmToggleStatus}
              >
                {statusToggling && <RefreshCw size={14} className="animate-spin" />}
                {statusTargetCustomer.active ? 'Xác nhận ngừng hoạt động' : 'Xác nhận kích hoạt'}
              </button>) }
            </div>
          </div>
        </div>
      )}

      {/* Portal Support Config Modal */}
      <PortalSupportConfigModal
        isOpen={isSupportConfigModalOpen}
        onClose={() => setIsSupportConfigModalOpen(false)}
        showToast={showToast}
      />
    </div>
  );
};

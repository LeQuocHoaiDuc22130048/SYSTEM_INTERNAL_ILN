import React, { useState, useEffect, useCallback } from 'react';
import {
  Wrench,
  Plus,
  X,
  Trash2,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { isManagerOrAbove as _isManagerOrAbove } from '../utils/permissions';
import { MediaPreviewModal } from './MediaPreviewModal';
import type {
  RepairDevice,
  RepairOrder,
  Employee,
  TimelineEvent,
  OrdersTabProps,
} from '../types/orders';
import { OrderListPanel } from './orders/OrderListPanel';
import { OrderDetailPanel } from './orders/OrderDetailPanel';
import './OrdersTab.css';


export const OrdersTab: React.FC<OrdersTabProps> = ({ showToast, currentUser }) => {
  const isManager = React.useMemo(() => _isManagerOrAbove(currentUser ?? null), [currentUser]);
  // State
  const [orders, setOrders] = useState<RepairOrder[]>([]);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [warrantyFilter, setWarrantyFilter] = useState<string>('ALL');
  const [dateFilter, setDateFilter] = useState<string>('');

  // Infinite scroll / Lazy loading
  const [visibleCount, setVisibleCount] = useState<number>(20);
  const listWrapperRef = React.useRef<HTMLDivElement | null>(null);

  // Selected Order details
  const [selectedOrder, setSelectedOrder] = useState<RepairOrder | null>(null);
  const [timeline, setTimeline] = useState<TimelineEvent[]>([]);
  const [loadingTimeline, setLoadingTimeline] = useState<boolean>(false);

  // Modals
  const [isCreateModalOpen, setIsCreateModalOpen] = useState<boolean>(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState<boolean>(false);
  const [isStatusModalOpen, setIsStatusModalOpen] = useState<boolean>(false);
  const [isAssignModalOpen, setIsAssignModalOpen] = useState<boolean>(false);

  // Form states
  const [customerName, setCustomerName] = useState<string>('');
  const [customerPhone, setCustomerPhone] = useState<string>('');
  const [formDevices, setFormDevices] = useState<Omit<RepairDevice, 'id'>[]>([
    { deviceName: '', deviceType: '', serialNumber: '', underWarranty: false, warrantyExpiry: '', description: '' },
  ]);

  const [newStatus, setNewStatus] = useState<string>('');
  const [statusNote, setStatusNote] = useState<string>('');

  const [selectedTechs, setSelectedTechs] = useState<string[]>([]);
  const [assignNote, setAssignNote] = useState<string>('');

  // Media upload progress/loading & preview modal
  const [uploadingMedia, setUploadingMedia] = useState<boolean>(false);
  const [isPreviewModalOpen, setIsPreviewModalOpen] = useState<boolean>(false);
  const [previewMediaIndex, setPreviewMediaIndex] = useState<number>(0);

  const handleOpenMediaPreview = (index: number) => {
    setPreviewMediaIndex(index);
    setIsPreviewModalOpen(true);
  };

  // Fetch orders
  const fetchOrders = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/v1/repair-orders?size=200', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data?.content) {
          setOrders(result.data.content);
        } else if (Array.isArray(result?.data)) {
          setOrders(result.data);
        }
      } else {
        showToast('Không thể tải danh sách đơn hàng');
      }
    } catch (e) {
      console.error(e);
      showToast('Lỗi kết nối server');
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  // Fetch employees (for assignment dropdown)
  const fetchEmployees = useCallback(async () => {
    try {
      const response = await fetch('/api/v1/employees?size=200', {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data?.content) {
          setEmployees(result.data.content);
        } else if (Array.isArray(result?.data)) {
          setEmployees(result.data);
        }
      }
    } catch (e) {
      console.error(e);
    }
  }, []);

  useEffect(() => {
    fetchOrders();
    fetchEmployees();
  }, [fetchOrders, fetchEmployees]);

  // Fetch timeline of selected order
  const fetchTimeline = async (orderId: string) => {
    setLoadingTimeline(true);
    try {
      const response = await fetch(`/api/v1/repair-orders/${orderId}/timeline`, {
        headers: getAuthHeaders(),
      });
      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setTimeline(result.data);
        }
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingTimeline(false);
    }
  };

  // Select order and open detail pane
  const handleSelectOrder = (order: RepairOrder) => {
    setSelectedOrder(order);
    fetchTimeline(order.id);
  };

  // Status mapping to label and classes
  const getStatusMeta = (status: string) => {
    switch (status) {
      case 'PENDING':
        return { label: 'Chưa kiểm tra', color: 'status-pending' };
      case 'WAITING_FOR_CHECK':
        return { label: 'Chờ kiểm tra', color: 'status-waiting' };
      case 'CHECKING':
        return { label: 'Đang kiểm tra', color: 'status-checking' };
      case 'CHECKED':
        return { label: 'Đã kiểm tra', color: 'status-checked' };
      case 'IN_PROGRESS':
        return { label: 'Đang sửa', color: 'status-inprogress' };
      case 'COMPLETED':
        return { label: 'Hoàn thành', color: 'status-completed' };
      case 'DELIVERED':
        return { label: 'Đã giao', color: 'status-delivered' };
      case 'CANCELLED':
        return { label: 'Đã trả', color: 'status-cancelled' };
      default:
        return { label: status, color: 'status-default' };
    }
  };

  // Filter orders
  const filteredOrders = orders.filter((order) => {
    const term = searchTerm.toLowerCase();
    const matchesSearch =
      order.orderCode.toLowerCase().includes(term) ||
      order.deviceName.toLowerCase().includes(term) ||
      order.customerName.toLowerCase().includes(term) ||
      (order.customerPhone && order.customerPhone.includes(term));

    const matchesStatus = statusFilter === 'ALL' || order.status === statusFilter;

    const matchesWarranty =
      warrantyFilter === 'ALL' ||
      (warrantyFilter === 'WARRANTY' && order.devices.some((d) => d.underWarranty)) ||
      (warrantyFilter === 'NO_WARRANTY' && order.devices.every((d) => !d.underWarranty));

    let matchesDate = true;
    if (dateFilter) {
      const orderDate = new Date(order.createdAt).toISOString().split('T')[0];
      matchesDate = orderDate === dateFilter;
    }

    return matchesSearch && matchesStatus && matchesWarranty && matchesDate;
  });

  // Displayed orders sliced by visibleCount for infinite scrolling
  const displayedOrders = filteredOrders.slice(0, visibleCount);

  // Handle infinite scroll event on orders list container
  const handleScrollList = (e: React.UIEvent<HTMLDivElement>) => {
    const { scrollTop, scrollHeight, clientHeight } = e.currentTarget;
    if (scrollTop + clientHeight >= scrollHeight - 60) {
      if (visibleCount < filteredOrders.length) {
        setVisibleCount((prev) => Math.min(prev + 20, filteredOrders.length));
      }
    }
  };

  // Form device list handlers
  const handleAddFormDevice = () => {
    setFormDevices([
      ...formDevices,
      { deviceName: '', deviceType: '', serialNumber: '', underWarranty: false, warrantyExpiry: '', description: '' },
    ]);
  };

  const handleRemoveFormDevice = (index: number) => {
    if (formDevices.length === 1) return;
    setFormDevices(formDevices.filter((_, i) => i !== index));
  };

  const handleDeviceChange = (index: number, key: keyof Omit<RepairDevice, 'id'>, val: any) => {
    const updated = [...formDevices];
    updated[index] = { ...updated[index], [key]: val };
    setFormDevices(updated);
  };

  // Open Create Modal
  const openCreateModal = () => {
    setCustomerName('');
    setCustomerPhone('');
    setFormDevices([
      { deviceName: '', deviceType: '', serialNumber: '', underWarranty: false, warrantyExpiry: '', description: '' },
    ]);
    setIsCreateModalOpen(true);
  };

  // Create Order API
  const handleCreateOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!customerName.trim()) {
      showToast('Vui lòng nhập tên khách hàng');
      return;
    }
    if (formDevices.some((d) => !d.deviceName.trim())) {
      showToast('Vui lòng điền tên thiết bị');
      return;
    }

    try {
      const response = await fetch('/api/v1/repair-orders', {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          customerName: customerName.trim(),
          customerPhone: customerPhone.trim() || undefined,
          devices: formDevices.map((d) => ({
            ...d,
            warrantyExpiry: d.underWarranty && d.warrantyExpiry ? d.warrantyExpiry : undefined,
          })),
        }),
      });

      if (response.ok) {
        showToast('Tạo đơn sửa chữa thành công!');
        setIsCreateModalOpen(false);
        fetchOrders();
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Không tạo được đơn'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi tạo đơn');
    }
  };

  // Open Edit Modal
  const openEditModal = (order: RepairOrder) => {
    setCustomerName(order.customerName);
    setCustomerPhone(order.customerPhone || '');
    setFormDevices(
      order.devices.map((d) => ({
        deviceName: d.deviceName,
        deviceType: d.deviceType || '',
        serialNumber: d.serialNumber || '',
        underWarranty: d.underWarranty,
        warrantyExpiry: d.warrantyExpiry ? d.warrantyExpiry.split('T')[0] : '',
        description: d.description || '',
        assignedToId: d.assignedTo?.id || undefined,
      }))
    );
    setIsEditModalOpen(true);
  };

  // Update Order API
  const handleUpdateOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrder) return;

    try {
      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          customerName: customerName.trim(),
          customerPhone: customerPhone.trim() || undefined,
          devices: formDevices.map((d) => ({
            ...d,
            warrantyExpiry: d.underWarranty && d.warrantyExpiry ? d.warrantyExpiry : undefined,
          })),
          note: 'Cập nhật từ Web Admin',
        }),
      });

      if (response.ok) {
        showToast('Cập nhật đơn sửa chữa thành công!');
        setIsEditModalOpen(false);
        // Refresh selected order details
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
        fetchOrders();
      } else {
        const errData = await response.json();
        showToast(`Lỗi: ${errData.message || 'Không cập nhật được đơn'}`);
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi cập nhật đơn');
    }
  };

  // Update Status API
  const handleUpdateStatus = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrder || !newStatus) return;

    try {
      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}/status`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          status: newStatus,
          note: statusNote.trim() || undefined,
        }),
      });

      if (response.ok) {
        showToast('Cập nhật trạng thái thành công!');
        setIsStatusModalOpen(false);
        setStatusNote('');
        // Refresh selected order and timeline
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
        fetchTimeline(selectedOrder.id);
        fetchOrders();
      } else {
        showToast('Cập nhật trạng thái thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi cập nhật trạng thái');
    }
  };

  // Open Assign Modal
  const openAssignModal = () => {
    if (!selectedOrder) return;
    setSelectedTechs(selectedOrder.assignees.map((a) => a.id));
    setAssignNote('');
    setIsAssignModalOpen(true);
  };

  // Assign Technicians API
  const handleAssignTechs = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrder) return;

    try {
      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}/assign`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          technicianIds: selectedTechs,
          note: assignNote.trim() || undefined,
        }),
      });

      if (response.ok) {
        showToast('Phân công nhân viên thành công!');
        setIsAssignModalOpen(false);
        // Refresh selected order and timeline
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
        fetchTimeline(selectedOrder.id);
        fetchOrders();
      } else {
        showToast('Phân công nhân viên thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi phân công');
    }
  };

  // Cancel Order API
  const handleCancelOrder = async () => {
    if (!selectedOrder) return;
    const reason = prompt('Nhập lý do hủy đơn:');
    if (reason === null) return; // User pressed Cancel

    try {
      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}/cancel?reason=${encodeURIComponent(reason)}`, {
        method: 'PATCH',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast('Hủy đơn hàng thành công!');
        // Refresh
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
        fetchTimeline(selectedOrder.id);
        fetchOrders();
      } else {
        showToast('Hủy đơn hàng thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi hủy đơn');
    }
  };

  // Delete Order API
  const handleDeleteOrder = async () => {
    if (!selectedOrder) return;
    if (!confirm(`Bạn có chắc chắn muốn xóa đơn sửa chữa ${selectedOrder.orderCode}?`)) return;

    try {
      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast('Xóa đơn hàng thành công!');
        setSelectedOrder(null);
        fetchOrders();
      } else {
        showToast('Xóa đơn hàng thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi xóa đơn');
    }
  };

  // Media file upload handler
  const handleUploadMedia = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!selectedOrder || !e.target.files || e.target.files.length === 0) return;
    const file = e.target.files[0];
    const isVideo = file.type.startsWith('video/') || /\.(mp4|mov|webm|avi|mkv|3gp)$/i.test(file.name);
    const isImage = file.type.startsWith('image/') || /\.(jpg|jpeg|png|gif|webp|heic|heif)$/i.test(file.name);
    const isDoc = file.type.startsWith('application/') || file.type.startsWith('text/') || /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|zip|rar|7z|csv)$/i.test(file.name);

    if (!isImage && !isVideo && !isDoc) {
      showToast('Chỉ hỗ trợ file hình ảnh, video hoặc tài liệu hợp lệ');
      return;
    }

    let mediaType: 'IMAGE' | 'VIDEO' | 'DOCUMENT' = 'IMAGE';
    if (isVideo) mediaType = 'VIDEO';
    else if (isDoc && !isImage) mediaType = 'DOCUMENT';

    setUploadingMedia(true);
    try {
      const formData = new FormData();
      formData.append('file', file);

      const response = await fetch(`/api/v1/repair-orders/${selectedOrder.id}/media?type=${mediaType}&caption=${encodeURIComponent(file.name)}`, {
        method: 'POST',
        headers: getAuthHeaders(), // Note: fetch multipart requires NO Content-Type header so browser inserts it with boundary
        body: formData,
      });

      if (response.ok) {
        showToast('Tải lên thành công!');
        // Refresh selected order
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
      } else {
        showToast('Tải lên thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi tải lên phương tiện');
    } finally {
      setUploadingMedia(false);
    }
  };

  // Delete Media API
  const handleDeleteMedia = async (mediaId: string) => {
    if (!selectedOrder) return;
    if (!confirm('Bạn muốn xóa tệp đính kèm này?')) return;

    try {
      const response = await fetch(`/api/v1/repair-orders/media/${mediaId}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast('Đã xóa phương tiện!');
        // Refresh selected order
        const refreshedOrder = await fetch(`/api/v1/repair-orders/${selectedOrder.id}`, {
          headers: getAuthHeaders(),
        });
        if (refreshedOrder.ok) {
          const result = await refreshedOrder.json();
          if (result?.data) setSelectedOrder(result.data);
        }
      } else {
        showToast('Xóa phương tiện thất bại');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi xóa phương tiện');
    }
  };

  return (
    <div className="orders-container">
      {/* 2-Column Layout: Left Side List, Right Side Detail */}
      <div className="orders-layout">
        {/* Left Column: Filter + List */}
        <div className="orders-list-panel">
          {/* Header Stats */}
          <div className="orders-summary-bar">
            <div className="summary-stat">
              <span className="summary-val">{orders.length}</span>
              <span className="summary-lbl">Tổng số đơn</span>
            </div>
            <div className="summary-stat">
              <span className="summary-val status-color-pending">
                {orders.filter((o) => o.status === 'PENDING').length}
              </span>
              <span className="summary-lbl">Chưa kiểm tra</span>
            </div>
            <div className="summary-stat">
              <span className="summary-val status-color-inprogress">
                {orders.filter((o) => o.status === 'IN_PROGRESS').length}
              </span>
              <span className="summary-lbl">Đang sửa</span>
            </div>
            <div className="summary-stat">
              <span className="summary-val status-color-completed">
                {orders.filter((o) => o.status === 'COMPLETED' || o.status === 'DELIVERED').length}
              </span>
              <span className="summary-lbl">Hoàn thành</span>
            </div>
          </div>

          <OrderListPanel
            searchTerm={searchTerm}
            setSearchTerm={setSearchTerm}
            statusFilter={statusFilter}
            setStatusFilter={setStatusFilter}
            warrantyFilter={warrantyFilter}
            setWarrantyFilter={setWarrantyFilter}
            dateFilter={dateFilter}
            setDateFilter={setDateFilter}
            setVisibleCount={setVisibleCount}
            openCreateModal={openCreateModal}
            listWrapperRef={listWrapperRef}
            handleScrollList={handleScrollList}
            loading={loading}
            displayedOrders={displayedOrders}
            filteredOrders={filteredOrders}
            selectedOrder={selectedOrder}
            handleSelectOrder={handleSelectOrder}
            getStatusMeta={getStatusMeta}
            visibleCount={visibleCount}
          />
        </div>

        {/* Right Column: Detail Pane */}
        <div className="orders-detail-panel">
          {selectedOrder ? (
            <OrderDetailPanel
              selectedOrder={selectedOrder}
              isManager={isManager}
              openEditModal={openEditModal}
              handleDeleteOrder={handleDeleteOrder}
              getStatusMeta={getStatusMeta}
              setNewStatus={setNewStatus}
              setIsStatusModalOpen={setIsStatusModalOpen}
              openAssignModal={openAssignModal}
              handleUploadMedia={handleUploadMedia}
              uploadingMedia={uploadingMedia}
              handleOpenMediaPreview={handleOpenMediaPreview}
              handleDeleteMedia={handleDeleteMedia}
              loadingTimeline={loadingTimeline}
              timeline={timeline}
              handleCancelOrder={handleCancelOrder}
            />
          ) : (
            <div className="detail-empty-state">
              <Wrench size={48} className="empty-icon" />
              <h3>Chọn một đơn sửa chữa</h3>
              <p>Chọn đơn sửa chữa từ danh sách bên trái để xem thông tin chi tiết, timeline vòng đời và tệp đính kèm.</p>
            </div>
          )}
        </div>
      </div>

      {/* CREATE MODAL */}
      {isCreateModalOpen && (
        <div className="orders-modal-overlay">
          <div className="orders-modal-card large">
            <div className="modal-header">
              <h3>Tạo đơn sửa chữa mới</h3>
              <button className="close-modal-btn" onClick={() => setIsCreateModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleCreateOrder} className="modal-form">
              <div className="form-section-title">Thông tin khách hàng</div>
              <div className="form-row-grid">
                <div className="form-group">
                  <label>Tên khách hàng *</label>
                  <input
                    type="text"
                    required
                    value={customerName}
                    onChange={(e) => setCustomerName(e.target.value)}
                    placeholder="Nguyễn Văn A"
                  />
                </div>
                <div className="form-group">
                  <label>Số điện thoại</label>
                  <input
                    type="text"
                    value={customerPhone}
                    onChange={(e) => setCustomerPhone(e.target.value)}
                    placeholder="0901234567"
                  />
                </div>
              </div>

              <div className="form-section-title flex-header">
                <span>Thiết bị sửa chữa ({formDevices.length})</span>
                <button type="button" className="btn-add-device-row" onClick={handleAddFormDevice}>
                  <Plus size={14} />
                  Thêm thiết bị
                </button>
              </div>

              <div className="modal-devices-scroll">
                {formDevices.map((device, idx) => (
                  <div key={idx} className="device-form-item">
                    <div className="device-item-header">
                      <span>Thiết bị #{idx + 1}</span>
                      {formDevices.length > 1 && (
                        <button type="button" className="btn-remove-device" onClick={() => handleRemoveFormDevice(idx)}>
                          <Trash2 size={13} /> Xóa
                        </button>
                      )}
                    </div>
                    <div className="form-row-grid">
                      <div className="form-group">
                        <label>Tên thiết bị *</label>
                        <input
                          type="text"
                          required
                          value={device.deviceName}
                          onChange={(e) => handleDeviceChange(idx, 'deviceName', e.target.value)}
                          placeholder="Biến tần Delta VFD-M"
                        />
                      </div>
                      <div className="form-group">
                        <label>Model / Loại thiết bị</label>
                        <input
                          type="text"
                          value={device.deviceType}
                          onChange={(e) => handleDeviceChange(idx, 'deviceType', e.target.value)}
                          placeholder="VFD015M21A"
                        />
                      </div>
                      <div className="form-group">
                        <label>Số Serial</label>
                        <input
                          type="text"
                          value={device.serialNumber}
                          onChange={(e) => handleDeviceChange(idx, 'serialNumber', e.target.value)}
                          placeholder="SN12345678"
                        />
                      </div>
                    </div>
                    <div className="form-row-grid items-center">
                      <div className="form-group-checkbox">
                        <input
                          type="checkbox"
                          id={`warranty-${idx}`}
                          checked={device.underWarranty}
                          onChange={(e) => handleDeviceChange(idx, 'underWarranty', e.target.checked)}
                        />
                        <label htmlFor={`warranty-${idx}`}>Hỗ trợ bảo hành</label>
                      </div>
                      {device.underWarranty && (
                        <div className="form-group">
                          <label>Hạn bảo hành</label>
                          <input
                            type="date"
                            value={device.warrantyExpiry}
                            onChange={(e) => handleDeviceChange(idx, 'warrantyExpiry', e.target.value)}
                          />
                        </div>
                      )}
                    </div>
                    <div className="form-group">
                      <label>Mô tả lỗi / Yêu cầu sửa chữa</label>
                      <textarea
                        value={device.description}
                        onChange={(e) => handleDeviceChange(idx, 'description', e.target.value)}
                        placeholder="Thiết bị báo lỗi OC khi tăng tốc..."
                        rows={2}
                      />
                    </div>
                  </div>
                ))}
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsCreateModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Tạo đơn hàng
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* EDIT MODAL */}
      {isEditModalOpen && (
        <div className="orders-modal-overlay">
          <div className="orders-modal-card large">
            <div className="modal-header">
              <h3>Chỉnh sửa đơn sửa chữa</h3>
              <button className="close-modal-btn" onClick={() => setIsEditModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleUpdateOrder} className="modal-form">
              <div className="form-section-title">Thông tin khách hàng</div>
              <div className="form-row-grid">
                <div className="form-group">
                  <label>Tên khách hàng *</label>
                  <input
                    type="text"
                    required
                    value={customerName}
                    onChange={(e) => setCustomerName(e.target.value)}
                    placeholder="Nguyễn Văn A"
                  />
                </div>
                <div className="form-group">
                  <label>Số điện thoại</label>
                  <input
                    type="text"
                    value={customerPhone}
                    onChange={(e) => setCustomerPhone(e.target.value)}
                    placeholder="0901234567"
                  />
                </div>
              </div>

              <div className="form-section-title flex-header">
                <span>Thiết bị sửa chữa ({formDevices.length})</span>
                <button type="button" className="btn-add-device-row" onClick={handleAddFormDevice}>
                  <Plus size={14} />
                  Thêm thiết bị
                </button>
              </div>

              <div className="modal-devices-scroll">
                {formDevices.map((device, idx) => (
                  <div key={idx} className="device-form-item">
                    <div className="device-item-header">
                      <span>Thiết bị #{idx + 1}</span>
                      {formDevices.length > 1 && (
                        <button type="button" className="btn-remove-device" onClick={() => handleRemoveFormDevice(idx)}>
                          <Trash2 size={13} /> Xóa
                        </button>
                      )}
                    </div>
                    <div className="form-row-grid">
                      <div className="form-group">
                        <label>Tên thiết bị *</label>
                        <input
                          type="text"
                          required
                          value={device.deviceName}
                          onChange={(e) => handleDeviceChange(idx, 'deviceName', e.target.value)}
                          placeholder="Biến tần Delta VFD-M"
                        />
                      </div>
                      <div className="form-group">
                        <label>Model / Loại thiết bị</label>
                        <input
                          type="text"
                          value={device.deviceType}
                          onChange={(e) => handleDeviceChange(idx, 'deviceType', e.target.value)}
                          placeholder="VFD015M21A"
                        />
                      </div>
                      <div className="form-group">
                        <label>Số Serial</label>
                        <input
                          type="text"
                          value={device.serialNumber}
                          onChange={(e) => handleDeviceChange(idx, 'serialNumber', e.target.value)}
                          placeholder="SN12345678"
                        />
                      </div>
                    </div>
                    <div className="form-row-grid items-center">
                      <div className="form-group-checkbox">
                        <input
                          type="checkbox"
                          id={`edit-warranty-${idx}`}
                          checked={device.underWarranty}
                          onChange={(e) => handleDeviceChange(idx, 'underWarranty', e.target.checked)}
                        />
                        <label htmlFor={`edit-warranty-${idx}`}>Hỗ trợ bảo hành</label>
                      </div>
                      {device.underWarranty && (
                        <div className="form-group">
                          <label>Hạn bảo hành</label>
                          <input
                            type="date"
                            value={device.warrantyExpiry}
                            onChange={(e) => handleDeviceChange(idx, 'warrantyExpiry', e.target.value)}
                          />
                        </div>
                      )}
                    </div>
                    <div className="form-group">
                      <label>Mô tả lỗi / Yêu cầu sửa chữa</label>
                      <textarea
                        value={device.description}
                        onChange={(e) => handleDeviceChange(idx, 'description', e.target.value)}
                        placeholder="Thiết bị báo lỗi OC..."
                        rows={2}
                      />
                    </div>
                  </div>
                ))}
              </div>

              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsEditModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Lưu thay đổi
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* UPDATE STATUS MODAL */}
      {isStatusModalOpen && (
        <div className="orders-modal-overlay">
          <div className="orders-modal-card small">
            <div className="modal-header">
              <h3>Cập nhật trạng thái đơn</h3>
              <button className="close-modal-btn" onClick={() => setIsStatusModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleUpdateStatus} className="modal-form">
              <div className="form-group">
                <label>Trạng thái mới *</label>
                <select value={newStatus} onChange={(e) => setNewStatus(e.target.value)} required>
                  <option value="PENDING">Chưa kiểm tra</option>
                  <option value="WAITING_FOR_CHECK">Chờ kiểm tra</option>
                  <option value="CHECKING">Đang kiểm tra</option>
                  <option value="CHECKED">Đã kiểm tra</option>
                  <option value="IN_PROGRESS">Đang sửa</option>
                  <option value="COMPLETED">Hoàn thành (Chờ giao)</option>
                  <option value="DELIVERED">Đã bàn giao khách hàng</option>
                  <option value="CANCELLED">Đã trả</option>
                </select>
              </div>
              <div className="form-group">
                <label>Ghi chú cập nhật</label>
                <textarea
                  value={statusNote}
                  onChange={(e) => setStatusNote(e.target.value)}
                  placeholder="Ghi chú chi tiết công việc hoặc lỗi phát hiện..."
                  rows={3}
                />
              </div>
              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsStatusModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Cập nhật
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ASSIGN TECHNICIANS MODAL */}
      {isAssignModalOpen && (
        <div className="orders-modal-overlay">
          <div className="orders-modal-card small">
            <div className="modal-header">
              <h3>Phân công kỹ thuật viên</h3>
              <button className="close-modal-btn" onClick={() => setIsAssignModalOpen(false)}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleAssignTechs} className="modal-form">
              <div className="form-group">
                <label>Chọn kỹ thuật viên (Chọn nhiều)</label>
                <div className="tech-checkbox-list">
                  {employees
                    .filter((emp) => emp.role === 'TECHNICIAN' || emp.role === 'ADMIN' || emp.role === 'SUPER_ADMIN')
                    .map((emp) => {
                      const isChecked = selectedTechs.includes(emp.id);
                      return (
                        <div key={emp.id} className="tech-checkbox-row">
                          <input
                            type="checkbox"
                            id={`tech-${emp.id}`}
                            checked={isChecked}
                            onChange={(e) => {
                              if (e.target.checked) {
                                setSelectedTechs([...selectedTechs, emp.id]);
                              } else {
                                setSelectedTechs(selectedTechs.filter((id) => id !== emp.id));
                              }
                            }}
                          />
                          <label htmlFor={`tech-${emp.id}`}>
                            {emp.fullName} ({emp.employeeCode || emp.username})
                          </label>
                        </div>
                      );
                    })}
                </div>
              </div>
              <div className="form-group">
                <label>Ghi chú phân công</label>
                <textarea
                  value={assignNote}
                  onChange={(e) => setAssignNote(e.target.value)}
                  placeholder="Yêu cầu cụ thể cho nhân viên..."
                  rows={2}
                />
              </div>
              <div className="modal-actions-footer">
                <button type="button" className="btn-cancel" onClick={() => setIsAssignModalOpen(false)}>
                  Hủy
                </button>
                <button type="submit" className="btn-submit">
                  Lưu phân công
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Media Preview Lightbox & Video Player Modal */}
      {selectedOrder && selectedOrder.images && selectedOrder.images.length > 0 && (
        <MediaPreviewModal
          isOpen={isPreviewModalOpen}
          onClose={() => setIsPreviewModalOpen(false)}
          mediaList={selectedOrder.images}
          currentIndex={previewMediaIndex}
          onIndexChange={setPreviewMediaIndex}
          onDelete={(id) => {
            handleDeleteMedia(id);
            setIsPreviewModalOpen(false);
          }}
        />
      )}
    </div>
  );
};

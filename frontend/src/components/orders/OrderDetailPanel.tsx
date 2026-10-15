import { usePermissionCheck } from '../../utils/permissionContext';
import React, { useState, useEffect } from 'react';
import {
  Edit2,
  Trash2,
  UserPlus,
  Paperclip,
  X,
  Play,
  FileText,
  User,
  AlertTriangle,
  CheckCircle2,
  Link2,
  RefreshCw,
} from 'lucide-react';
import type { RepairOrder, TimelineEvent } from '../../types/orders';
import type { UserInfo } from '../../mockData';
import type { Customer } from '../../types/customer';
import { hasPermission } from '../../utils/permissions';
import { getCustomers, linkRepairOrderCustomer } from '../../utils/customerApi';

interface OrderDetailPanelProps {
  selectedOrder: RepairOrder;
  isManager: boolean;
  currentUser?: UserInfo | null;
  openEditModal: (order: RepairOrder) => void;
  handleDeleteOrder: () => void;
  getStatusMeta: (status: string) => { label: string; color: string };
  setNewStatus: (status: string) => void;
  setIsStatusModalOpen: (val: boolean) => void;
  openAssignModal: () => void;
  handleUploadMedia: (e: React.ChangeEvent<HTMLInputElement>) => void;
  uploadingMedia: boolean;
  handleOpenMediaPreview: (index: number) => void;
  handleDeleteMedia: (mediaId: string) => void;
  loadingTimeline: boolean;
  timeline: TimelineEvent[];
  handleCancelOrder?: () => void;
  onClose?: () => void;
  onRefreshOrder?: () => void;
  showToast?: (msg: string) => void;
}

export const OrderDetailPanel: React.FC<OrderDetailPanelProps> = ({
  selectedOrder,
  currentUser,
  openEditModal,
  handleDeleteOrder,
  getStatusMeta,
  setNewStatus,
  setIsStatusModalOpen,
  openAssignModal,
  handleUploadMedia,
  uploadingMedia,
  handleOpenMediaPreview,
  handleDeleteMedia,
  loadingTimeline,
  timeline,
  handleCancelOrder,
  onClose,
  onRefreshOrder,
  showToast,
}) => {
  const canAction = usePermissionCheck();
  const statusMeta = getStatusMeta(selectedOrder.status);
  const canManageCustomers = hasPermission(currentUser ?? null, 'CUSTOMER_MANAGE');

  // Customer linking modal state
  const [isLinkModalOpen, setIsLinkModalOpen] = useState(false);
  const [searchCustKeyword, setSearchCustKeyword] = useState('');
  const [custSearchResults, setCustSearchResults] = useState<Customer[]>([]);
  const [searchingCust, setSearchingCust] = useState(false);
  const [targetCustomer, setTargetCustomer] = useState<Customer | null>(null);
  const [linkReason, setLinkReason] = useState('');
  const [linking, setLinking] = useState(false);
  const [linkError, setLinkError] = useState('');

  useEffect(() => {
    if (!isLinkModalOpen) return;
    const timer = setTimeout(async () => {
      setSearchingCust(true);
      const res = await getCustomers({
        keyword: searchCustKeyword,
        active: true,
        size: 10,
      });
      if (res.success && res.data) {
        setCustSearchResults(res.data.content);
      }
      setSearchingCust(false);
    }, 300);
    return () => clearTimeout(timer);
  }, [isLinkModalOpen, searchCustKeyword]);

  const handleOpenLinkModal = () => {
    setSearchCustKeyword('');
    setTargetCustomer(null);
    setLinkReason('');
    setLinkError('');
    setIsLinkModalOpen(true);
  };

  const handleConfirmLink = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!targetCustomer) {
      setLinkError('Vui lòng chọn khách hàng');
      return;
    }
    if (!linkReason.trim()) {
      setLinkError('Vui lòng nhập lý do gán/chuyển hồ sơ');
      return;
    }
    setLinking(true);
    setLinkError('');
    const res = await linkRepairOrderCustomer(selectedOrder.id, targetCustomer.id, linkReason.trim());
    setLinking(false);
    if (res.success) {
      showToast?.('Gán hồ sơ khách hàng thành công!');
      setIsLinkModalOpen(false);
      onRefreshOrder?.();
    } else {
      setLinkError(res.message || 'Lỗi khi gán hồ sơ');
    }
  };


  return (
    <div className="detail-scroller">
      <div className="detail-header">
        <div className="detail-title-row">
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: '12px' }}>
            {onClose && (
              <button
                type="button"
                className="detail-close-btn"
                onClick={onClose}
                title="Đóng chi tiết"
                aria-label="Đóng chi tiết"
              >
                <X size={18} />
              </button>
            )}
            <div>
              <span className="detail-order-code">{selectedOrder.orderCode}</span>
              <h2 className="detail-device-title">{selectedOrder.deviceName}</h2>
            </div>
          </div>
          <div className="detail-actions">
            {canAction('REPAIR_UPDATE') && (<button  className="btn-action-outline" onClick={() => openEditModal(selectedOrder)}>
              <Edit2 size={14} />
              Sửa
            </button>) }
            {hasPermission(currentUser ?? null, 'REPAIR_DELETE') && (
              (canAction('REPAIR_DELETE') && (<button className="btn-action-outline danger" onClick={handleDeleteOrder}>
                <Trash2 size={14} />
                Xóa
              </button>))
            )}
          </div>
        </div>

        <div className="status-timeline-bar">
          <span className={`status-badge lg ${statusMeta.color}`}>
            {statusMeta.label}
          </span>
          {canAction('REPAIR_STATUS_UPDATE') && (<button
            className="btn-update-status"

            onClick={() => {
              setNewStatus(selectedOrder.status);
              setIsStatusModalOpen(true);
            }}
          >
            Cập nhật trạng thái
          </button>) }
        </div>
      </div>

      <div className="detail-content-section">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
          <h4 className="section-title" style={{ margin: 0 }}>Thông tin khách hàng</h4>
          {selectedOrder.customerId ? (
            <span className="customer-badge-linked">
              <CheckCircle2 size={12} />
              Đã liên kết hồ sơ
            </span>
          ) : (
            <span className="customer-badge-unlinked">
              <AlertTriangle size={12} />
              Chưa liên kết hồ sơ
            </span>
          )}
        </div>
        <div className="detail-info-card">
          <div className="info-row">
            <span className="info-lbl">Khách hàng:</span>
            <span className="info-val">{selectedOrder.customerName}</span>
          </div>
          {selectedOrder.customerPhone && (
            <div className="info-row">
              <span className="info-lbl">Số điện thoại:</span>
              <span className="info-val">{selectedOrder.customerPhone}</span>
            </div>
          )}
          <div className="info-row">
            <span className="info-lbl">Ngày tạo:</span>
            <span className="info-val">
              {new Date(selectedOrder.createdAt).toLocaleDateString('vi-VN', {
                day: '2-digit',
                month: '2-digit',
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              })}
            </span>
          </div>

          {canManageCustomers && (
            <div style={{ marginTop: '10px', paddingTop: '10px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end' }}>
              {(selectedOrder.customerId ? canAction('CUSTOMER_TRANSFER') : canAction('CUSTOMER_ASSIGN')) && (<button
                type="button"
                className="btn-action-outline"
                style={{ fontSize: '0.8rem', padding: '4px 10px', display: 'inline-flex', alignItems: 'center', gap: '5px' }}
                onClick={handleOpenLinkModal}
              >
                <Link2 size={13} />
                {selectedOrder.customerId ? 'Chuyển hồ sơ khách hàng' : 'Liên kết hồ sơ khách hàng'}
              </button>) }
            </div>
          )}
        </div>
      </div>

      <div className="detail-content-section">
        <div className="section-header-row">
          <h4 className="section-title">Thiết bị trong đơn ({selectedOrder.devices.length})</h4>
        </div>
        <div className="devices-detail-list">
          {selectedOrder.devices.map((device, idx) => (
            <div key={device.id || idx} className="device-detail-card">
              <div className="device-card-header">
                <span className="device-name">{device.deviceName}</span>
                {device.underWarranty ? (
                  <span className="warranty-tag true">Bảo hành</span>
                ) : (
                  <span className="warranty-tag false">Hết/Không BH</span>
                )}
              </div>
              <div className="device-card-body">
                {device.deviceType && (
                  <div className="device-body-item">
                    <span className="lbl">Loại:</span> <span>{device.deviceType}</span>
                  </div>
                )}
                {device.serialNumber && (
                  <div className="device-body-item">
                    <span className="lbl">Serial:</span> <span>{device.serialNumber}</span>
                  </div>
                )}
                {device.underWarranty && device.warrantyExpiry && (
                  <div className="device-body-item">
                    <span className="lbl">Hạn bảo hành:</span>{' '}
                    <span>{new Date(device.warrantyExpiry).toLocaleDateString('vi-VN')}</span>
                  </div>
                )}
                {device.description && (
                  <div className="device-body-item full">
                    <span className="lbl">Mô tả lỗi:</span> <p>{device.description}</p>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="detail-content-section">
        <div className="section-header-row">
          <h4 className="section-title">Kỹ thuật viên sửa chữa</h4>
          {canAction('REPAIR_ASSIGN') && (<button  className="btn-action-outline sm" onClick={openAssignModal}>
            <UserPlus size={14} />
            Phân công
          </button>) }
        </div>
        <div className="detail-assignees-card">
          {selectedOrder.assignees.length > 0 ? (
            <div className="assignees-list">
              {selectedOrder.assignees.map((tech) => (
                <div key={tech.id} className="tech-badge-item">
                  <User size={14} />
                  <span>{tech.fullName}</span>
                </div>
              ))}
            </div>
          ) : (
            <p className="no-data-text">Chưa phân công kỹ thuật viên nào cho đơn hàng này.</p>
          )}
        </div>
      </div>

      {/* Attachments Section */}
      <div className="detail-content-section">
        <div className="section-header-row">
          <h4 className="section-title">Phương tiện & Tài liệu đính kèm</h4>
          <div className="upload-btn-wrapper">
            {canAction('REPAIR_MEDIA_UPLOAD') && (<button className="btn-action-outline sm">
              <Paperclip size={14} />
              Đính kèm file
            </button>) }
            {canAction('REPAIR_MEDIA_UPLOAD') && (<input
              type="file"

              accept="image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar,.csv"
              onChange={handleUploadMedia}
            />) }
          </div>
        </div>
        <div className="media-attachments-card">
          {uploadingMedia && <div className="media-uploading">Đang tải lên tệp đính kèm...</div>}
          {selectedOrder.images && selectedOrder.images.length > 0 ? (
            <div className="media-grid">
              {selectedOrder.images.map((media, idx) => {
                const isVid = media.mediaType === 'VIDEO' || /\.(mp4|mov|webm|avi|mkv|3gp)$/i.test(media.imageUrl);
                const isDoc = media.mediaType === 'DOCUMENT' || /\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|zip|rar|7z|csv)$/i.test(media.imageUrl);
                return (
                  <div
                    key={media.id || idx}
                    className="media-item-wrapper"
                    onClick={() => handleOpenMediaPreview(idx)}
                    title="Click để xem chi tiết / phát video / phóng to ảnh"
                  >
                    {canAction('REPAIR_MEDIA_DELETE') && (<button
                      className="delete-media-btn"

                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeleteMedia(media.id);
                      }}
                      title="Xóa tệp đính kèm"
                    >
                      <X size={12} />
                    </button>) }
                    {isVid ? (
                      <div className="media-video-placeholder">
                        <div className="media-overlay-icon">
                          <Play size={24} className="play-icon" />
                        </div>
                        <span className="media-type-badge vid">VIDEO</span>
                        <video src={media.imageUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                      </div>
                    ) : isDoc ? (
                      <div className="media-doc-placeholder">
                        <FileText size={32} className="doc-grid-icon" />
                        <span className="media-type-badge doc">DOC</span>
                      </div>
                    ) : (
                      <div className="media-image-placeholder">
                        <img src={media.imageUrl} alt={media.caption || 'Media'} />
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="no-data-text">Chưa có ảnh/video/tài liệu đính kèm.</p>
          )}
        </div>
      </div>

      {/* Timeline Event History */}
      {canAction('REPAIR_TIMELINE_VIEW') && (<div className="detail-content-section">
        <h4 className="section-title">Nhật ký xử lý đơn hàng</h4>
        <div className="timeline-flow-card">
          {loadingTimeline ? (
            <p className="no-data-text">Đang tải nhật ký...</p>
          ) : timeline.length > 0 ? (
            <div className="timeline-events-list">
              {timeline.map((event, idx) => {
                const statusMeta = getStatusMeta(event.status);
                return (
                  <div key={event.id || idx} className="timeline-event-item">
                    <div className="event-marker" />
                    <div className="event-content">
                      <div className="event-header-row">
                        <span className={`status-badge sm ${statusMeta.color}`}>
                          {statusMeta.label}
                        </span>
                        <span className="event-time">
                          {new Date(event.changedAt).toLocaleString('vi-VN')}
                        </span>
                      </div>
                      <div className="event-author">Thực hiện bởi: {event.changedByName}</div>
                      {event.note && <div className="event-note">{event.note}</div>}
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <p className="no-data-text">Chưa có nhật ký thay đổi nào.</p>
          )}
        </div>
      </div>) }

      {handleCancelOrder && selectedOrder.status !== 'CANCELLED' && selectedOrder.status !== 'DELIVERED' && (
        <div className="cancel-order-footer">
          {canAction('REPAIR_CANCEL') && (<button  className="btn-cancel-order" onClick={handleCancelOrder}>
            <AlertTriangle size={14} />
            Hủy đơn sửa chữa
          </button>) }
        </div>
      )}

      {/* Modal: Gán / Chuyển hồ sơ khách hàng */}
      {isLinkModalOpen && (
        <div className="orders-modal-overlay">
          <div className="orders-modal-card" style={{ maxWidth: '520px' }}>
            <div className="modal-header">
              <h3>
                <Link2 size={18} />
                {selectedOrder.customerId ? 'Chuyển hồ sơ khách hàng' : 'Liên kết hồ sơ khách hàng'}
              </h3>
              <button
                type="button"
                className="close-modal-btn"
                onClick={() => !linking && setIsLinkModalOpen(false)}
              >
                <X size={18} />
              </button>
            </div>

            {(selectedOrder.customerId ? canAction('CUSTOMER_TRANSFER') : canAction('CUSTOMER_ASSIGN')) && (<form onSubmit={handleConfirmLink} className="modal-form">
              <div style={{ fontSize: '0.85rem', color: '#64748b', marginBottom: '8px' }}>
                Đơn hàng: <strong>{selectedOrder.orderCode}</strong> — Khách hiện tại:{' '}
                <strong>{selectedOrder.customerName}</strong>
              </div>

              {linkError && (
                <div style={{ padding: '8px 12px', background: '#fee2e2', color: '#dc2626', borderRadius: '6px', fontSize: '0.82rem' }}>
                  {linkError}
                </div>
              )}

              <div className="form-group">
                <label>Tìm chọn khách hàng (Hồ sơ đang hoạt động) *</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type="text"
                    placeholder="Gõ tên, mã khách, SĐT để tìm..."
                    value={searchCustKeyword}
                    onChange={(e) => setSearchCustKeyword(e.target.value)}
                  />
                  {searchingCust && (
                    <RefreshCw size={14} className="animate-spin" style={{ position: 'absolute', right: 10, top: 12, color: '#94a3b8' }} />
                  )}
                </div>

                {targetCustomer ? (
                  <div className="customer-selected-card" style={{ marginTop: '8px' }}>
                    <div className="customer-selected-info">
                      <div className="customer-selected-name">{targetCustomer.customerName}</div>
                      <div className="customer-selected-meta">
                        <span>Mã: {targetCustomer.customerCode.slice(0, 15)}...</span>
                        {targetCustomer.phone && <span>SĐT: {targetCustomer.phone}</span>}
                      </div>
                    </div>
                    <button
                      type="button"
                      className="btn-icon-action"
                      onClick={() => setTargetCustomer(null)}
                      title="Bỏ chọn"
                    >
                      <X size={16} />
                    </button>
                  </div>
                ) : (
                  <div className="customer-picker-results" style={{ marginTop: '4px' }}>
                    {custSearchResults.length === 0 ? (
                      <div style={{ padding: '12px', textAlign: 'center', color: '#94a3b8', fontSize: '0.82rem' }}>
                        {searchingCust ? 'Đang tìm kiếm...' : 'Nhập từ khóa để tìm khách hàng'}
                      </div>
                    ) : (
                      custSearchResults.map((c) => (
                        <div
                          key={c.id}
                          className="customer-picker-item"
                          onClick={() => setTargetCustomer(c)}
                        >
                          <div>
                            <div style={{ fontWeight: 600 }}>{c.customerName}</div>
                            <div style={{ fontSize: '0.75rem', color: '#64748b' }}>
                              {c.customerCode.slice(0, 15)}... {c.phone ? `• ${c.phone}` : ''}
                            </div>
                          </div>
                          <span style={{ fontSize: '0.75rem', color: '#2563eb' }}>Chọn</span>
                        </div>
                      ))
                    )}
                  </div>
                )}
              </div>

              <div className="form-group">
                <label>Lý do gán / chuyển hồ sơ * (Tối đa 500 ký tự)</label>
                <textarea
                  rows={3}
                  required
                  maxLength={500}
                  placeholder="VD: Đã xác minh thông tin khách hàng và số điện thoại liên hệ"
                  value={linkReason}
                  onChange={(e) => setLinkReason(e.target.value)}
                />
              </div>

              <div className="modal-actions" style={{ marginTop: '16px' }}>
                <button
                  type="button"
                  className="btn-cancel"
                  disabled={linking}
                  onClick={() => setIsLinkModalOpen(false)}
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  className="btn-submit"
                  disabled={linking || !targetCustomer || !linkReason.trim()}
                >
                  {linking && <RefreshCw size={14} className="animate-spin" />}
                  Xác nhận liên kết
                </button>
              </div>
            </form>) }
          </div>
        </div>
      )}
    </div>
  );
};

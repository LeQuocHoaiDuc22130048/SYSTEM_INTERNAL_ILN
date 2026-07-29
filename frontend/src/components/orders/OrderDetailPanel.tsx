import React from 'react';
import { Edit2, Trash2, UserPlus, Paperclip, X, Play, FileText, User, AlertTriangle } from 'lucide-react';
import type { RepairOrder, TimelineEvent } from '../../types/orders';

interface OrderDetailPanelProps {
  selectedOrder: RepairOrder;
  isManager: boolean;
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
}

export const OrderDetailPanel: React.FC<OrderDetailPanelProps> = ({
  selectedOrder,
  isManager,
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
}) => {
  const statusMeta = getStatusMeta(selectedOrder.status);


  return (
    <div className="detail-scroller">
      <div className="detail-header">
        <div className="detail-title-row">
          <div>
            <span className="detail-order-code">{selectedOrder.orderCode}</span>
            <h2 className="detail-device-title">{selectedOrder.deviceName}</h2>
          </div>
          <div className="detail-actions">
            <button className="btn-action-outline" onClick={() => openEditModal(selectedOrder)}>
              <Edit2 size={14} />
              Sửa
            </button>
            {isManager && (
              <button className="btn-action-outline danger" onClick={handleDeleteOrder}>
                <Trash2 size={14} />
                Xóa
              </button>
            )}
          </div>
        </div>

        <div className="status-timeline-bar">
          <span className={`status-badge lg ${statusMeta.color}`}>
            {statusMeta.label}
          </span>
          <button
            className="btn-update-status"
            onClick={() => {
              setNewStatus(selectedOrder.status);
              setIsStatusModalOpen(true);
            }}
          >
            Cập nhật trạng thái
          </button>
        </div>
      </div>

      <div className="detail-content-section">
        <h4 className="section-title">Thông tin khách hàng</h4>
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
          <button className="btn-action-outline sm" onClick={openAssignModal}>
            <UserPlus size={14} />
            Phân công
          </button>
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
            <button className="btn-action-outline sm">
              <Paperclip size={14} />
              Đính kèm file
            </button>
            <input
              type="file"
              accept="image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.zip,.rar,.csv"
              onChange={handleUploadMedia}
            />
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
                    <button
                      className="delete-media-btn"
                      onClick={(e) => {
                        e.stopPropagation();
                        handleDeleteMedia(media.id);
                      }}
                      title="Xóa tệp đính kèm"
                    >
                      <X size={12} />
                    </button>
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
      <div className="detail-content-section">
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
      </div>

      {handleCancelOrder && selectedOrder.status !== 'CANCELLED' && selectedOrder.status !== 'DELIVERED' && (
        <div className="cancel-order-footer">
          <button className="btn-cancel-order" onClick={handleCancelOrder}>
            <AlertTriangle size={14} />
            Hủy đơn sửa chữa
          </button>
        </div>
      )}
    </div>
  );
};

import React, { useState, useEffect, useCallback } from 'react';
import {
  Send,
  RefreshCw,
  Image,
  MessageSquare,
  Clock,
} from 'lucide-react';
import type { CustomerUpdateResponse, CustomerMediaResponse } from '../../types/customer';
import type { RepairMedia } from '../../types/orders';
import {
  getPublishedCustomerUpdates,
  publishCustomerUpdate,
  getPublishedCustomerMedia,
  publishCustomerMedia,
} from '../../utils/portalApi';
import './OrderCustomerPublishSection.css';

interface OrderCustomerPublishSectionProps {
  orderId: string;
  orderCode: string;
  canPublish: boolean;
  orderImages?: RepairMedia[];
  showToast?: (msg: string) => void;
}

export const OrderCustomerPublishSection: React.FC<OrderCustomerPublishSectionProps> = ({
  orderId,
  orderCode,
  canPublish,
  orderImages = [],
  showToast,
}) => {
  const [updates, setUpdates] = useState<CustomerUpdateResponse[]>([]);
  const [mediaList, setMediaList] = useState<CustomerMediaResponse[]>([]);
  const [loading, setLoading] = useState(false);

  // Publish Update Modal
  const [isUpdateModalOpen, setIsUpdateModalOpen] = useState(false);
  const [updateTitle, setUpdateTitle] = useState('');
  const [updateContent, setUpdateContent] = useState('');
  const [submittingUpdate, setSubmittingUpdate] = useState(false);

  // Publish Media Modal
  const [isMediaModalOpen, setIsMediaModalOpen] = useState(false);
  const [selectedMediaId, setSelectedMediaId] = useState<string>('');
  const [mediaCaption, setMediaCaption] = useState('');
  const [submittingMedia, setSubmittingMedia] = useState(false);

  const fetchData = useCallback(async () => {
    if (!orderId) return;
    setLoading(true);
    const [updatesRes, mediaRes] = await Promise.all([
      getPublishedCustomerUpdates(orderId),
      getPublishedCustomerMedia(orderId),
    ]);
    if (updatesRes.success && updatesRes.data) {
      setUpdates(updatesRes.data);
    }
    if (mediaRes.success && mediaRes.data) {
      setMediaList(mediaRes.data);
    }
    setLoading(false);
  }, [orderId]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleOpenUpdateModal = () => {
    setUpdateTitle('');
    setUpdateContent('');
    setIsUpdateModalOpen(true);
  };

  const handleSubmitUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!updateTitle.trim() || !updateContent.trim() || submittingUpdate) return;

    setSubmittingUpdate(true);
    const res = await publishCustomerUpdate(orderId, {
      title: updateTitle.trim(),
      content: updateContent.trim(),
      message: updateContent.trim(),
    });
    setSubmittingUpdate(false);

    if (res.success && res.data) {
      showToast?.('Đã xuất bản cập nhật tiến độ cho khách xem');
      setIsUpdateModalOpen(false);
      fetchData();
    } else {
      showToast?.(res.message || 'Không thể đăng cập nhật');
    }
  };

  const handleOpenMediaModal = () => {
    setSelectedMediaId(orderImages && orderImages.length > 0 ? orderImages[0].id : '');
    setMediaCaption('');
    setIsMediaModalOpen(true);
  };

  const handleSubmitMedia = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedMediaId || submittingMedia) return;

    setSubmittingMedia(true);
    const res = await publishCustomerMedia(orderId, {
      mediaId: selectedMediaId,
      caption: mediaCaption.trim() || undefined,
    });
    setSubmittingMedia(false);

    if (res.success && res.data) {
      showToast?.('Đã chia sẻ hình ảnh cho khách xem');
      setIsMediaModalOpen(false);
      fetchData();
    } else {
      showToast?.(res.message || 'Không thể chia sẻ hình ảnh');
    }
  };

  return (
    <div className="order-customer-publish-card">
      <div className="publish-header-row">
        <div>
          <h4 className="publish-section-title">
            <Send size={15} className="text-blue-500" />
            Tiến độ & Hình ảnh hiển thị cho Khách hàng
          </h4>
          <span className="publish-section-desc">
            Nội dung ở đây sẽ hiển thị trực tiếp trên Cổng tra cứu của khách hàng.
          </span>
        </div>
        {canPublish && (
          <div className="publish-actions-bar">
            <button
              type="button"
              className="btn-publish-action"
              onClick={handleOpenUpdateModal}
              title="Đăng thông báo tiến độ cho khách"
            >
              <MessageSquare size={13} />
              Đăng tiến độ
            </button>
            <button
              type="button"
              className="btn-publish-action secondary"
              onClick={handleOpenMediaModal}
              title="Chia sẻ hình ảnh kiểm tra/sửa chữa cho khách"
            >
              <Image size={13} />
              Chia sẻ ảnh
            </button>
          </div>
        )}
      </div>

      {loading ? (
        <div className="publish-loading">
          <RefreshCw size={15} className="animate-spin" /> Đang tải tiến độ đã gửi...
        </div>
      ) : (
        <div className="publish-content-body">
          {/* Published updates list */}
          <div className="published-updates-section">
            <h5 className="sub-heading">
              <MessageSquare size={13} /> Tiến độ đã gửi ({updates.length})
            </h5>
            {updates.length === 0 ? (
              <p className="empty-sub-text">Chưa có thông báo tiến độ nào gửi cho khách.</p>
            ) : (
              <div className="published-updates-list">
                {updates.map((u) => (
                  <div key={u.id} className="published-update-item">
                    <div className="update-item-header">
                      <span className="update-item-title">{u.title}</span>
                      <span className="update-item-time">
                        <Clock size={11} />
                        {u.publishedAt && !isNaN(new Date(u.publishedAt).getTime())
                          ? new Date(u.publishedAt).toLocaleString('vi-VN')
                          : 'Vừa xong'}
                      </span>
                    </div>
                    <p className="update-item-content">{u.content || u.message}</p>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Published media gallery */}
          <div className="published-media-section">
            <h5 className="sub-heading">
              <Image size={13} /> Ảnh/Video công khai ({mediaList.length})
            </h5>
            {mediaList.length === 0 ? (
              <p className="empty-sub-text">Chưa có ảnh nào được gắn cờ công khai cho khách.</p>
            ) : (
              <div className="published-media-grid">
                {mediaList.map((m) => (
                  <div key={m.id} className="published-media-thumb">
                    <img src={m.fileUrl || m.mediaUrl} alt={m.caption || 'Media cho khách'} />
                    {m.caption && <span className="media-caption">{m.caption}</span>}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* MODAL: ĐĂNG TIẾN ĐỘ */}
      {isUpdateModalOpen && (
        <div className="orders-modal-overlay" style={{ zIndex: 1200 }}>
          <div className="orders-modal-card" style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <h3>
                <MessageSquare size={16} /> Đăng tiến độ cho khách xem ({orderCode})
              </h3>
              <button
                type="button"
                className="close-modal-btn"
                onClick={() => setIsUpdateModalOpen(false)}
              >
                ✕
              </button>
            </div>
            <form onSubmit={handleSubmitUpdate} className="modal-form">
              <div className="form-group">
                <label>Tiêu đề thông báo *</label>
                <input
                  type="text"
                  required
                  placeholder="VD: Đã kiểm tra xong bo nguồn và IGBT"
                  value={updateTitle}
                  onChange={(e) => setUpdateTitle(e.target.value)}
                />
              </div>
              <div className="form-group">
                <label>Chi tiết tiến độ gửi khách *</label>
                <textarea
                  rows={4}
                  required
                  placeholder="Mô tả tóm tắt tình trạng và bước xử lý tiếp theo bằng ngôn từ thân thiện với khách hàng..."
                  value={updateContent}
                  onChange={(e) => setUpdateContent(e.target.value)}
                />
              </div>
              <div className="modal-actions">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={() => setIsUpdateModalOpen(false)}
                  disabled={submittingUpdate}
                >
                  Hủy
                </button>
                <button type="submit" className="btn-submit" disabled={submittingUpdate}>
                  {submittingUpdate ? 'Đang gửi...' : 'Xuất bản cho khách'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: CHIA SẺ ẢNH */}
      {isMediaModalOpen && (
        <div className="orders-modal-overlay" style={{ zIndex: 1200 }}>
          <div className="orders-modal-card" style={{ maxWidth: '480px' }}>
            <div className="modal-header">
              <h3>
                <Image size={16} /> Chia sẻ hình ảnh cho khách ({orderCode})
              </h3>
              <button
                type="button"
                className="close-modal-btn"
                onClick={() => setIsMediaModalOpen(false)}
              >
                ✕
              </button>
            </div>
            <form onSubmit={handleSubmitMedia} className="modal-form">
              <div className="form-group">
                <label>Chọn ảnh đính kèm từ đơn hàng *</label>
                {orderImages && orderImages.length > 0 ? (
                  <div className="media-selection-grid">
                    {orderImages.map((img) => (
                      <div
                        key={img.id}
                        className={`media-select-card ${selectedMediaId === img.id ? 'selected' : ''}`}
                        onClick={() => setSelectedMediaId(img.id)}
                        title={img.caption || 'Nhấp để chọn ảnh này'}
                      >
                        <img src={img.imageUrl} alt={img.caption || 'Ảnh'} />
                        {selectedMediaId === img.id && (
                          <span className="media-select-indicator">✓</span>
                        )}
                      </div>
                    ))}
                  </div>
                ) : (
                  <p style={{ fontSize: '0.82rem', color: '#dc2626', margin: '4px 0 0' }}>
                    Đơn hàng này chưa có ảnh đính kèm. Vui lòng tải ảnh lên ở mục Phương tiện phía trên trước khi chia sẻ cho khách.
                  </p>
                )}
              </div>
              <div className="form-group">
                <label>Chú thích hiển thị cho khách hàng</label>
                <input
                  type="text"
                  placeholder="VD: Ảnh kiểm tra mạch nguồn sau khi thay tụ"
                  value={mediaCaption}
                  onChange={(e) => setMediaCaption(e.target.value)}
                />
              </div>
              <div className="modal-actions">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={() => setIsMediaModalOpen(false)}
                  disabled={submittingMedia}
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  className="btn-submit"
                  disabled={submittingMedia || !selectedMediaId}
                >
                  {submittingMedia ? 'Đang lưu...' : 'Lưu & Chia sẻ'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

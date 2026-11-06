import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  MessageSquare,
  Star,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Search,
  RefreshCw,
  Phone,
  Building2,
  Tag,
  Send,
  X,
  MessageSquareCheck,
  ShieldAlert,
  Flame,
  Filter,
} from 'lucide-react';
import type { CustomerFeedback, FeedbackStatus } from '../types/customerFeedback';
import {
  getCustomerFeedbacks,
  updateFeedbackReply,
  updateFeedbackStatusOnly,
} from '../utils/customerFeedbackApi';
import type { UserInfo } from '../mockData';
import './CustomerFeedbackSection.css';

interface CustomerFeedbackSectionProps {
  showToast: (msg: string) => void;
  currentUser?: UserInfo | null;
}

export const CustomerFeedbackSection: React.FC<CustomerFeedbackSectionProps> = ({
  showToast,
  currentUser,
}) => {
  const [feedbacks, setFeedbacks] = useState<CustomerFeedback[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [typeFilter, setTypeFilter] = useState<string>('ALL');
  const [ratingFilter, setRatingFilter] = useState<string>('ALL');
  const [onlyUrgent, setOnlyUrgent] = useState<boolean>(false);

  // Modal Xử lý & Phản hồi
  const [selectedFeedback, setSelectedFeedback] = useState<CustomerFeedback | null>(null);
  const [modalStatus, setModalStatus] = useState<FeedbackStatus>('IN_PROGRESS');
  const [modalReplyText, setModalReplyText] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);

  const fetchFeedbacks = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getCustomerFeedbacks();
      setFeedbacks(data);
    } catch {
      showToast('Không thể tải danh sách phản hồi');
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    fetchFeedbacks();
  }, [fetchFeedbacks]);

  // Thống kê nhanh (KPIs)
  const stats = useMemo(() => {
    const total = feedbacks.length;
    const urgentCount = feedbacks.filter((f) => f.isUrgent && f.status !== 'RESOLVED').length;
    const warrantyCount = feedbacks.filter((f) => f.type === 'WARRANTY_ISSUE').length;
    const resolvedCount = feedbacks.filter((f) => f.status === 'RESOLVED').length;
    const resolvedRate = total > 0 ? Math.round((resolvedCount / total) * 100) : 100;

    const ratedFeedbacks = feedbacks.filter((f) => f.type !== 'SUGGESTION' && f.rating > 0);
    const avgRating =
      ratedFeedbacks.length > 0
        ? (
            ratedFeedbacks.reduce((sum, f) => sum + f.rating, 0) / ratedFeedbacks.length
          ).toFixed(1)
        : '5.0';

    return { total, urgentCount, warrantyCount, resolvedRate, avgRating };
  }, [feedbacks]);

  // Bộ lọc dữ liệu
  const filteredFeedbacks = useMemo(() => {
    return feedbacks.filter((f) => {
      if (onlyUrgent && !f.isUrgent) return false;
      if (statusFilter !== 'ALL' && f.status !== statusFilter) return false;
      if (typeFilter !== 'ALL' && f.type !== typeFilter) return false;
      if (ratingFilter === '5_STAR' && f.rating !== 5) return false;
      if (ratingFilter === '4_STAR' && f.rating !== 4) return false;
      if (ratingFilter === 'LOW_STAR' && f.rating > 3) return false;

      if (searchTerm.trim()) {
        const q = searchTerm.toLowerCase().trim();
        const matchName = f.customerName.toLowerCase().includes(q);
        const matchCode = (f.customerCode || '').toLowerCase().includes(q);
        const matchOrder = f.orderCode.toLowerCase().includes(q);
        const matchDevice = (f.deviceModel || '').toLowerCase().includes(q);
        const matchContent = f.content.toLowerCase().includes(q);
        if (!matchName && !matchCode && !matchOrder && !matchDevice && !matchContent) {
          return false;
        }
      }
      return true;
    });
  }, [feedbacks, onlyUrgent, statusFilter, typeFilter, ratingFilter, searchTerm]);

  // Mở modal trả lời
  const handleOpenReplyModal = (f: CustomerFeedback) => {
    setSelectedFeedback(f);
    setModalStatus(f.status === 'PENDING' ? 'IN_PROGRESS' : f.status);
    setModalReplyText(f.reply || '');
  };

  // Submit trả lời
  const handleSubmitReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFeedback) return;
    if (!modalReplyText.trim()) {
      showToast('Vui lòng nhập nội dung phản hồi cho khách hàng');
      return;
    }

    setIsSubmitting(true);
    try {
      const updated = await updateFeedbackReply({
        feedbackId: selectedFeedback.id,
        status: modalStatus,
        reply: modalReplyText,
        repliedBy: currentUser?.fullName || currentUser?.username || 'Kỹ sư trưởng LikeNew',
      });

      setFeedbacks((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      showToast('Đã gửi phản hồi và cập nhật tiến độ giải quyết!');
      setSelectedFeedback(null);
    } catch {
      showToast('Có lỗi xảy ra khi lưu phản hồi');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Cập nhật trạng thái trực tiếp
  const handleQuickStatusChange = async (feedbackId: string, newStatus: FeedbackStatus) => {
    try {
      const updated = await updateFeedbackStatusOnly(feedbackId, newStatus);
      setFeedbacks((prev) => prev.map((item) => (item.id === updated.id ? updated : item)));
      showToast(`Đã chuyển trạng thái sang "${updated.statusName}"`);
    } catch {
      showToast('Lỗi cập nhật trạng thái');
    }
  };

  return (
    <div className="customer-feedback-section">
      {/* 1. Header & KPI Cards */}
      <div className="feedback-kpi-grid">
        <div className="feedback-kpi-card">
          <div className="kpi-icon-wrap primary">
            <MessageSquare size={22} />
          </div>
          <div className="kpi-info">
            <span className="kpi-label">Tổng phản hồi</span>
            <span className="kpi-value">{stats.total}</span>
          </div>
        </div>

        <div className="feedback-kpi-card">
          <div className="kpi-icon-wrap star">
            <Star size={22} />
          </div>
          <div className="kpi-info">
            <span className="kpi-label">Điểm hài lòng CSAT</span>
            <span className="kpi-value">{stats.avgRating} / 5.0 ⭐</span>
          </div>
        </div>

        <div className={`feedback-kpi-card ${stats.urgentCount > 0 ? 'urgent-glow' : ''}`}>
          <div className="kpi-icon-wrap urgent">
            <Flame size={22} />
          </div>
          <div className="kpi-info">
            <span className="kpi-label">Sự cố khẩn cấp</span>
            <span className="kpi-value text-urgent">{stats.urgentCount}</span>
          </div>
        </div>

        <div className="feedback-kpi-card">
          <div className="kpi-icon-wrap warning">
            <AlertTriangle size={22} />
          </div>
          <div className="kpi-info">
            <span className="kpi-label">Khiếu nại bảo hành</span>
            <span className="kpi-value">{stats.warrantyCount}</span>
          </div>
        </div>

        <div className="feedback-kpi-card">
          <div className="kpi-icon-wrap success">
            <CheckCircle2 size={22} />
          </div>
          <div className="kpi-info">
            <span className="kpi-label">Tỷ lệ giải quyết</span>
            <span className="kpi-value text-success">{stats.resolvedRate}%</span>
          </div>
        </div>
      </div>

      {/* 2. Toolbar & Filters */}
      <div className="feedback-toolbar-card">
        <div className="feedback-filters-row">
          <div className="search-box-wrap">
            <Search size={16} className="search-icon" />
            <input
              type="text"
              placeholder="Tìm theo khách hàng, mã đơn, thiết bị, nội dung..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="feedback-search-input"
            />
          </div>

          <select
            className="filter-select"
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
          >
            <option value="ALL">Tất cả phân loại</option>
            <option value="SERVICE_QUALITY">⭐ Đánh giá chất lượng</option>
            <option value="WARRANTY_ISSUE">⚠️ Khiếu nại / Bảo hành</option>
            <option value="SUGGESTION">💡 Đóng góp ý kiến</option>
          </select>

          <select
            className="filter-select"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="ALL">Tất cả trạng thái</option>
            <option value="PENDING">Chờ tiếp nhận</option>
            <option value="IN_PROGRESS">Đang xử lý</option>
            <option value="RESOLVED">Đã giải quyết</option>
          </select>

          <select
            className="filter-select"
            value={ratingFilter}
            onChange={(e) => setRatingFilter(e.target.value)}
          >
            <option value="ALL">Mọi mức đánh giá sao</option>
            <option value="5_STAR">⭐⭐⭐⭐⭐ (5 sao)</option>
            <option value="4_STAR">⭐⭐⭐⭐ (4 sao)</option>
            <option value="LOW_STAR">⭐ Đến ⭐⭐⭐ (Cần khắc phục)</option>
          </select>

          <button
            type="button"
            className={`btn-urgent-toggle ${onlyUrgent ? 'active' : ''}`}
            onClick={() => setOnlyUrgent((prev) => !prev)}
            title="Chỉ hiển thị phản hồi có gắn cờ KHẨN CẤP"
          >
            <Flame size={15} />
            <span>Khẩn cấp ({stats.urgentCount})</span>
          </button>

          <button
            type="button"
            className="btn-refresh"
            onClick={fetchFeedbacks}
            title="Làm mới dữ liệu"
          >
            <RefreshCw size={15} className={loading ? 'animate-spin' : ''} />
            Làm mới
          </button>
        </div>
      </div>

      {/* 3. Feedback Cards List */}
      <div className="feedback-cards-container">
        {loading && feedbacks.length === 0 ? (
          <div className="feedback-empty-state">
            <RefreshCw size={28} className="animate-spin text-primary" />
            <p>Đang tải danh sách phản hồi từ khách hàng...</p>
          </div>
        ) : filteredFeedbacks.length === 0 ? (
          <div className="feedback-empty-state">
            <Filter size={32} className="text-muted" />
            <h4>Không có phản hồi nào phù hợp bộ lọc</h4>
            <p>Vui lòng thử điều chỉnh lại từ khóa hoặc các tiêu chí phân loại.</p>
          </div>
        ) : (
          filteredFeedbacks.map((f) => {
            const isPending = f.status === 'PENDING';
            const isInProgress = f.status === 'IN_PROGRESS';
            const isResolved = f.status === 'RESOLVED';

            return (
              <div
                key={f.id}
                className={`feedback-card-item ${f.isUrgent ? 'urgent-border' : ''} ${isResolved ? 'resolved' : ''}`}
              >
                {/* Header card */}
                <div className="card-top-row">
                  <div className="customer-info-wrap">
                    <span className="customer-name-title">
                      <Building2 size={16} />
                      {f.customerName}
                    </span>
                    {f.customerCode && <span className="code-badge">{f.customerCode}</span>}
                    {f.customerPhone && (
                      <a href={`tel:${f.customerPhone}`} className="phone-link">
                        <Phone size={13} />
                        {f.customerPhone}
                      </a>
                    )}
                  </div>

                  <div className="card-top-badges">
                    {f.isUrgent && (
                      <span className="badge-urgent-tag">
                        <Flame size={13} />
                        KHẨN CẤP
                      </span>
                    )}

                    <span className={`badge-type-tag ${f.type.toLowerCase()}`}>
                      {f.typeName}
                    </span>

                    <span
                      className={`badge-status-pill ${
                        isResolved ? 'resolved' : isInProgress ? 'in-progress' : 'pending'
                      }`}
                    >
                      {isResolved && <CheckCircle2 size={12} />}
                      {isInProgress && <Clock size={12} />}
                      {f.statusName}
                    </span>
                  </div>
                </div>

                {/* Sub row: Order Code & Device Model */}
                <div className="card-sub-row">
                  <div className="order-device-wrap">
                    <span className="order-pill">
                      <strong>Mã đơn:</strong> {f.orderCode}
                    </span>
                    {f.deviceModel && (
                      <span className="device-pill">
                        <strong>Thiết bị:</strong> {f.deviceModel}
                      </span>
                    )}
                  </div>
                  <div className="time-stamp">
                    <Clock size={13} />
                    {f.createdAt}
                  </div>
                </div>

                {/* Rating stars & Tags */}
                <div className="card-rating-tags-row">
                  {f.type !== 'SUGGESTION' && (
                    <div className="stars-wrap">
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Star
                          key={i}
                          size={16}
                          className={i < f.rating ? 'star-filled' : 'star-empty'}
                        />
                      ))}
                      <span className="rating-num">({f.rating}/5)</span>
                    </div>
                  )}

                  {f.tags.length > 0 && (
                    <div className="tags-list">
                      {f.tags.map((tag, tIdx) => (
                        <span key={tIdx} className="feedback-tag">
                          <Tag size={11} />
                          {tag}
                        </span>
                      ))}
                    </div>
                  )}
                </div>

                {/* Customer Content Box */}
                <div className="customer-content-box">
                  <p className="content-text">{f.content}</p>
                </div>

                {/* Technician Reply Box (If any) */}
                {f.reply && (
                  <div className="reply-display-box">
                    <div className="reply-header">
                      <MessageSquareCheck size={15} className="text-primary" />
                      <span className="replier-name">
                        {f.repliedBy || 'Kỹ thuật viên LikeNew'} đã phản hồi:
                      </span>
                      {f.replyAt && <span className="reply-time">({f.replyAt})</span>}
                    </div>
                    <p className="reply-content">{f.reply}</p>
                  </div>
                )}

                {/* Card Bottom Actions */}
                <div className="card-actions-row">
                  <div className="quick-status-actions">
                    <span className="status-label">Chuyển trạng thái:</span>
                    {isPending && (
                      <button
                        type="button"
                        className="btn-status-quick in-progress"
                        onClick={() => handleQuickStatusChange(f.id, 'IN_PROGRESS')}
                      >
                        Bắt đầu xử lý
                      </button>
                    )}
                    {!isResolved && (
                      <button
                        type="button"
                        className="btn-status-quick resolve"
                        onClick={() => handleQuickStatusChange(f.id, 'RESOLVED')}
                      >
                        Đánh dấu đã giải quyết
                      </button>
                    )}
                  </div>

                  <button
                    type="button"
                    className="btn-action-reply"
                    onClick={() => handleOpenReplyModal(f)}
                  >
                    <Send size={14} />
                    {f.reply ? 'Cập nhật câu trả lời' : 'Xử lý & Trả lời khách'}
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* 4. Modal Trả lời & Xử lý Khiếu nại */}
      {selectedFeedback && (
        <div className="feedback-modal-overlay">
          <div className="feedback-modal-card">
            <div className="modal-header">
              <div className="modal-title-wrap">
                <MessageSquare className="text-primary" size={20} />
                <h3>Xử lý & Phản hồi Khách hàng</h3>
              </div>
              <button
                type="button"
                className="btn-close-modal"
                onClick={() => setSelectedFeedback(null)}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSubmitReply} className="modal-body">
              {/* Summary of feedback */}
              <div className="feedback-summary-box">
                <div className="summary-row">
                  <span>Khách hàng:</span>
                  <strong>{selectedFeedback.customerName}</strong>
                </div>
                <div className="summary-row">
                  <span>Mã đơn / Thiết bị:</span>
                  <strong>
                    {selectedFeedback.orderCode} - {selectedFeedback.deviceModel || 'Ý kiến chung'}
                  </strong>
                </div>
                {selectedFeedback.isUrgent && (
                  <div className="urgent-alert-badge">
                    <ShieldAlert size={14} />
                    <span>Phản hồi này được đánh dấu KHẨN CẤP (Dừng dây chuyền / Sự cố gấp)</span>
                  </div>
                )}
                <div className="summary-content-quote">
                  <em>&ldquo;{selectedFeedback.content}&rdquo;</em>
                </div>
              </div>

              {/* Status Select */}
              <div className="form-group">
                <label className="form-label">Cập nhật trạng thái xử lý:*</label>
                <div className="status-options-group">
                  <label className={`status-option-pill ${modalStatus === 'IN_PROGRESS' ? 'active' : ''}`}>
                    <input
                      type="radio"
                      name="feedbackStatus"
                      value="IN_PROGRESS"
                      checked={modalStatus === 'IN_PROGRESS'}
                      onChange={() => setModalStatus('IN_PROGRESS')}
                    />
                    <span>⚙️ Đang xử lý</span>
                  </label>
                  <label className={`status-option-pill ${modalStatus === 'RESOLVED' ? 'active' : ''}`}>
                    <input
                      type="radio"
                      name="feedbackStatus"
                      value="RESOLVED"
                      checked={modalStatus === 'RESOLVED'}
                      onChange={() => setModalStatus('RESOLVED')}
                    />
                    <span>✅ Đã giải quyết</span>
                  </label>
                </div>
              </div>

              {/* Reply Textarea */}
              <div className="form-group">
                <label className="form-label">Nội dung phản hồi / Giải pháp kỹ thuật gửi khách hàng:*</label>
                <textarea
                  rows={4}
                  className="reply-textarea"
                  placeholder="Nhập nội dung giải đáp, căn chỉnh thông số, hẹn giờ kỹ sư đến hiện trường..."
                  value={modalReplyText}
                  onChange={(e) => setModalReplyText(e.target.value)}
                  required
                />
              </div>

              {/* Template quick fills */}
              <div className="quick-templates-wrap">
                <span className="templates-label">Mẫu nhanh:</span>
                <button
                  type="button"
                  className="template-chip"
                  onClick={() =>
                    setModalReplyText(
                      'Kỹ sư trưởng LikeNew đã tiếp nhận yêu cầu. Kỹ thuật viên sẽ liên hệ trực tiếp qua số điện thoại để hỗ trợ căn chỉnh lại thông số thiết bị ngay trong sáng nay.'
                    )
                  }
                >
                  Tiếp nhận hỗ trợ thông số
                </button>
                <button
                  type="button"
                  className="template-chip"
                  onClick={() =>
                    setModalReplyText(
                      'Trung tâm bảo hành LikeNew đã cử kỹ sư chuyên trách đến nhà máy của Quý khách để kiểm tra hiện trường. Dự kiến có mặt trong vòng 2 giờ.'
                    )
                  }
                >
                  Cử kỹ sư đến hiện trường
                </button>
                <button
                  type="button"
                  className="template-chip"
                  onClick={() =>
                    setModalReplyText(
                      'Bộ phận Kỹ thuật LikeNew trân trọng cảm ơn Quý khách đã luôn tin tưởng dịch vụ! Chúc dây chuyền của Quý công ty vận hành an toàn và năng suất.'
                    )
                  }
                >
                  Cảm ơn đánh giá chất lượng
                </button>
              </div>

              {/* Modal footer */}
              <div className="modal-footer">
                <button
                  type="button"
                  className="btn-modal-cancel"
                  onClick={() => setSelectedFeedback(null)}
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  className="btn-modal-submit"
                  disabled={isSubmitting}
                >
                  <Send size={15} />
                  {isSubmitting ? 'Đang gửi...' : 'Gửi phản hồi cho khách'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

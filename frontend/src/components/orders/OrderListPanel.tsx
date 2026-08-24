import React from 'react';
import { Search, Filter, Calendar, Plus, X, User, Phone } from 'lucide-react';
import type { RepairOrder } from '../../types/orders';

interface OrderListPanelProps {
  searchTerm: string;
  setSearchTerm: (val: string) => void;
  statusFilter: string;
  setStatusFilter: (val: string) => void;
  warrantyFilter: string;
  setWarrantyFilter: (val: string) => void;
  dateFilter: string;
  setDateFilter: (val: string) => void;
  setVisibleCount: React.Dispatch<React.SetStateAction<number>>;
  openCreateModal: () => void;
  listWrapperRef: React.RefObject<HTMLDivElement | null>;
  handleScrollList: (e: React.UIEvent<HTMLDivElement>) => void;
  loading: boolean;
  displayedOrders: RepairOrder[];
  filteredOrders: RepairOrder[];
  selectedOrder: RepairOrder | null;
  handleSelectOrder: (order: RepairOrder) => void;
  getStatusMeta: (status: string) => { label: string; color: string };
  visibleCount: number;
}

export const OrderListPanel: React.FC<OrderListPanelProps> = ({
  searchTerm,
  setSearchTerm,
  statusFilter,
  setStatusFilter,
  warrantyFilter,
  setWarrantyFilter,
  dateFilter,
  setDateFilter,
  setVisibleCount,
  openCreateModal,
  listWrapperRef,
  handleScrollList,
  loading,
  displayedOrders,
  filteredOrders,
  selectedOrder,
  handleSelectOrder,
  getStatusMeta,
  visibleCount,
}) => {
  return (
    <>
      {/* Top Filter Card */}
      <div className="orders-filter-card">
        <div className="search-box-row">
          <div className="search-input-wrapper">
            <Search size={18} className="search-icon" />
            <input
              type="text"
              className="orders-search-input"
              placeholder="Tìm theo mã đơn, số seri, thiết bị, tên hoặc SĐT khách..."
              value={searchTerm}
              onChange={(e) => {
                setSearchTerm(e.target.value);
                setVisibleCount(20);
              }}
            />
          </div>

          <button className="btn-create-order" onClick={openCreateModal}>
            <Plus size={16} />
            <span>Tạo đơn mới</span>
          </button>
        </div>

        <div className="filters-row">
          <div className="filter-item">
            <Filter size={14} className="filter-icon" />
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setVisibleCount(20);
              }}
            >
              <option value="ALL">Tất cả trạng thái</option>
              <option value="PENDING">Chưa kiểm tra</option>
              <option value="WAITING_FOR_CHECK">Chờ kiểm tra</option>
              <option value="CHECKING">Đang kiểm tra</option>
              <option value="CHECKED">Đã kiểm tra</option>
              <option value="IN_PROGRESS">Đang sửa</option>
              <option value="COMPLETED">Hoàn thành</option>
              <option value="DELIVERED">Đã giao</option>
              <option value="CANCELLED">Đã trả</option>
            </select>
          </div>

          <div className="filter-item">
            <ShieldCheckIcon />
            <select
              value={warrantyFilter}
              onChange={(e) => {
                setWarrantyFilter(e.target.value);
                setVisibleCount(20);
              }}
            >
              <option value="ALL">Mọi bảo hành</option>
              <option value="WARRANTY">Có bảo hành</option>
              <option value="NO_WARRANTY">Không bảo hành</option>
            </select>
          </div>

          <div className="filter-item">
            <Calendar size={14} className="filter-icon" />
            <input
              type="date"
              value={dateFilter}
              onChange={(e) => {
                setDateFilter(e.target.value);
                setVisibleCount(20);
              }}
              className="filter-date-input"
            />
            {dateFilter && (
              <button
                className="clear-date-btn"
                onClick={() => {
                  setDateFilter('');
                  setVisibleCount(20);
                }}
              >
                <X size={12} />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* List display */}
      <div
        className="orders-list-wrapper"
        ref={listWrapperRef}
        onScroll={handleScrollList}
      >
        {loading ? (
          <div className="list-status-msg">Đang tải danh sách đơn hàng...</div>
        ) : displayedOrders.length === 0 ? (
          <div className="list-status-msg">Không tìm thấy đơn hàng nào.</div>
        ) : (
          <>
            <div className="orders-cards-list">
              {displayedOrders.map((order) => {
                const statusMeta = getStatusMeta(order.status);
                const isSelected = selectedOrder?.id === order.id;

                return (
                  <div
                    key={order.id}
                    className={`order-list-card ${isSelected ? 'selected' : ''}`}
                    onClick={() => handleSelectOrder(order)}
                  >
                    <div className="card-header-row">
                      <span className="order-code-tag">{order.orderCode}</span>
                      <span className={`status-badge ${statusMeta.color}`}>
                        {statusMeta.label}
                      </span>
                    </div>

                    <h3 className="card-device-name" title={order.deviceName}>
                      {order.deviceName}
                    </h3>

                    <div className="card-info-grid">
                      <div className="info-item">
                        <User size={13} />
                        <span>{order.customerName}</span>
                      </div>
                      {order.customerPhone && (
                        <div className="info-item">
                          <Phone size={13} />
                          <span>{order.customerPhone}</span>
                        </div>
                      )}
                    </div>

                    <div className="card-footer-row">
                      <span className="card-date">
                        {new Date(order.createdAt).toLocaleDateString('vi-VN', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </span>
                      <div className="card-assignees">
                        {order.assignees.length > 0 ? (
                          <span
                            className="assignees-badge"
                            title={order.assignees.map((a) => a.fullName).join(', ')}
                          >
                            {order.assignees.length} kỹ thuật viên
                          </span>
                        ) : (
                          <span className="unassigned-badge">Chưa phân công</span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Infinite Scroll Footer */}
            <div className="infinite-scroll-footer">
              {visibleCount < filteredOrders.length ? (
                <span className="loading-more-text">
                  Cuộn xuống để nạp thêm... ({displayedOrders.length}/{filteredOrders.length})
                </span>
              ) : (
                <span className="end-list-text">
                  Đã hiển thị tất cả {filteredOrders.length} đơn hàng
                </span>
              )}
            </div>
          </>
        )}
      </div>
    </>
  );
};

const ShieldCheckIcon: React.FC = () => (
  <svg
    width="14"
    height="14"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    className="filter-icon"
  >
    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    <path d="m9 12 2 2 4-4" />
  </svg>
);

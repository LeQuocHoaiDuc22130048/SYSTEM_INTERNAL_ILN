import React from 'react';
import { Cpu, Edit2, Trash2, Printer } from 'lucide-react';
import type { Board, BoardHistoryItem } from '../../types/warehouse';

interface BoardDetailPanelProps {
  selectedBoard: Board;
  getStatusLabel: (status: string) => string;
  getStatusColorClass: (status: string) => string;
  openAddEditModal: (board: Board) => void;
  handleDeleteBoard: () => void;
  openCheckoutModal: () => void;
  openReturnModal: () => void;
  getQRCodeUrl: (code: string) => string;
  exportBoardQrPdf: (board: Board) => void;
  loadingHistory: boolean;
  boardHistory: BoardHistoryItem[];
}

export const BoardDetailPanel: React.FC<BoardDetailPanelProps> = ({
  selectedBoard,
  getStatusLabel,
  getStatusColorClass,
  openAddEditModal,
  handleDeleteBoard,
  openCheckoutModal,
  openReturnModal,
  getQRCodeUrl,
  exportBoardQrPdf,
  loadingHistory,
  boardHistory,
}) => {
  return (
    <div className="detail-scroller">
      <div className="detail-header-row">
        <div className="title-wrapper">
          <div className="board-badge-icon">
            <Cpu size={24} />
          </div>
          <div>
            <h3 className="detail-board-name">{selectedBoard.name}</h3>
            <span className={`status-badge ${getStatusColorClass(selectedBoard.status)}`}>
              {getStatusLabel(selectedBoard.status)}
            </span>
          </div>
        </div>

        <div className="actions-wrapper">
          <button className="btn-action-outline" onClick={() => openAddEditModal(selectedBoard)}>
            <Edit2 size={14} />
            Sửa
          </button>
          <button className="btn-action-outline danger" onClick={handleDeleteBoard}>
            <Trash2 size={14} />
            Xóa
          </button>
        </div>
      </div>

      {/* Status Action Buttons */}
      <div className="detail-main-actions-bar">
        {selectedBoard.status === 'AVAILABLE' ? (
          <button className="btn-checkout-board" onClick={openCheckoutModal}>
            Mượn board / Checkout
          </button>
        ) : (selectedBoard.status === 'CHECKED_OUT' || selectedBoard.status === 'IN_USE') ? (
          <button className="btn-return-board" onClick={openReturnModal}>
            Trả board về kho
          </button>
        ) : null}
      </div>

      {/* Specs Specifications List */}
      <div className="detail-content-section">
        <h4 className="section-title">Thông số kỹ thuật</h4>
        <div className="specs-info-grid">
          <div className="spec-detail-item">
            <span className="label">Vị trí lưu trữ</span>
            <span className="value">{selectedBoard.location || 'Chưa cài đặt'}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Tồn kho hiện tại</span>
            <span className={`value ${(selectedBoard.quantity || 0) > 0 ? 'text-success' : 'text-danger'}`}>
              {selectedBoard.quantity || 0}
              {(selectedBoard.quantity || 0) === 0 && ' (Hết hàng)'}
            </span>
          </div>
        </div>
      </div>

      {/* Active Checkout Info */}
      {selectedBoard.checkedOutBy && (
        <div className="detail-content-section">
          <h4 className="section-title">Thông tin mượn hiện tại</h4>
          <div className="active-borrow-card">
            <div className="borrow-row">
              <span className="lbl">Người mượn:</span>
              <span className="val">{selectedBoard.checkedOutBy}</span>
            </div>
            {selectedBoard.checkedOutAt && (
              <div className="borrow-row">
                <span className="lbl">Ngày mượn:</span>
                <span className="val">{new Date(selectedBoard.checkedOutAt).toLocaleString('vi-VN')}</span>
              </div>
            )}
            {selectedBoard.currentRepairOrder && (
              <div className="borrow-row">
                <span className="lbl">Liên kết đơn sửa:</span>
                <span className="val link-code">
                  {selectedBoard.currentRepairOrder}
                </span>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Description */}
      {selectedBoard.description && (
        <div className="detail-content-section">
          <h4 className="section-title">Mô tả bo mạch</h4>
          <div className="description-card">
            <p>{selectedBoard.description}</p>
          </div>
        </div>
      )}

      {/* QR Code Section */}
      <div className="detail-content-section align-center">
        <div className="qrcode-section-header">
          <h4 className="section-title text-left margin-0">QR Code định danh</h4>
          <button
            className="btn-export-qr-pdf"
            onClick={() => exportBoardQrPdf(selectedBoard)}
            title="Xuất PDF mã QR và mã code của linh kiện bo mạch này"
          >
            <Printer size={15} />
            <span>Xuất PDF QR</span>
          </button>
        </div>
        <div className="qrcode-container-card">
          <img src={getQRCodeUrl(selectedBoard.qrCode)} alt="QR Code" className="qrcode-img" />
          <div className="qrcode-meta">
            <span className="qr-value">{selectedBoard.qrCode}</span>
            <span className="qr-desc">Dùng ứng dụng di động quét mã QR này để nhanh chóng kiểm tra thông tin hoặc thay đổi vị trí.</span>
            <button
              className="btn-export-qr-pdf-outline"
              onClick={() => exportBoardQrPdf(selectedBoard)}
            >
              <Printer size={14} />
              <span>Xuất tem PDF</span>
            </button>
          </div>
        </div>
      </div>

      {/* History Section */}
      <div className="detail-content-section">
        <h4 className="section-title">Lịch sử di chuyển & mượn trả</h4>
        <div className="history-flow-card">
          {loadingHistory ? (
            <p className="no-data-text">Đang tải lịch sử di chuyển...</p>
          ) : boardHistory.length > 0 ? (
            <div className="history-nodes-list">
              {boardHistory.map((item, idx) => (
                <div key={item.id || idx} className="history-node-item">
                  <div className="node-marker" />
                  <div className="node-info">
                    <div className="node-header">
                      <span className="node-author">Mượn bởi: <strong>{item.takenByName}</strong></span>
                      {item.takenAt && (
                        <span className="node-time">{new Date(item.takenAt).toLocaleString('vi-VN')}</span>
                      )}
                    </div>
                    {item.returnedAt && (
                      <div className="node-return">
                        <span>Trả vào: {new Date(item.returnedAt).toLocaleString('vi-VN')}</span>
                      </div>
                    )}
                    {item.notes && <div className="node-notes">{item.notes}</div>}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <p className="no-data-text">Chưa có lịch sử mượn trả nào cho bo mạch này.</p>
          )}
        </div>
      </div>
    </div>
  );
};

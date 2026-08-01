import React, { useState } from 'react';
import { Cpu, Edit2, Trash2, Printer, Copy, Check } from 'lucide-react';
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
  const [isCopied, setIsCopied] = useState<boolean>(false);

  const handleCopyQr = () => {
    const rawQrCode = (selectedBoard?.qrCode || '').trim();
    if (rawQrCode) {
      navigator.clipboard.writeText(rawQrCode);
      setIsCopied(true);
      setTimeout(() => setIsCopied(false), 2200);
    }
  };

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
          <div className="spec-detail-item">
            <span className="label">Model thiết bị</span>
            <span className="value">{selectedBoard.model || 'Chưa rõ'}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Loại bo mạch</span>
            <span className="value">{selectedBoard.boardType || 'Chưa phân loại'}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Số Serial</span>
            <span className="value">{selectedBoard.serialNumber || 'Không có'}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Firmware</span>
            <span className="value">{selectedBoard.firmware || 'Chưa cập nhật'}</span>
          </div>
          {selectedBoard.receivedDate && (
            <div className="spec-detail-item">
              <span className="label">Ngày nhập kho</span>
              <span className="value">{new Date(selectedBoard.receivedDate).toLocaleDateString('vi-VN')}</span>
            </div>
          )}
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

      {/* Note */}
      {selectedBoard.note && (
        <div className="detail-content-section">
          <h4 className="section-title">Ghi chú bổ sung</h4>
          <div className="description-card">
            <p>{selectedBoard.note}</p>
          </div>
        </div>
      )}

      {/* Removed Parts */}
      {selectedBoard.removedParts && (
        <div className="detail-content-section">
          <h4 className="section-title">Linh kiện đã rã (Bo xác)</h4>
          <div className="description-card">
            <p>{selectedBoard.removedParts}</p>
          </div>
        </div>
      )}


      {/* QR Code Section */}
      <div className="detail-content-section align-center">
        <div className="qrcode-section-header">
          <h4 className="section-title text-left margin-0">QR Code định danh</h4>
          <button
            className={`btn-export-qr-pdf ${isCopied ? 'copied-success' : ''}`}
            onClick={handleCopyQr}
            title="Sao chép mã QR này vào bộ nhớ tạm"
          >
            {isCopied ? <Check size={15} /> : <Copy size={15} />}
            <span>{isCopied ? 'Đã sao chép mã!' : 'Sao chép Mã QR'}</span>
          </button>
        </div>
        <div className="qrcode-container-card">
          <img src={getQRCodeUrl(selectedBoard.qrCode)} alt="QR Code" className="qrcode-img" />
          <div className="qrcode-meta">
            <span className="qr-value">{selectedBoard.qrCode}</span>
            <span className="qr-desc">Sao chép mã QR này hoặc dùng ứng dụng di động quét mã để kiểm tra thông tin nhanh.</span>
            
            <div style={{ display: 'flex', gap: '8px', width: '100%', marginTop: '6px' }}>
              <button
                className={`btn-export-qr-pdf-outline ${isCopied ? 'copied-success' : ''}`}
                onClick={handleCopyQr}
                style={{ flex: 1 }}
              >
                {isCopied ? <Check size={14} /> : <Copy size={14} />}
                <span>{isCopied ? 'Đã sao chép!' : 'Sao chép mã'}</span>
              </button>

              <button
                className="btn-export-qr-pdf-outline"
                onClick={() => exportBoardQrPdf(selectedBoard)}
                title="Cấu hình cài đặt in tem nhãn bo mạch"
                style={{ width: 'auto', padding: '0 10px' }}
              >
                <Printer size={14} />
              </button>
            </div>
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

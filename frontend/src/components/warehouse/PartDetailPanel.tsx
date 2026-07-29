import React from 'react';
import { Boxes, Edit2, Trash2 } from 'lucide-react';
import type { Part } from '../../types/warehouse';

interface PartDetailPanelProps {
  selectedPart: Part;
  openAddEditPartModal: (part: Part) => void;
  handleDeletePart: () => void;
  openAdjustStockModal: () => void;
}

export const PartDetailPanel: React.FC<PartDetailPanelProps> = ({
  selectedPart,
  openAddEditPartModal,
  handleDeletePart,
  openAdjustStockModal,
}) => {
  const isZeroStock = selectedPart.totalQuantity === 0;
  const isLowStock = selectedPart.totalQuantity < selectedPart.minAmount;

  return (
    <div className="detail-scroller">
      <div className="detail-header-row">
        <div className="title-wrapper">
          <div className="board-badge-icon">
            <Boxes size={24} />
          </div>
          <div>
            <h3 className="detail-board-name">{selectedPart.name}</h3>
            <span
              className={`status-badge ${
                isZeroStock
                  ? 'board-damaged'
                  : isLowStock
                  ? 'board-checkedout'
                  : 'board-available'
              }`}
            >
              {isZeroStock ? 'Hết hàng' : isLowStock ? 'Sắp hết' : 'Đủ hàng'}
            </span>
          </div>
        </div>

        <div className="actions-wrapper">
          <button className="btn-action-outline" onClick={() => openAddEditPartModal(selectedPart)}>
            <Edit2 size={14} />
            Sửa
          </button>
          <button className="btn-action-outline danger" onClick={handleDeletePart}>
            <Trash2 size={14} />
            Xóa
          </button>
        </div>
      </div>

      {/* Main Action Buttons */}
      <div className="detail-main-actions-bar">
        <button className="btn-checkout-board" onClick={openAdjustStockModal}>
          Điều chỉnh số lượng tồn kho
        </button>
      </div>

      {/* Specs Section */}
      <div className="detail-content-section">
        <h4 className="section-title">Thông số kỹ thuật</h4>
        <div className="specs-info-grid">
          <div className="spec-detail-item">
            <span className="label">Mã IPN</span>
            <span className="value" style={{ fontFamily: 'monospace', fontWeight: 700 }}>
              {selectedPart.ipn}
            </span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Danh mục linh kiện</span>
            <span className="value">{selectedPart.categoryName || 'Chưa rõ'}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Định mức tối thiểu</span>
            <span className="value">{selectedPart.minAmount}</span>
          </div>
          <div className="spec-detail-item">
            <span className="label">Tổng lượng tồn kho</span>
            <span className="value text-success" style={{ fontSize: '1rem', fontWeight: 800 }}>
              {selectedPart.totalQuantity}
            </span>
          </div>
        </div>
      </div>

      {/* Detailed Stock per Location */}
      <div className="detail-content-section">
        <h4 className="section-title">Vị trí lưu kho & Số lượng chi tiết</h4>
        <div className="specs-info-grid">
          {selectedPart.lots && selectedPart.lots.length > 0 ? (
            selectedPart.lots.map((lot) => (
              <div
                key={lot.id}
                className="spec-detail-item"
                style={{ borderBottom: '1px dashed var(--color-border)', paddingBottom: '6px' }}
              >
                <div>
                  <span className="value" style={{ display: 'block' }}>
                    {lot.storeLocationName}
                  </span>
                </div>
                <span className="value text-success" style={{ fontSize: '0.95rem' }}>
                  {lot.amount}
                </span>
              </div>
            ))
          ) : (
            <p className="no-data-text" style={{ margin: 0, padding: '10px 0' }}>
              Chưa có linh kiện này ở bất kỳ vị trí kho nào. Nhấp "Điều chỉnh số lượng tồn kho" để nhập kho.
            </p>
          )}
        </div>
      </div>

      {/* Description Section */}
      {selectedPart.description && (
        <div className="detail-content-section">
          <h4 className="section-title">Mô tả linh kiện</h4>
          <div className="description-card">
            <p>{selectedPart.description}</p>
          </div>
        </div>
      )}
    </div>
  );
};

import React from 'react';
import { Search, Plus, Boxes, Layers, CheckCircle, History, Tag, MapPin } from 'lucide-react';
import type { Part } from '../../types/warehouse';

interface PartListPanelProps {
  parts: Part[];
  loadingParts: boolean;
  partSearchTerm: string;
  setPartSearchTerm: (val: string) => void;
  filteredParts: Part[];
  selectedPart: Part | null;
  setSelectedPart: (part: Part | null) => void;
  openAddEditPartModal: (part: Part | null) => void;
}

export const PartListPanel: React.FC<PartListPanelProps> = ({
  parts,
  loadingParts,
  partSearchTerm,
  setPartSearchTerm,
  filteredParts,
  selectedPart,
  setSelectedPart,
  openAddEditPartModal,
}) => {
  return (
    <>
      {/* Stats Bar for Parts */}
      <div className="warehouse-stats-row">
        <div className="w-stat-card">
          <Boxes size={24} className="stat-icon total" />
          <div className="stat-text">
            <span className="stat-val">{parts.length}</span>
            <span className="stat-lbl">Loại linh kiện</span>
          </div>
        </div>
        <div className="w-stat-card">
          <Layers size={24} className="stat-icon available" />
          <div className="stat-text">
            <span className="stat-val text-success">
              {parts.reduce((sum, p) => sum + p.totalQuantity, 0)}
            </span>
            <span className="stat-lbl">Tổng tồn kho</span>
          </div>
        </div>
        <div className="w-stat-card">
          <CheckCircle size={24} className="stat-icon checkedout" />
          <div className="stat-text">
            <span className="stat-val text-warning">
              {parts.filter((p) => p.totalQuantity < p.minAmount).length}
            </span>
            <span className="stat-lbl">Dưới định mức</span>
          </div>
        </div>
        <div className="w-stat-card">
          <History size={24} className="stat-icon maintenance" />
          <div className="stat-text">
            <span className="stat-val text-danger">
              {parts.filter((p) => p.totalQuantity === 0).length}
            </span>
            <span className="stat-lbl">Hết hàng</span>
          </div>
        </div>
      </div>

      {/* Search & Actions Bar for Parts */}
      <div className="warehouse-control-bar">
        <div className="search-input-wrapper flex-1">
          <Search size={18} className="search-icon" />
          <input
            type="text"
            placeholder="Tìm theo tên, IPN, danh mục linh kiện..."
            value={partSearchTerm}
            onChange={(e) => setPartSearchTerm(e.target.value)}
            className="w-search-input"
          />
        </div>

        <div className="filters-actions-wrapper">
          <button className="btn-add-board" onClick={() => openAddEditPartModal(null)}>
            <Plus size={16} />
            <span>Thêm linh kiện</span>
          </button>
        </div>
      </div>

      {/* Parts Grid Display */}
      <div className="boards-grid-wrapper">
        {loadingParts ? (
          <div className="list-status-msg">Đang tải danh sách linh kiện...</div>
        ) : filteredParts.length === 0 ? (
          <div className="list-status-msg">Không tìm thấy linh kiện nào trong kho.</div>
        ) : (
          <div className="boards-grid-list">
            {filteredParts.map((part) => {
              const isSelected = selectedPart?.id === part.id;
              const isLowStock = part.totalQuantity < part.minAmount;

              return (
                <div
                  key={part.id}
                  className={`board-grid-card ${isSelected ? 'selected' : ''}`}
                  onClick={() => setSelectedPart(part)}
                >
                  <div className="board-card-header">
                    <h4 className="board-card-title" title={part.name}>
                      {part.name}
                    </h4>
                    <span className={`board-status-dot-badge ${part.totalQuantity === 0 ? 'board-damaged' : isLowStock ? 'board-checkedout' : 'board-available'}`}>
                      {part.totalQuantity === 0 ? 'Hết hàng' : isLowStock ? 'Sắp hết' : 'Đủ hàng'}
                    </span>
                  </div>

                  <div className="board-card-specs">
                    <div className="spec-row">
                      <Tag size={12} />
                      <span>IPN: {part.ipn}</span>
                    </div>
                    <div className="spec-row">
                      <Layers size={12} />
                      <span>Danh mục: {part.categoryName || 'Chưa rõ'}</span>
                    </div>
                    <div className="spec-row">
                      <MapPin size={12} />
                      <span>Lưu tại: {part.lots.length > 0 ? part.lots.map(l => `${l.storeLocationCode} (${l.amount})`).join(', ') : 'Chưa nhập kho'}</span>
                    </div>
                  </div>

                  <div className="board-card-borrow-info" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>Tồn kho: <strong>{part.totalQuantity}</strong></span>
                    {part.minAmount > 0 && (
                      <span style={{ fontSize: '0.7rem', color: 'var(--color-text-light)' }}>Min: {part.minAmount}</span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </>
  );
};

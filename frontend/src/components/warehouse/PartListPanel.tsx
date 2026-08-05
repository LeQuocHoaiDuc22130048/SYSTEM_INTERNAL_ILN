import React, { useState } from 'react';
import { Search, Plus, Boxes, Layers, CheckCircle, History, Tag, MapPin, QrCode } from 'lucide-react';
import type { Part, PartLot } from '../../types/warehouse';

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

interface LocationGroupItem {
  part: Part;
  lot: PartLot;
}

interface LocationGroup {
  locationCode: string;
  locationName: string;
  items: LocationGroupItem[];
  totalQty: number;
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
  const [partSearchMethod, setPartSearchMethod] = useState<'general' | 'locationQr'>('general');

  // Compute location-grouped parts
  const locationGroups = React.useMemo(() => {
    const groupMap: Record<string, LocationGroup> = {};
    const term = partSearchTerm.trim().toLowerCase();

    filteredParts.forEach(part => {
      if (!part.lots || part.lots.length === 0) {
        const key = 'UNASSIGNED';
        if (!groupMap[key]) {
          groupMap[key] = {
            locationCode: 'N/A',
            locationName: 'Chưa xếp vị trí',
            items: [],
            totalQty: 0,
          };
        }
        groupMap[key].items.push({
          part,
          lot: {
            id: '',
            storeLocationId: '',
            storeLocationCode: 'N/A',
            storeLocationName: 'Chưa xếp vị trí',
            amount: part.totalQuantity,
            lotCode: 'N/A',
          },
        });
        groupMap[key].totalQty += part.totalQuantity;
      } else {
        part.lots.forEach(lot => {
          const locCode = lot.storeLocationCode || 'N/A';
          const locName = lot.storeLocationName || locCode;

          if (term && partSearchMethod === 'locationQr') {
            const matchesLoc = locCode.toLowerCase().includes(term) || locName.toLowerCase().includes(term);
            const matchesPart = part.name.toLowerCase().includes(term) || part.ipn.toLowerCase().includes(term);
            if (!matchesLoc && !matchesPart) return;
          }

          const key = lot.storeLocationId || locCode;
          if (!groupMap[key]) {
            groupMap[key] = {
              locationCode: locCode,
              locationName: locName,
              items: [],
              totalQty: 0,
            };
          }
          groupMap[key].items.push({ part, lot });
          groupMap[key].totalQty += lot.amount;
        });
      }
    });

    return Object.values(groupMap);
  }, [filteredParts, partSearchTerm, partSearchMethod]);

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
      <div className="warehouse-control-bar" style={{ flexDirection: 'column', alignItems: 'stretch', gap: '10px' }}>
        <div className="flex-row gap-2" style={{ display: 'flex', gap: '10px', width: '100%' }}>
          <div className="search-input-wrapper flex-1">
            {partSearchMethod === 'locationQr' ? (
              <QrCode size={18} className="search-icon text-primary" />
            ) : (
              <Search size={18} className="search-icon" />
            )}
            <input
              type="text"
              placeholder={
                partSearchMethod === 'locationQr'
                  ? 'Nhập hoặc quét mã QR vị trí (VD: LOC-A1, Kệ A1)...'
                  : 'Tìm theo tên, IPN, danh mục linh kiện...'
              }
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

        {/* Search Method Toggle */}
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center', fontSize: '0.85rem' }}>
          <span style={{ color: 'var(--color-text-secondary)', fontWeight: 500 }}>Phương thức tìm:</span>
          <button
            type="button"
            className={`warehouse-mode-btn ${partSearchMethod === 'general' ? 'active' : ''}`}
            onClick={() => setPartSearchMethod('general')}
            style={{ padding: '4px 12px', fontSize: '0.8rem', borderRadius: '14px' }}
          >
            🔍 Tên / IPN
          </button>
          <button
            type="button"
            className={`warehouse-mode-btn ${partSearchMethod === 'locationQr' ? 'active' : ''}`}
            onClick={() => setPartSearchMethod('locationQr')}
            style={{ padding: '4px 12px', fontSize: '0.8rem', borderRadius: '14px' }}
          >
            📍 Vị trí / QR Code
          </button>
          {partSearchMethod === 'locationQr' && partSearchTerm && (
            <span style={{ fontSize: '0.75rem', color: '#2563eb', backgroundColor: '#dbeafe', padding: '2px 8px', borderRadius: '10px' }}>
              Đang lọc vị trí: "{partSearchTerm}"
            </span>
          )}
        </div>
      </div>

      {/* Parts Grid or Location Group Display */}
      <div className="boards-grid-wrapper">
        {loadingParts ? (
          <div className="list-status-msg">Đang tải danh sách linh kiện...</div>
        ) : partSearchMethod === 'locationQr' ? (
          locationGroups.length === 0 ? (
            <div className="list-status-msg">Không tìm thấy linh kiện ở vị trí này.</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {locationGroups.map(group => (
                <div
                  key={group.locationCode}
                  style={{
                    backgroundColor: 'var(--color-bg-surface, #ffffff)',
                    border: '1px solid var(--color-border, #e2e8f0)',
                    borderRadius: '12px',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      backgroundColor: 'rgba(37, 99, 235, 0.08)',
                      padding: '10px 16px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      borderBottom: '1px solid var(--color-border, #e2e8f0)',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 600, color: '#2563eb' }}>
                      <MapPin size={18} />
                      <span>{group.locationName} ({group.locationCode})</span>
                    </div>
                    <span style={{ fontSize: '0.8rem', backgroundColor: '#2563eb', color: '#ffffff', padding: '2px 10px', borderRadius: '12px', fontWeight: 500 }}>
                      {group.items.length} loại · Tổng SL: {group.totalQty}
                    </span>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    {group.items.map(({ part, lot }, idx) => (
                      <div
                        key={`${part.id}-${idx}`}
                        onClick={() => setSelectedPart(part)}
                        style={{
                          padding: '12px 16px',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          borderBottom: idx < group.items.length - 1 ? '1px solid var(--color-border, #e2e8f0)' : 'none',
                          cursor: 'pointer',
                          backgroundColor: selectedPart?.id === part.id ? 'rgba(37, 99, 235, 0.05)' : 'transparent',
                        }}
                      >
                        <div>
                          <div style={{ fontWeight: 600, fontSize: '0.95rem' }}>{part.name}</div>
                          <div style={{ fontSize: '0.8rem', color: 'var(--color-text-secondary)', display: 'flex', gap: '12px', marginTop: '2px' }}>
                            <span>IPN: {part.ipn}</span>
                            <span>Danh mục: {part.categoryName || 'Chưa rõ'}</span>
                          </div>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#2563eb', backgroundColor: '#f1f5f9', padding: '4px 10px', borderRadius: '6px' }}>
                            Tại vị trí: {lot.amount}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          )
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


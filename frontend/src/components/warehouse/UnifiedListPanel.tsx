import React from 'react';
import {
  Search,
  Plus,
  Boxes,
  Cpu,
  MapPin,
  QrCode,
  ArrowUpRight,
  AlertTriangle,
  Package,
} from 'lucide-react';
import type { Board, Part, PartLot } from '../../types/warehouse';

interface UnifiedListPanelProps {
  boards: Board[];
  parts: Part[];
  loading: boolean;
  searchTerm: string;
  setSearchTerm: (s: string) => void;
  typeFilter: 'ALL' | 'BOARDS' | 'PARTS';
  setTypeFilter: (t: 'ALL' | 'BOARDS' | 'PARTS') => void;
  stockFilter: 'ALL' | 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK';
  setStockFilter: (s: 'ALL' | 'IN_STOCK' | 'LOW_STOCK' | 'OUT_OF_STOCK') => void;
  onSelectBoard: (b: Board) => void;
  onSelectPart: (p: Part) => void;
  onAddBoard: () => void;
  onAddPart: () => void;
  onQuickCheckoutPart?: (p: Part, lot?: PartLot) => void;
  onQuickCheckoutBoard?: (b: Board) => void;
  onScanLocationQr?: () => void;
}

export const UnifiedListPanel: React.FC<UnifiedListPanelProps> = ({
  boards,
  parts,
  loading,
  searchTerm,
  setSearchTerm,
  typeFilter,
  setTypeFilter,
  stockFilter,
  setStockFilter,
  onSelectBoard,
  onSelectPart,
  onAddBoard,
  onAddPart,
  onQuickCheckoutPart,
  onQuickCheckoutBoard,
}) => {
  // 1. Calculate Stats
  const totalBoards = boards.length;
  const totalParts = parts.length;
  const totalItems = totalBoards + totalParts;

  const lowStockBoards = boards.filter(
    (b) => (b.quantity || 1) <= (b.minQuantity || 0) && (b.minQuantity || 0) > 0
  ).length;
  const lowStockParts = parts.filter(
    (p) => p.totalQuantity <= p.minAmount && p.totalQuantity > 0
  ).length;
  const totalLowStock = lowStockBoards + lowStockParts;


  // 2. Filter Boards
  const q = searchTerm.toLowerCase().trim();

  const filteredBoards = boards.filter((b) => {
    if (typeFilter === 'PARTS') return false;
    const qty = b.quantity || 1;
    const minQty = b.minQuantity || 0;

    if (stockFilter === 'IN_STOCK' && qty <= 0) return false;
    if (stockFilter === 'LOW_STOCK' && (qty > minQty || minQty === 0)) return false;
    if (stockFilter === 'OUT_OF_STOCK' && qty > 0) return false;

    if (q) {
      const match =
        b.name.toLowerCase().includes(q) ||
        b.qrCode.toLowerCase().includes(q) ||
        (b.model && b.model.toLowerCase().includes(q)) ||
        (b.location && b.location.toLowerCase().includes(q));
      if (!match) return false;
    }
    return true;
  });

  // 3. Filter Parts
  const filteredParts = parts.filter((p) => {
    if (typeFilter === 'BOARDS') return false;
    const qty = p.totalQuantity;
    const minQty = p.minAmount || 0;

    if (stockFilter === 'IN_STOCK' && qty <= 0) return false;
    if (stockFilter === 'LOW_STOCK' && (qty > minQty || minQty === 0)) return false;
    if (stockFilter === 'OUT_OF_STOCK' && qty > 0) return false;

    if (q) {
      const match =
        p.name.toLowerCase().includes(q) ||
        p.ipn.toLowerCase().includes(q) ||
        (p.categoryName && p.categoryName.toLowerCase().includes(q)) ||
        (p.description && p.description.toLowerCase().includes(q)) ||
        p.lots.some(
          (l) =>
            l.storeLocationCode.toLowerCase().includes(q) ||
            l.storeLocationName.toLowerCase().includes(q)
        );
      if (!match) return false;
    }
    return true;
  });

  // Combine list
  type UnifiedRow =
    | { kind: 'BOARD'; data: Board }
    | { kind: 'PART'; data: Part };

  const combinedItems: UnifiedRow[] = [
    ...filteredBoards.map((b) => ({ kind: 'BOARD' as const, data: b })),
    ...filteredParts.map((p) => ({ kind: 'PART' as const, data: p })),
  ];

  combinedItems.sort((a, b) => a.data.name.localeCompare(b.data.name));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
      {/* 4 Summary Stats Cards */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '12px',
        }}
      >
        <div
          onClick={() => {
            setTypeFilter('ALL');
            setStockFilter('ALL');
          }}
          style={{
            backgroundColor: '#ffffff',
            padding: '14px 16px',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '10px',
              backgroundColor: '#eff6ff',
              color: '#2563eb',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Package size={22} />
          </div>
          <div>
            <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600 }}>
              TỔNG MẶT HÀNG
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: 700, color: '#0f172a' }}>
              {totalItems}
            </div>
          </div>
        </div>

        <div
          onClick={() => {
            setTypeFilter('BOARDS');
            setStockFilter('ALL');
          }}
          style={{
            backgroundColor: '#ffffff',
            padding: '14px 16px',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '10px',
              backgroundColor: '#e0f2fe',
              color: '#0284c7',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Cpu size={22} />
          </div>
          <div>
            <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600 }}>
              BO MẠCH
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: 700, color: '#0284c7' }}>
              {totalBoards}
            </div>
          </div>
        </div>

        <div
          onClick={() => {
            setTypeFilter('PARTS');
            setStockFilter('ALL');
          }}
          style={{
            backgroundColor: '#ffffff',
            padding: '14px 16px',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '10px',
              backgroundColor: '#fef3c7',
              color: '#d97706',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Boxes size={22} />
          </div>
          <div>
            <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600 }}>
              LINH KIỆN RỜI
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: 700, color: '#d97706' }}>
              {totalParts}
            </div>
          </div>
        </div>

        <div
          onClick={() => setStockFilter('LOW_STOCK')}
          style={{
            backgroundColor: '#ffffff',
            padding: '14px 16px',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '10px',
              backgroundColor: '#fee2e2',
              color: '#ef4444',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <AlertTriangle size={22} />
          </div>
          <div>
            <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600 }}>
              SẮP HẾT / CẦN NHẬP
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: 700, color: '#ef4444' }}>
              {totalLowStock}
            </div>
          </div>
        </div>
      </div>

      {/* Filter and Action Bar */}
      <div
        style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: '12px',
          justifyContent: 'space-between',
          alignItems: 'center',
          backgroundColor: '#ffffff',
          padding: '12px 16px',
          borderRadius: '12px',
          border: '1px solid #e2e8f0',
        }}
      >
        {/* Search Box */}
        <div style={{ position: 'relative', flex: '1 1 260px', maxWidth: '420px' }}>
          <Search
            size={16}
            style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#94a3b8',
            }}
          />
          <input
            type="text"
            placeholder="Tìm theo tên, mã QR, IPN, vị trí..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              width: '100%',
              padding: '8px 12px 8px 36px',
              fontSize: '0.88rem',
              border: '1.5px solid #cbd5e1',
              borderRadius: '8px',
              outline: 'none',
            }}
          />
        </div>

        {/* Type & Stock Filters */}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', alignItems: 'center' }}>
          {/* Type Filter */}
          <div
            style={{
              display: 'flex',
              gap: '4px',
              backgroundColor: '#f1f5f9',
              padding: '3px',
              borderRadius: '8px',
            }}
          >
            <button
              type="button"
              onClick={() => setTypeFilter('ALL')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: typeFilter === 'ALL' ? '#2563eb' : 'transparent',
                color: typeFilter === 'ALL' ? '#ffffff' : '#64748b',
              }}
            >
              Tất cả ({totalItems})
            </button>
            <button
              type="button"
              onClick={() => setTypeFilter('BOARDS')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: typeFilter === 'BOARDS' ? '#0284c7' : 'transparent',
                color: typeFilter === 'BOARDS' ? '#ffffff' : '#64748b',
              }}
            >
              📱 Bo Mạch ({totalBoards})
            </button>
            <button
              type="button"
              onClick={() => setTypeFilter('PARTS')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: typeFilter === 'PARTS' ? '#d97706' : 'transparent',
                color: typeFilter === 'PARTS' ? '#ffffff' : '#64748b',
              }}
            >
              ⚙️ Linh Kiện ({totalParts})
            </button>
          </div>

          {/* Stock Filter Pills */}
          <select
            value={stockFilter}
            onChange={(e) => setStockFilter(e.target.value as any)}
            style={{
              padding: '6px 10px',
              borderRadius: '8px',
              border: '1px solid #cbd5e1',
              fontSize: '0.82rem',
              fontWeight: 500,
              backgroundColor: '#ffffff',
              color: '#334155',
            }}
          >
            <option value="ALL">📦 Tất cả trạng thái</option>
            <option value="IN_STOCK">✅ Còn hàng</option>
            <option value="LOW_STOCK">⚠️ Sắp hết hàng</option>
            <option value="OUT_OF_STOCK">❌ Hết hàng</option>
          </select>
        </div>

        {/* Action Buttons */}
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            type="button"
            onClick={onAddBoard}
            style={{
              backgroundColor: '#0284c7',
              color: '#ffffff',
              border: 'none',
              padding: '8px 12px',
              borderRadius: '8px',
              fontWeight: 600,
              fontSize: '0.82rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
            }}
          >
            <Plus size={15} />
            Bo Mạch
          </button>
          <button
            type="button"
            onClick={onAddPart}
            style={{
              backgroundColor: '#d97706',
              color: '#ffffff',
              border: 'none',
              padding: '8px 12px',
              borderRadius: '8px',
              fontWeight: 600,
              fontSize: '0.82rem',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
            }}
          >
            <Plus size={15} />
            Linh Kiện
          </button>
        </div>
      </div>

      {/* List / Grid of Combined Items */}
      {loading ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>
          Đang tải danh sách kho...
        </div>
      ) : combinedItems.length === 0 ? (
        <div
          style={{
            backgroundColor: '#ffffff',
            padding: '48px 24px',
            borderRadius: '12px',
            textAlign: 'center',
            border: '1px dashed #cbd5e1',
          }}
        >
          <div style={{ fontSize: '3rem', marginBottom: '8px' }}>📦</div>
          <div style={{ fontSize: '1.1rem', fontWeight: 600, color: '#334155' }}>
            Không tìm thấy mặt hàng nào
          </div>
          <div style={{ fontSize: '0.88rem', color: '#64748b', marginTop: '4px' }}>
            Hãy thử thay đổi từ khóa tìm kiếm hoặc bộ lọc.
          </div>
        </div>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
            gap: '14px',
          }}
        >
          {combinedItems.map((item) => {
            if (item.kind === 'BOARD') {
              const b = item.data;
              const qty = b.quantity || 1;
              const minQty = b.minQuantity || 0;
              const isLowStock = qty <= minQty && minQty > 0;
              const isOutOfStock = qty <= 0;

              return (
                <div
                  key={'board-' + b.id}
                  onClick={() => onSelectBoard(b)}
                  style={{
                    backgroundColor: '#ffffff',
                    borderRadius: '12px',
                    border: '1.5px solid #e2e8f0',
                    padding: '16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    gap: '12px',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = '#0284c7';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(2,132,199,0.12)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = '#e2e8f0';
                    e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.04)';
                  }}
                >
                  <div>
                    {/* Header: Title & Badges */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px', marginBottom: '8px' }}>
                      <div style={{ fontWeight: 700, fontSize: '1rem', color: '#0f172a' }}>
                        {b.name}
                      </div>
                      <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 700,
                            padding: '3px 8px',
                            borderRadius: '6px',
                            backgroundColor: '#e0f2fe',
                            color: '#0369a1',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '3px',
                          }}
                        >
                          <Cpu size={12} /> Bo mạch
                        </span>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 600,
                            padding: '3px 8px',
                            borderRadius: '6px',
                            backgroundColor: isOutOfStock ? '#fee2e2' : isLowStock ? '#fef3c7' : '#dcfce7',
                            color: isOutOfStock ? '#b91c1c' : isLowStock ? '#b45309' : '#15803d',
                          }}
                        >
                          {isOutOfStock ? 'Hết hàng' : isLowStock ? 'Sắp hết' : 'Sẵn sàng'}
                        </span>
                      </div>
                    </div>

                    {/* Metadata lines */}
                    <div style={{ fontSize: '0.82rem', color: '#64748b', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <QrCode size={14} color="#64748b" />
                        <span>Mã QR: <strong>{b.qrCode}</strong></span>
                        {b.model && <span style={{ color: '#94a3b8' }}>• Model: {b.model}</span>}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <MapPin size={14} color="#64748b" />
                        <span>Vị trí kệ: <strong>{b.location || 'Chưa phân vị trí'}</strong></span>
                      </div>
                    </div>
                  </div>

                  {/* Footer: Quantity & Action */}
                  <div
                    style={{
                      borderTop: '1px solid #f1f5f9',
                      paddingTop: '10px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Tồn kho: </span>
                      <strong style={{ fontSize: '1.05rem', color: isOutOfStock ? '#ef4444' : '#0f172a' }}>
                        {qty} Cái
                      </strong>
                      {minQty > 0 && (
                        <span style={{ fontSize: '0.75rem', color: '#94a3b8', marginLeft: '6px' }}>
                          (Min: {minQty})
                        </span>
                      )}
                    </div>

                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        if (onQuickCheckoutBoard) onQuickCheckoutBoard(b);
                      }}
                      style={{
                        backgroundColor: '#f8fafc',
                        border: '1px solid #cbd5e1',
                        color: '#0284c7',
                        padding: '5px 10px',
                        borderRadius: '6px',
                        fontSize: '0.78rem',
                        fontWeight: 600,
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                      }}
                    >
                      <ArrowUpRight size={13} />
                      Lấy bo
                    </button>
                  </div>
                </div>
              );
            } else {
              const p = item.data;
              const qty = p.totalQuantity;
              const minQty = p.minAmount || 0;
              const isLowStock = qty <= minQty && minQty > 0;
              const isOutOfStock = qty <= 0;

              return (
                <div
                  key={'part-' + p.id}
                  onClick={() => onSelectPart(p)}
                  style={{
                    backgroundColor: '#ffffff',
                    borderRadius: '12px',
                    border: '1.5px solid #e2e8f0',
                    padding: '16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    gap: '12px',
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = '#d97706';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(217,119,6,0.12)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = '#e2e8f0';
                    e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.04)';
                  }}
                >
                  <div>
                    {/* Header: Title & Badges */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '8px', marginBottom: '8px' }}>
                      <div style={{ fontWeight: 700, fontSize: '1rem', color: '#0f172a' }}>
                        {p.name}
                      </div>
                      <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap', justifyContent: 'flex-end' }}>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 700,
                            padding: '3px 8px',
                            borderRadius: '6px',
                            backgroundColor: '#fef3c7',
                            color: '#b45309',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '3px',
                          }}
                        >
                          <Boxes size={12} /> Linh kiện
                        </span>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 600,
                            padding: '3px 8px',
                            borderRadius: '6px',
                            backgroundColor: isOutOfStock ? '#fee2e2' : isLowStock ? '#fef3c7' : '#dcfce7',
                            color: isOutOfStock ? '#b91c1c' : isLowStock ? '#b45309' : '#15803d',
                          }}
                        >
                          {isOutOfStock ? 'Hết hàng' : isLowStock ? 'Sắp hết' : 'Đủ hàng'}
                        </span>
                      </div>
                    </div>

                    {/* Metadata lines */}
                    <div style={{ fontSize: '0.82rem', color: '#64748b', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <QrCode size={14} color="#64748b" />
                        <span>IPN: <strong>{p.ipn}</strong></span>
                        {p.categoryName && <span style={{ color: '#94a3b8' }}>• {p.categoryName}</span>}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <MapPin size={14} color="#64748b" />
                        <span>
                          Vị trí:{' '}
                          <strong>
                            {p.lots && p.lots.length > 0
                              ? p.lots
                                  .filter((l) => l.amount > 0)
                                  .map((l) => `${l.storeLocationCode} (${l.amount})`)
                                  .join(', ') || 'Chưa xếp vị trí'
                              : 'Chưa xếp vị trí'}
                          </strong>
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Footer: Quantity & Action */}
                  <div
                    style={{
                      borderTop: '1px solid #f1f5f9',
                      paddingTop: '10px',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <div>
                      <span style={{ fontSize: '0.75rem', color: '#64748b' }}>Tồn kho: </span>
                      <strong style={{ fontSize: '1.05rem', color: isOutOfStock ? '#ef4444' : '#0f172a' }}>
                        {qty} Cái
                      </strong>
                      {minQty > 0 && (
                        <span style={{ fontSize: '0.75rem', color: '#94a3b8', marginLeft: '6px' }}>
                          (Min: {minQty})
                        </span>
                      )}
                    </div>

                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        if (onQuickCheckoutPart) onQuickCheckoutPart(p);
                      }}
                      style={{
                        backgroundColor: '#f8fafc',
                        border: '1px solid #cbd5e1',
                        color: '#d97706',
                        padding: '5px 10px',
                        borderRadius: '6px',
                        fontSize: '0.78rem',
                        fontWeight: 600,
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                      }}
                    >
                      <ArrowUpRight size={13} />
                      Lấy linh kiện
                    </button>
                  </div>
                </div>
              );
            }
          })}
        </div>
      )}
    </div>
  );
};

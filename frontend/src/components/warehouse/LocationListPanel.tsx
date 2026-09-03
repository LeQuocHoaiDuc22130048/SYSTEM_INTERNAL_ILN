import React, { useState, useMemo } from 'react';
import {
  Search,
  Plus,
  Edit2,
  Trash2,
  Printer,
  MapPin,
  PackageCheck,
  Boxes,
  Layers,
  X,
  AlertCircle,
  QrCode,
  ArrowRight,
  LayoutGrid,
  List,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../../utils/auth';

export interface LocationItem {
  id: string;
  code: string;
  name: string;
  description?: string;
  qrCode?: string;
  totalPartTypes?: number;
  totalQuantity?: number;
  partTypesCount?: number;
  partQuantity?: number;
  boardTypesCount?: number;
  boardQuantity?: number;
}

interface LocationListPanelProps {
  locations: LocationItem[];
  onRefreshLocations: () => Promise<void>;
  onPrintLocationQr: (location: LocationItem) => void;
  onPrintAllLocationsQr: () => void;
  onScanLocationQr: () => void;
  onViewLocationParts: (locationCode: string) => void;
  showToast: (msg: string) => void;
}

export const LocationListPanel: React.FC<LocationListPanelProps> = ({
  locations,
  onRefreshLocations,
  onPrintLocationQr,
  onPrintAllLocationsQr,
  onScanLocationQr,
  onViewLocationParts,
  showToast,
}) => {
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'OCCUPIED' | 'EMPTY'>('ALL');
  const [viewMode, setViewMode] = useState<'grid' | 'table'>('grid');

  const [editingLocation, setEditingLocation] = useState<LocationItem | null>(null);
  const [isFormOpen, setIsFormOpen] = useState<boolean>(false);
  const [formCode, setFormCode] = useState<string>('');
  const [formName, setFormName] = useState<string>('');
  const [formDesc, setFormDesc] = useState<string>('');
  const [formQr, setFormQr] = useState<string>('');
  const [isSaving, setIsSaving] = useState<boolean>(false);

  const [deletingLocation, setDeletingLocation] = useState<LocationItem | null>(null);
  const [isDeleting, setIsDeleting] = useState<boolean>(false);

  // Statistics
  const occupiedCount = useMemo(
    () => locations.filter((l) => (l.totalPartTypes || 0) > 0 || (l.totalQuantity || 0) > 0).length,
    [locations]
  );
  const emptyCount = locations.length - occupiedCount;
  const totalItemsStored = useMemo(
    () => locations.reduce((sum, l) => sum + (l.totalQuantity || 0), 0),
    [locations]
  );

  const filteredLocations = useMemo(() => {
    let result = locations;

    // Status filter
    if (statusFilter === 'OCCUPIED') {
      result = result.filter((l) => (l.totalPartTypes || 0) > 0 || (l.totalQuantity || 0) > 0);
    } else if (statusFilter === 'EMPTY') {
      result = result.filter((l) => (l.totalPartTypes || 0) === 0 && (l.totalQuantity || 0) === 0);
    }

    // Search term filter
    const term = searchTerm.toLowerCase().trim();
    if (term) {
      result = result.filter(
        (l) =>
          l.name.toLowerCase().includes(term) ||
          l.code.toLowerCase().includes(term) ||
          (l.qrCode && l.qrCode.toLowerCase().includes(term)) ||
          (l.description && l.description.toLowerCase().includes(term))
      );
    }

    return result;
  }, [locations, statusFilter, searchTerm]);

  const openCreateForm = () => {
    setEditingLocation(null);
    setFormCode('');
    setFormName('');
    setFormDesc('');
    setFormQr('');
    setIsFormOpen(true);
  };

  const openEditForm = (loc: LocationItem) => {
    setEditingLocation(loc);
    setFormCode(loc.code);
    setFormName(loc.name);
    setFormDesc(loc.description || '');
    setFormQr(loc.qrCode || loc.code);
    setIsFormOpen(true);
  };

  const handleSaveLocation = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formCode.trim() || !formName.trim()) {
      showToast('Vui lòng nhập đầy đủ Mã vị trí và Tên vị trí');
      return;
    }

    setIsSaving(true);
    try {
      if (editingLocation) {
        // Update
        const res = await fetch(`/api/v1/parts/locations/${editingLocation.id}`, {
          method: 'PATCH',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify({
            code: formCode.trim().toUpperCase(),
            name: formName.trim(),
            description: formDesc.trim() || undefined,
            qrCode: formQr.trim() || formCode.trim().toUpperCase(),
          }),
        });
        const json = await res.json();
        if (res.ok && json.success) {
          showToast('Cập nhật vị trí kho thành công');
          setIsFormOpen(false);
          await onRefreshLocations();
        } else {
          showToast(json.message || 'Lỗi khi cập nhật vị trí kho');
        }
      } else {
        // Create
        const res = await fetch('/api/v1/parts/locations', {
          method: 'POST',
          headers: getJsonAuthHeaders(),
          body: JSON.stringify({
            code: formCode.trim().toUpperCase(),
            name: formName.trim(),
            description: formDesc.trim() || undefined,
            qrCode: formQr.trim() || formCode.trim().toUpperCase(),
          }),
        });
        const json = await res.json();
        if (res.ok && json.success) {
          showToast('Tạo vị trí kho mới thành công');
          setIsFormOpen(false);
          await onRefreshLocations();
        } else {
          showToast(json.message || 'Lỗi khi tạo vị trí kho');
        }
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi lưu vị trí kho');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDeleteLocation = async () => {
    if (!deletingLocation) return;
    setIsDeleting(true);
    try {
      const res = await fetch(`/api/v1/parts/locations/${deletingLocation.id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      const json = await res.json();
      if (res.ok && json.success) {
        showToast(`Đã xóa vị trí ${deletingLocation.name}`);
        setDeletingLocation(null);
        await onRefreshLocations();
      } else {
        showToast(json.message || 'Không thể xóa vị trí kho này');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi xóa vị trí kho');
    } finally {
      setIsDeleting(false);
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', height: '100%' }}>
      {/* Top Stat KPI Cards - 4 Column Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '14px',
        }}
      >
        <div
          onClick={() => setStatusFilter('ALL')}
          style={{
            backgroundColor: '#ffffff',
            borderRadius: '12px',
            border: statusFilter === 'ALL' ? '2px solid #2563eb' : '1px solid #e2e8f0',
            padding: '14px 18px',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
            transition: 'all 0.15s ease',
          }}
        >
          <div
            style={{
              width: '46px',
              height: '46px',
              borderRadius: '10px',
              backgroundColor: '#eff6ff',
              color: '#2563eb',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <MapPin size={22} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 500 }}>Tổng Số Vị Trí / Kệ</span>
            <strong style={{ fontSize: '20px', color: '#0f172a', fontWeight: 700 }}>{locations.length}</strong>
          </div>
        </div>

        <div
          onClick={() => setStatusFilter('OCCUPIED')}
          style={{
            backgroundColor: '#ffffff',
            borderRadius: '12px',
            border: statusFilter === 'OCCUPIED' ? '2px solid #059669' : '1px solid #e2e8f0',
            padding: '14px 18px',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
            transition: 'all 0.15s ease',
          }}
        >
          <div
            style={{
              width: '46px',
              height: '46px',
              borderRadius: '10px',
              backgroundColor: '#ecfdf5',
              color: '#059669',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <Boxes size={22} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 500 }}>Vị Trí Đang Chứa Hàng</span>
            <strong style={{ fontSize: '20px', color: '#059669', fontWeight: 700 }}>{occupiedCount}</strong>
          </div>
        </div>

        <div
          onClick={() => setStatusFilter('EMPTY')}
          style={{
            backgroundColor: '#ffffff',
            borderRadius: '12px',
            border: statusFilter === 'EMPTY' ? '2px solid #64748b' : '1px solid #e2e8f0',
            padding: '14px 18px',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            cursor: 'pointer',
            boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
            transition: 'all 0.15s ease',
          }}
        >
          <div
            style={{
              width: '46px',
              height: '46px',
              borderRadius: '10px',
              backgroundColor: '#f8fafc',
              color: '#64748b',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <PackageCheck size={22} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 500 }}>Vị Trí Còn Trống (0 LK)</span>
            <strong style={{ fontSize: '20px', color: '#334155', fontWeight: 700 }}>{emptyCount}</strong>
          </div>
        </div>

        <div
          style={{
            backgroundColor: '#ffffff',
            borderRadius: '12px',
            border: '1px solid #e2e8f0',
            padding: '14px 18px',
            display: 'flex',
            alignItems: 'center',
            gap: '14px',
            boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
          }}
        >
          <div
            style={{
              width: '46px',
              height: '46px',
              borderRadius: '10px',
              backgroundColor: '#fef3c7',
              color: '#d97706',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <Layers size={22} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 500 }}>Tổng Lượng Tồn Kho</span>
            <strong style={{ fontSize: '20px', color: '#d97706', fontWeight: 700 }}>{totalItemsStored}</strong>
          </div>
        </div>
      </div>

      {/* Action Toolbar */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px',
          backgroundColor: '#ffffff',
          padding: '12px 16px',
          borderRadius: '12px',
          border: '1px solid #e2e8f0',
          boxShadow: '0 1px 3px rgba(0,0,0,0.03)',
        }}
      >
        {/* Left: Search & Filter Pills */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', flex: '1 1 360px', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative', flex: '1 1 240px', minWidth: '220px' }}>
            <Search size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Tìm theo tên, mã kệ hoặc vị trí kho..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{
                width: '100%',
                padding: '8px 12px 8px 36px',
                fontSize: '13px',
                borderRadius: '8px',
                border: '1px solid #cbd5e1',
                outline: 'none',
                backgroundColor: '#f8fafc',
                color: '#0f172a',
              }}
            />
          </div>

          <div style={{ display: 'flex', backgroundColor: '#f1f5f9', padding: '3px', borderRadius: '8px', gap: '4px' }}>
            <button
              type="button"
              onClick={() => setStatusFilter('ALL')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: statusFilter === 'ALL' ? '#2563eb' : 'transparent',
                color: statusFilter === 'ALL' ? '#ffffff' : '#64748b',
                transition: 'all 0.15s ease',
              }}
            >
              Tất cả ({locations.length})
            </button>
            <button
              type="button"
              onClick={() => setStatusFilter('OCCUPIED')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: statusFilter === 'OCCUPIED' ? '#059669' : 'transparent',
                color: statusFilter === 'OCCUPIED' ? '#ffffff' : '#64748b',
                transition: 'all 0.15s ease',
              }}
            >
              Có hàng ({occupiedCount})
            </button>
            <button
              type="button"
              onClick={() => setStatusFilter('EMPTY')}
              style={{
                border: 'none',
                padding: '6px 12px',
                borderRadius: '6px',
                fontSize: '12px',
                fontWeight: 600,
                cursor: 'pointer',
                backgroundColor: statusFilter === 'EMPTY' ? '#64748b' : 'transparent',
                color: statusFilter === 'EMPTY' ? '#ffffff' : '#64748b',
                transition: 'all 0.15s ease',
              }}
            >
              Trống ({emptyCount})
            </button>
          </div>
        </div>

        {/* Right: View toggle & Action Buttons */}
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
          {/* View mode toggle */}
          <div style={{ display: 'flex', border: '1px solid #cbd5e1', borderRadius: '8px', overflow: 'hidden' }}>
            <button
              type="button"
              onClick={() => setViewMode('grid')}
              style={{
                border: 'none',
                padding: '7px 12px',
                backgroundColor: viewMode === 'grid' ? '#e2e8f0' : '#ffffff',
                color: viewMode === 'grid' ? '#0f172a' : '#64748b',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
                fontSize: '12px',
                fontWeight: 600,
              }}
              title="Xem dạng thẻ lưới"
            >
              <LayoutGrid size={14} />
              <span>Lưới</span>
            </button>
            <button
              type="button"
              onClick={() => setViewMode('table')}
              style={{
                border: 'none',
                padding: '7px 12px',
                backgroundColor: viewMode === 'table' ? '#e2e8f0' : '#ffffff',
                color: viewMode === 'table' ? '#0f172a' : '#64748b',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
                fontSize: '12px',
                fontWeight: 600,
              }}
              title="Xem dạng bảng chi tiết"
            >
              <List size={14} />
              <span>Bảng</span>
            </button>
          </div>

          <button
            type="button"
            onClick={onScanLocationQr}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              backgroundColor: '#ffffff',
              color: '#0f172a',
              border: '1px solid #cbd5e1',
              borderRadius: '8px',
              padding: '7px 12px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            <QrCode size={15} color="#2563eb" />
            <span>Quét QR</span>
          </button>

          <button
            type="button"
            onClick={onPrintAllLocationsQr}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              backgroundColor: '#ffffff',
              color: '#0284c7',
              border: '1px solid #bae6fd',
              borderRadius: '8px',
              padding: '7px 12px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            <Printer size={15} color="#0284c7" />
            <span>In Tem QR</span>
          </button>

          <button
            type="button"
            onClick={openCreateForm}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '6px',
              backgroundColor: '#2563eb',
              color: '#ffffff',
              border: 'none',
              borderRadius: '8px',
              padding: '8px 16px',
              fontSize: '13px',
              fontWeight: 600,
              cursor: 'pointer',
              boxShadow: '0 2px 4px rgba(37,99,235,0.2)',
            }}
          >
            <Plus size={16} />
            <span>+ Thêm Vị Trí Mới</span>
          </button>
        </div>
      </div>

      {/* Content: Table View or Grid View */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {filteredLocations.length === 0 ? (
          <div className="empty-state-box" style={{ padding: '60px 20px', backgroundColor: '#ffffff', borderRadius: '12px', border: '1px dashed #cbd5e1' }}>
            <MapPin size={48} style={{ margin: '0 auto 12px auto', color: '#cbd5e1' }} />
            <h4 style={{ fontSize: '16px', fontWeight: 600, color: '#334155' }}>
              {searchTerm ? 'Không tìm thấy vị trí nào khớp từ khóa' : 'Chưa có vị trí lưu kho nào'}
            </h4>
            <p style={{ fontSize: '13px', color: '#64748b' }}>
              {searchTerm ? 'Vui lòng thử từ khóa khác' : 'Bấm "+ Thêm Vị Trí Mới" để bắt đầu thiết lập sơ đồ kho'}
            </p>
          </div>
        ) : viewMode === 'table' ? (
          // TABLE VIEW
          <div style={{ backgroundColor: '#ffffff', borderRadius: '12px', border: '1px solid #e2e8f0', overflow: 'hidden', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '13px' }}>
                <thead>
                  <tr style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid #e2e8f0', color: '#475569', fontWeight: 700 }}>
                    <th style={{ padding: '12px 16px' }}>Mã Vị Trí</th>
                    <th style={{ padding: '12px 16px' }}>Tên Vị Trí / Kệ</th>
                    <th style={{ padding: '12px 16px' }}>Mô Tả</th>
                    <th style={{ padding: '12px 16px' }}>Mã QR</th>
                    <th style={{ padding: '12px 16px', textAlign: 'center' }}>Linh Kiện</th>
                    <th style={{ padding: '12px 16px', textAlign: 'center' }}>Bo Mạch</th>
                    <th style={{ padding: '12px 16px', textAlign: 'center' }}>Tổng Tồn</th>
                    <th style={{ padding: '12px 16px', textAlign: 'center' }}>Trạng Thái</th>
                    <th style={{ padding: '12px 16px', textAlign: 'right' }}>Thao Tác</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredLocations.map((loc, idx) => {
                    const partCount = loc.partTypesCount !== undefined ? loc.partTypesCount : (loc.totalPartTypes || 0);
                    const partQty = loc.partQuantity !== undefined ? loc.partQuantity : 0;
                    const boardCount = loc.boardTypesCount !== undefined ? loc.boardTypesCount : 0;
                    const boardQty = loc.boardQuantity !== undefined ? loc.boardQuantity : 0;
                    const totalQty = loc.totalQuantity !== undefined ? loc.totalQuantity : (partQty + boardQty);
                    const isOccupied = partCount > 0 || partQty > 0 || boardCount > 0 || boardQty > 0;

                    return (
                      <tr
                        key={loc.id}
                        style={{
                          borderBottom: '1px solid #f1f5f9',
                          backgroundColor: idx % 2 === 0 ? '#ffffff' : '#fafafa',
                          transition: 'background-color 0.15s ease',
                        }}
                        onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#f0f7ff')}
                        onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = idx % 2 === 0 ? '#ffffff' : '#fafafa')}
                      >
                        <td style={{ padding: '12px 16px' }}>
                          <span
                            style={{
                              backgroundColor: '#f1f5f9',
                              border: '1px solid #cbd5e1',
                              borderRadius: '6px',
                              padding: '3px 8px',
                              fontSize: '12px',
                              fontWeight: 800,
                              color: '#1e293b',
                              fontFamily: 'monospace',
                            }}
                          >
                            {loc.code}
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px', fontWeight: 600, color: '#0f172a' }}>
                          {loc.name}
                        </td>
                        <td style={{ padding: '12px 16px', color: '#64748b', maxWidth: '240px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {loc.description || '-'}
                        </td>
                        <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontSize: '12px', color: '#475569' }}>
                          {loc.qrCode || loc.code}
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center' }}>
                          <span
                            style={{
                              fontSize: '11px',
                              fontWeight: 600,
                              padding: '2px 8px',
                              borderRadius: '6px',
                              backgroundColor: partQty > 0 || partCount > 0 ? '#ecfdf5' : '#f8fafc',
                              color: partQty > 0 || partCount > 0 ? '#059669' : '#94a3b8',
                              border: `1px solid ${partQty > 0 || partCount > 0 ? '#a7f3d0' : '#e2e8f0'}`,
                            }}
                          >
                            📦 {partCount} loại ({partQty})
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center' }}>
                          <span
                            style={{
                              fontSize: '11px',
                              fontWeight: 600,
                              padding: '2px 8px',
                              borderRadius: '6px',
                              backgroundColor: boardQty > 0 || boardCount > 0 ? '#eff6ff' : '#f8fafc',
                              color: boardQty > 0 || boardCount > 0 ? '#2563eb' : '#94a3b8',
                              border: `1px solid ${boardQty > 0 || boardCount > 0 ? '#bfdbfe' : '#e2e8f0'}`,
                            }}
                          >
                            ⚡ {boardCount} loại ({boardQty})
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center', fontWeight: 700, color: isOccupied ? '#0f172a' : '#94a3b8' }}>
                          {totalQty}
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'center' }}>
                          <span
                            style={{
                              fontSize: '11px',
                              fontWeight: 600,
                              padding: '3px 8px',
                              borderRadius: '12px',
                              backgroundColor: isOccupied ? '#ecfdf5' : '#f1f5f9',
                              color: isOccupied ? '#059669' : '#64748b',
                            }}
                          >
                            {isOccupied ? 'Có hàng' : 'Trống'}
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', gap: '6px', alignItems: 'center' }}>
                            {isOccupied && (
                              <button
                                type="button"
                                title="Xem các linh kiện tại vị trí này"
                                onClick={() => onViewLocationParts(loc.code)}
                                style={{
                                  background: '#eff6ff',
                                  border: '1px solid #bfdbfe',
                                  borderRadius: '6px',
                                  padding: '4px 8px',
                                  color: '#2563eb',
                                  cursor: 'pointer',
                                  fontSize: '12px',
                                  fontWeight: 600,
                                  display: 'inline-flex',
                                  alignItems: 'center',
                                  gap: '3px',
                                }}
                              >
                                <span>Xem LK</span>
                              </button>
                            )}
                            <button
                              type="button"
                              title="In tem QR vị trí"
                              onClick={() => onPrintLocationQr(loc)}
                              style={{
                                background: '#f0f9ff',
                                border: '1px solid #bae6fd',
                                borderRadius: '6px',
                                padding: '4px 8px',
                                color: '#0284c7',
                                cursor: 'pointer',
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '4px',
                                fontSize: '12px',
                                fontWeight: 600,
                              }}
                            >
                              <Printer size={13} />
                              <span>In QR</span>
                            </button>
                            <button
                              type="button"
                              title="Chỉnh sửa thông tin vị trí"
                              onClick={() => openEditForm(loc)}
                              style={{
                                background: '#f8fafc',
                                border: '1px solid #cbd5e1',
                                borderRadius: '6px',
                                padding: '4px 8px',
                                color: '#334155',
                                cursor: 'pointer',
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '4px',
                                fontSize: '12px',
                                fontWeight: 600,
                              }}
                            >
                              <Edit2 size={13} />
                              <span>Sửa</span>
                            </button>
                            <button
                              type="button"
                              title="Xóa vị trí này"
                              onClick={() => setDeletingLocation(loc)}
                              style={{
                                background: '#fee2e2',
                                border: '1.5px solid #fca5a5',
                                borderRadius: '6px',
                                padding: '4px 10px',
                                color: '#dc2626',
                                cursor: 'pointer',
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '4px',
                                fontSize: '12px',
                                fontWeight: 700,
                              }}
                            >
                              <Trash2 size={13} />
                              <span>Xóa</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        ) : (
          // GRID CARDS VIEW
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))',
              gap: '16px',
            }}
          >
            {filteredLocations.map((loc) => {
              const partCount = loc.partTypesCount !== undefined ? loc.partTypesCount : (loc.totalPartTypes || 0);
              const partQty = loc.partQuantity !== undefined ? loc.partQuantity : 0;
              const boardCount = loc.boardTypesCount !== undefined ? loc.boardTypesCount : 0;
              const boardQty = loc.boardQuantity !== undefined ? loc.boardQuantity : 0;
              const totalQty = loc.totalQuantity !== undefined ? loc.totalQuantity : (partQty + boardQty);
              const isOccupied = partCount > 0 || partQty > 0 || boardCount > 0 || boardQty > 0;

              return (
                <div
                  key={loc.id}
                  style={{
                    backgroundColor: '#ffffff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '12px',
                    padding: '18px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
                    transition: 'all 0.15s ease',
                  }}
                >
                  <div>
                    {/* Top Row: Code, Status & Actions */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px', flexWrap: 'wrap', gap: '8px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <span
                          style={{
                            backgroundColor: '#0f172a',
                            borderRadius: '6px',
                            padding: '3px 8px',
                            fontSize: '12px',
                            fontWeight: 800,
                            color: '#ffffff',
                            fontFamily: 'monospace',
                            letterSpacing: '0.5px',
                          }}
                        >
                          {loc.code}
                        </span>
                        <span
                          style={{
                            fontSize: '11px',
                            fontWeight: 600,
                            padding: '3px 8px',
                            borderRadius: '12px',
                            backgroundColor: isOccupied ? '#ecfdf5' : '#f1f5f9',
                            color: isOccupied ? '#059669' : '#64748b',
                          }}
                        >
                          {isOccupied ? 'Có hàng' : 'Trống'}
                        </span>
                      </div>

                      <div style={{ display: 'flex', gap: '5px' }}>
                        <button
                          type="button"
                          title="In tem QR vị trí"
                          onClick={() => onPrintLocationQr(loc)}
                          style={{
                            background: '#f0f9ff',
                            border: '1px solid #bae6fd',
                            borderRadius: '6px',
                            padding: '4px 8px',
                            color: '#0284c7',
                            cursor: 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '12px',
                            fontWeight: 600,
                          }}
                        >
                          <Printer size={13} />
                          <span>In QR</span>
                        </button>
                        <button
                          type="button"
                          title="Chỉnh sửa thông tin vị trí"
                          onClick={() => openEditForm(loc)}
                          style={{
                            background: '#f8fafc',
                            border: '1px solid #cbd5e1',
                            borderRadius: '6px',
                            padding: '4px 8px',
                            color: '#334155',
                            cursor: 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '12px',
                            fontWeight: 600,
                          }}
                        >
                          <Edit2 size={13} />
                          <span>Sửa</span>
                        </button>
                        <button
                          type="button"
                          title="Xóa vị trí này"
                          onClick={() => setDeletingLocation(loc)}
                          style={{
                            background: '#fee2e2',
                            border: '1px solid #fca5a5',
                            borderRadius: '6px',
                            padding: '4px 8px',
                            color: '#dc2626',
                            cursor: 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '12px',
                            fontWeight: 700,
                          }}
                        >
                          <Trash2 size={13} />
                          <span>Xóa</span>
                        </button>
                      </div>
                    </div>

                    {/* Title */}
                    <h4 style={{ margin: '0 0 6px 0', fontSize: '16px', fontWeight: 700, color: '#0f172a' }}>
                      {loc.name}
                    </h4>

                    {/* Description */}
                    {loc.description && (
                      <p
                        style={{
                          margin: '0 0 10px 0',
                          fontSize: '13px',
                          color: '#64748b',
                          lineHeight: '1.4',
                        }}
                      >
                        {loc.description}
                      </p>
                    )}

                    {/* QR String info */}
                    <div style={{ fontSize: '12px', color: '#94a3b8', fontFamily: 'monospace', marginBottom: '10px' }}>
                      Mã QR: {loc.qrCode || loc.code}
                    </div>
                  </div>

                  {/* Footer & Badges */}
                  <div
                    style={{
                      borderTop: '1px solid #f1f5f9',
                      paddingTop: '12px',
                      marginTop: '8px',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '8px',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
                      <span
                        style={{
                          fontSize: '11.5px',
                          fontWeight: 600,
                          color: partQty > 0 || partCount > 0 ? '#059669' : '#94a3b8',
                          backgroundColor: partQty > 0 || partCount > 0 ? '#ecfdf5' : '#f8fafc',
                          border: `1px solid ${partQty > 0 || partCount > 0 ? '#a7f3d0' : '#e2e8f0'}`,
                          padding: '3px 8px',
                          borderRadius: '6px',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                        }}
                      >
                        <span>📦 Linh kiện:</span>
                        <b>{partCount} loại ({partQty})</b>
                      </span>

                      <span
                        style={{
                          fontSize: '11.5px',
                          fontWeight: 600,
                          color: boardQty > 0 || boardCount > 0 ? '#2563eb' : '#94a3b8',
                          backgroundColor: boardQty > 0 || boardCount > 0 ? '#eff6ff' : '#f8fafc',
                          border: `1px solid ${boardQty > 0 || boardCount > 0 ? '#bfdbfe' : '#e2e8f0'}`,
                          padding: '3px 8px',
                          borderRadius: '6px',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                        }}
                      >
                        <span>⚡ Bo mạch:</span>
                        <b>{boardCount} loại ({boardQty})</b>
                      </span>
                    </div>

                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '2px' }}>
                      <span style={{ fontSize: '11.5px', color: '#64748b' }}>
                        Tổng tồn: <strong style={{ color: '#0f172a' }}>{totalQty}</strong>
                      </span>

                      {isOccupied && (
                        <button
                          type="button"
                          onClick={() => onViewLocationParts(loc.code)}
                          style={{
                            background: 'none',
                            border: 'none',
                            color: '#2563eb',
                            fontSize: '12px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: '3px',
                            padding: 0,
                          }}
                        >
                          <span>Xem chi tiết</span>
                          <ArrowRight size={13} />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Sub-modal: Add / Edit Form */}
      {isFormOpen && (
        <div className="w-modal-overlay" style={{ zIndex: 1100 }}>
          <div className="w-modal-card" style={{ maxWidth: '480px', width: '90vw' }}>
            <div className="modal-header">
              <h3>{editingLocation ? 'Chỉnh Sửa Vị Trí Kho' : 'Thêm Vị Trí Kho Mới'}</h3>
              <button className="close-modal-btn" onClick={() => setIsFormOpen(false)}>
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleSaveLocation} className="modal-form">
              <div className="form-group">
                <label>Mã vị trí (Code) *</label>
                <input
                  type="text"
                  required
                  placeholder="VD: LOC-A1, KE-01, NGAN-02..."
                  value={formCode}
                  onChange={(e) => setFormCode(e.target.value.toUpperCase())}
                  style={{ fontFamily: 'monospace', fontWeight: 600 }}
                />
              </div>

              <div className="form-group">
                <label>Tên vị trí / Kệ kho *</label>
                <input
                  type="text"
                  required
                  placeholder="VD: Kệ A - Tầng 1 (Công suất)"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Mô tả chi tiết</label>
                <textarea
                  rows={2}
                  placeholder="Ghi chú chi tiết khu vực, loại linh kiện chứa..."
                  value={formDesc}
                  onChange={(e) => setFormDesc(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Mã QR Code (Mặc định bằng mã vị trí)</label>
                <input
                  type="text"
                  placeholder="Để trống sẽ tự sinh theo mã vị trí"
                  value={formQr}
                  onChange={(e) => setFormQr(e.target.value)}
                />
              </div>

              <div className="modal-actions-footer">
                <button
                  type="button"
                  className="btn-cancel"
                  onClick={() => setIsFormOpen(false)}
                  disabled={isSaving}
                >
                  Hủy
                </button>
                <button type="submit" className="btn-submit" disabled={isSaving}>
                  {isSaving ? 'Đang lưu...' : editingLocation ? 'Cập nhật' : 'Tạo mới'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Sub-modal: Delete Confirm / Block */}
      {deletingLocation && (
        <div className="w-modal-overlay" style={{ zIndex: 1100 }}>
          <div className="w-modal-card" style={{ maxWidth: '460px', width: '90vw', textAlign: 'center' }}>
            {(deletingLocation.totalQuantity || 0) > 0 || (deletingLocation.totalPartTypes || 0) > 0 ? (
              // CASE 1: LOCATION STILL HAS ITEMS -> PREVENT DELETE WITH CLEAR NOTIFICATION
              <>
                <div style={{ color: '#d97706', marginBottom: '12px' }}>
                  <AlertCircle size={48} style={{ margin: '0 auto', color: '#dc2626' }} />
                </div>
                <h3 style={{ fontSize: '18px', fontWeight: 700, margin: '0 0 8px 0', color: '#b91c1c' }}>
                  Không Thể Xóa Vị Trí Này!
                </h3>
                <div
                  style={{
                    backgroundColor: '#fef2f2',
                    border: '1.5px solid #fecaca',
                    borderRadius: '8px',
                    padding: '12px 16px',
                    margin: '12px 0 16px 0',
                    textAlign: 'left',
                    fontSize: '13px',
                    color: '#991b1b',
                    lineHeight: '1.5',
                  }}
                >
                  <div>
                    Vị trí <strong style={{ color: '#0f172a' }}>{deletingLocation.name} ({deletingLocation.code})</strong> hiện đang còn:{' '}
                    <strong style={{ color: '#dc2626' }}>
                      {deletingLocation.totalPartTypes} loại linh kiện
                    </strong>{' '}
                    (Tổng tồn kho: <strong style={{ color: '#dc2626' }}>{deletingLocation.totalQuantity} cái</strong>).
                  </div>
                  <div style={{ marginTop: '6px', color: '#7f1d1d' }}>
                    ⚠️ Để đảm bảo an toàn số liệu kho, bạn không thể xóa vị trí khi vẫn còn hàng tồn. Vui lòng chuyển hoặc xuất hết linh kiện trước khi xóa.
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
                  <button
                    type="button"
                    className="btn-cancel"
                    onClick={() => setDeletingLocation(null)}
                    style={{ padding: '8px 18px', borderRadius: '6px' }}
                  >
                    Đóng
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      const code = deletingLocation.code;
                      setDeletingLocation(null);
                      onViewLocationParts(code);
                    }}
                    style={{
                      padding: '8px 18px',
                      borderRadius: '6px',
                      backgroundColor: '#2563eb',
                      color: '#ffffff',
                      border: 'none',
                      fontWeight: 600,
                      cursor: 'pointer',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                    }}
                  >
                    <span>Xem linh kiện tại đây</span>
                    <ArrowRight size={14} />
                  </button>
                </div>
              </>
            ) : (
              // CASE 2: LOCATION IS EMPTY (0 ITEMS) -> ALLOW DELETE
              <>
                <div style={{ color: '#dc2626', marginBottom: '12px' }}>
                  <AlertCircle size={44} style={{ margin: '0 auto' }} />
                </div>
                <h3 style={{ fontSize: '17px', fontWeight: 700, margin: '0 0 8px 0', color: '#0f172a' }}>
                  Xác nhận xóa vị trí kho?
                </h3>
                <p style={{ fontSize: '13px', color: '#64748b', marginBottom: '20px' }}>
                  Vị trí <strong style={{ color: '#0f172a' }}>{deletingLocation.name} ({deletingLocation.code})</strong> đang trống (0 linh kiện). Bạn có chắc chắn muốn xóa vị trí này khỏi hệ thống không?
                </p>

                <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
                  <button
                    type="button"
                    className="btn-cancel"
                    onClick={() => setDeletingLocation(null)}
                    disabled={isDeleting}
                    style={{ padding: '8px 20px', borderRadius: '6px' }}
                  >
                    Hủy bỏ
                  </button>
                  <button
                    type="button"
                    onClick={handleDeleteLocation}
                    disabled={isDeleting}
                    style={{
                      padding: '8px 20px',
                      borderRadius: '6px',
                      backgroundColor: '#dc2626',
                      color: '#ffffff',
                      border: 'none',
                      fontWeight: 600,
                      cursor: 'pointer',
                    }}
                  >
                    {isDeleting ? 'Đang xóa...' : 'Xác nhận xóa'}
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

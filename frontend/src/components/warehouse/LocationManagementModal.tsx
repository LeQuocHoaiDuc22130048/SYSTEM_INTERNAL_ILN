import React, { useState, useMemo } from 'react';
import {
  X,
  Plus,
  Edit2,
  Trash2,
  Printer,
  Search,
  MapPin,
  AlertCircle,
  PackageCheck,
} from 'lucide-react';
import { getAuthHeaders } from '../../utils/auth';

export interface LocationItem {
  id: string;
  code: string;
  name: string;
  description?: string;
  qrCode?: string;
  totalPartTypes?: number;
  totalQuantity?: number;
}

interface LocationManagementModalProps {
  isOpen: boolean;
  onClose: () => void;
  locations: LocationItem[];
  onRefreshLocations: () => Promise<void>;
  onPrintLocationQr: (location?: LocationItem) => void;
  onPrintAllLocationsQr: () => void;
  showToast: (msg: string) => void;
}

export const LocationManagementModal: React.FC<LocationManagementModalProps> = ({
  isOpen,
  onClose,
  locations,
  onRefreshLocations,
  onPrintLocationQr,
  onPrintAllLocationsQr,
  showToast,
}) => {
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [editingLocation, setEditingLocation] = useState<LocationItem | null>(null);
  const [isFormOpen, setIsFormOpen] = useState<boolean>(false);
  const [formCode, setFormCode] = useState<string>('');
  const [formName, setFormName] = useState<string>('');
  const [formDesc, setFormDesc] = useState<string>('');
  const [formQr, setFormQr] = useState<string>('');
  const [isSaving, setIsSaving] = useState<boolean>(false);

  const [deletingLocation, setDeletingLocation] = useState<LocationItem | null>(null);
  const [isDeleting, setIsDeleting] = useState<boolean>(false);

  const filteredLocations = useMemo(() => {
    const term = searchTerm.toLowerCase().trim();
    if (!term) return locations;
    return locations.filter(
      (l) =>
        l.name.toLowerCase().includes(term) ||
        l.code.toLowerCase().includes(term) ||
        (l.description && l.description.toLowerCase().includes(term))
    );
  }, [locations, searchTerm]);

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
          headers: getAuthHeaders(),
          body: JSON.stringify({
            code: formCode.trim(),
            name: formName.trim(),
            description: formDesc.trim() || undefined,
            qrCode: formQr.trim() || formCode.trim(),
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
          headers: getAuthHeaders(),
          body: JSON.stringify({
            code: formCode.trim(),
            name: formName.trim(),
            description: formDesc.trim() || undefined,
            qrCode: formQr.trim() || formCode.trim(),
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

  if (!isOpen) return null;

  return (
    <div className="w-modal-overlay">
      <div
        className="w-modal-card"
        style={{
          maxWidth: '850px',
          width: '95vw',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {/* Modal Header */}
        <div className="modal-header" style={{ padding: '16px 20px', borderBottom: '1px solid #e2e8f0' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: '8px',
                backgroundColor: '#eff6ff',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#2563eb',
              }}
            >
              <MapPin size={20} />
            </div>
            <div>
              <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 700, color: '#0f172a' }}>
                Quản Lý Vị Trí Lưu Kho / Kệ Hàng
              </h3>
              <p style={{ margin: 0, fontSize: '13px', color: '#64748b' }}>
                Quản lý danh sách kệ, ngăn kéo, gắn mã QR và định vị linh kiện
              </p>
            </div>
          </div>
          <button className="close-modal-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        {/* Action Toolbar */}
        <div
          style={{
            padding: '12px 20px',
            backgroundColor: '#f8fafc',
            borderBottom: '1px solid #e2e8f0',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            gap: '12px',
            flexWrap: 'wrap',
          }}
        >
          {/* Search Box */}
          <div style={{ position: 'relative', flex: '1', minWidth: '220px' }}>
            <Search
              size={16}
              style={{ position: 'absolute', left: '10px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
            />
            <input
              type="text"
              placeholder="Tìm theo tên hoặc mã kệ/vị trí..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              style={{
                width: '100%',
                padding: '8px 12px 8px 34px',
                borderRadius: '6px',
                border: '1px solid #cbd5e1',
                fontSize: '13px',
                outline: 'none',
              }}
            />
          </div>

          {/* Action Buttons */}
          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              type="button"
              onClick={onPrintAllLocationsQr}
              className="btn-filter"
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 14px',
                fontSize: '13px',
                fontWeight: 600,
                backgroundColor: '#ffffff',
                border: '1px solid #cbd5e1',
                borderRadius: '6px',
                cursor: 'pointer',
                color: '#334155',
              }}
            >
              <Printer size={15} color="#0284c7" />
              <span>In Tất Cả Tem QR</span>
            </button>

            <button
              type="button"
              onClick={openCreateForm}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '6px',
                padding: '8px 14px',
                fontSize: '13px',
                fontWeight: 600,
                backgroundColor: '#2563eb',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                color: '#ffffff',
              }}
            >
              <Plus size={16} />
              <span>Thêm Vị Trí Mới</span>
            </button>
          </div>
        </div>

        {/* Location List Table */}
        <div style={{ flex: 1, overflowY: 'auto', padding: '16px 20px' }}>
          {filteredLocations.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px 20px', color: '#64748b' }}>
              <PackageCheck size={40} style={{ margin: '0 auto 12px auto', color: '#cbd5e1' }} />
              <div style={{ fontSize: '15px', fontWeight: 600, color: '#334155' }}>
                {searchTerm ? 'Không tìm thấy vị trí nào khớp từ khóa' : 'Chưa có vị trí lưu kho nào'}
              </div>
              <p style={{ fontSize: '13px', marginTop: '4px' }}>
                {searchTerm
                  ? 'Thử thay đổi từ khóa tìm kiếm'
                  : 'Bấm "+ Thêm Vị Trí Mới" để tạo vị trí kệ hàng đầu tiên'}
              </p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {filteredLocations.map((loc) => {
                const partCount = loc.totalPartTypes || 0;
                const totalQty = loc.totalQuantity || 0;

                return (
                  <div
                    key={loc.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '12px 16px',
                      backgroundColor: '#ffffff',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px',
                      transition: 'all 0.15s ease',
                      gap: '12px',
                    }}
                  >
                    {/* Left: Info */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: 1, minWidth: 0 }}>
                      <div
                        style={{
                          minWidth: '70px',
                          textAlign: 'center',
                          padding: '4px 8px',
                          backgroundColor: '#f1f5f9',
                          borderRadius: '6px',
                          border: '1px solid #cbd5e1',
                          fontWeight: 800,
                          fontSize: '12px',
                          color: '#1e293b',
                          fontFamily: 'monospace',
                        }}
                      >
                        {loc.code}
                      </div>

                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <span style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a' }}>
                            {loc.name}
                          </span>
                          <span
                            style={{
                              fontSize: '11px',
                              padding: '2px 6px',
                              borderRadius: '4px',
                              backgroundColor: partCount > 0 ? '#ecfdf5' : '#f8fafc',
                              color: partCount > 0 ? '#059669' : '#94a3b8',
                              fontWeight: 600,
                            }}
                          >
                            {partCount > 0 ? `${partCount} loại linh kiện (Tồn: ${totalQty})` : 'Trống (0 linh kiện)'}
                          </span>
                        </div>

                        {loc.description && (
                          <div
                            style={{
                              fontSize: '12px',
                              color: '#64748b',
                              marginTop: '2px',
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                            }}
                          >
                            {loc.description}
                          </div>
                        )}
                      </div>
                    </div>

                    {/* Right: Actions */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <button
                        type="button"
                        title="In tem QR vị trí"
                        onClick={() => onPrintLocationQr(loc)}
                        style={{
                          padding: '6px 10px',
                          backgroundColor: '#f0f9ff',
                          border: '1px solid #bae6fd',
                          borderRadius: '6px',
                          color: '#0284c7',
                          cursor: 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '12px',
                          fontWeight: 600,
                        }}
                      >
                        <Printer size={14} />
                        <span>In QR</span>
                      </button>

                      <button
                        type="button"
                        title="Chỉnh sửa vị trí"
                        onClick={() => openEditForm(loc)}
                        style={{
                          padding: '6px 10px',
                          backgroundColor: '#f8fafc',
                          border: '1px solid #cbd5e1',
                          borderRadius: '6px',
                          color: '#334155',
                          cursor: 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '12px',
                          fontWeight: 600,
                        }}
                      >
                        <Edit2 size={14} />
                        <span>Sửa</span>
                      </button>

                      <button
                        type="button"
                        title="Xóa vị trí này"
                        onClick={() => setDeletingLocation(loc)}
                        style={{
                          padding: '6px 12px',
                          backgroundColor: '#fee2e2',
                          border: '1.5px solid #fca5a5',
                          borderRadius: '6px',
                          color: '#dc2626',
                          cursor: 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '12px',
                          fontWeight: 700,
                        }}
                      >
                        <Trash2 size={14} />
                        <span>Xóa</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Modal Footer */}
        <div
          style={{
            padding: '12px 20px',
            backgroundColor: '#f8fafc',
            borderTop: '1px solid #e2e8f0',
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <span style={{ fontSize: '13px', color: '#64748b' }}>
            Tổng cộng: <strong>{locations.length}</strong> vị trí kho
          </span>
          <button
            type="button"
            className="btn-cancel"
            onClick={onClose}
            style={{
              padding: '8px 18px',
              backgroundColor: '#e2e8f0',
              border: 'none',
              borderRadius: '6px',
              fontWeight: 600,
              fontSize: '13px',
              cursor: 'pointer',
              color: '#334155',
            }}
          >
            Đóng
          </button>
        </div>
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
                    style={{ padding: '8px 20px', borderRadius: '6px' }}
                  >
                    Đã hiểu
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

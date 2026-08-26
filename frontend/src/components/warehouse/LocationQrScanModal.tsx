import React, { useState, useEffect } from 'react';
import {
  X,
  QrCode,
  MapPin,
  ArrowUpRight,
  Search,
  Printer,
  Edit2,
  Trash2,
  AlertCircle,
} from 'lucide-react';

import { getAuthHeaders } from '../../utils/auth';
import type { LocationScanData, LocationPartItem } from '../../types/warehouse';

interface LocationQrScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialCode?: string;
  availableLocations?: Array<{ id: string; code: string; name: string }>;
  onSelectPartForCheckout?: (partItem: LocationPartItem, locationData: LocationScanData) => void;
  onPrintLocationQr?: (locationData: LocationScanData) => void;
  onRefreshLocations?: () => Promise<void>;
  showToast: (msg: string) => void;
}

export const LocationQrScanModal: React.FC<LocationQrScanModalProps> = ({
  isOpen,
  onClose,
  initialCode = '',
  availableLocations = [],
  onSelectPartForCheckout,
  onPrintLocationQr,
  onRefreshLocations,
  showToast,
}) => {
  const [codeOrQr, setCodeOrQr] = useState<string>(initialCode);
  const [loading, setLoading] = useState<boolean>(false);
  const [scanResult, setScanResult] = useState<LocationScanData | null>(null);

  // Edit states
  const [isEditOpen, setIsEditOpen] = useState<boolean>(false);
  const [editCode, setEditCode] = useState<string>('');
  const [editName, setEditName] = useState<string>('');
  const [editDesc, setEditDesc] = useState<string>('');
  const [editQr, setEditQr] = useState<string>('');
  const [isSaving, setIsSaving] = useState<boolean>(false);

  // Delete states
  const [isDeleteConfirmOpen, setIsDeleteConfirmOpen] = useState<boolean>(false);
  const [isDeleting, setIsDeleting] = useState<boolean>(false);

  useEffect(() => {
    if (isOpen) {
      if (initialCode) {
        setCodeOrQr(initialCode);
        fetchLocationData(initialCode);
      } else {
        setCodeOrQr('');
        setScanResult(null);
      }
    }
  }, [isOpen, initialCode]);

  const fetchLocationData = async (targetCode: string) => {
    if (!targetCode.trim()) {
      showToast('Vui lòng nhập hoặc quét mã QR vị trí');
      return;
    }

    setLoading(true);
    setScanResult(null);
    try {
      const res = await fetch(`/api/v1/parts/locations/scan/${encodeURIComponent(targetCode.trim())}`, {
        headers: getAuthHeaders(),
      });
      const json = await res.json();

      if (res.ok && json.success && json.data) {
        setScanResult(json.data);
        showToast(`Đã tìm thấy vị trí: ${json.data.name} (${json.data.code})`);
      } else {
        showToast(json.message || 'Không tìm thấy vị trí kho với mã này');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi khi tra cứu vị trí kho');
    } finally {
      setLoading(false);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    fetchLocationData(codeOrQr);
  };

  const openEditModal = () => {
    if (!scanResult) return;
    setEditCode(scanResult.code);
    setEditName(scanResult.name);
    setEditDesc(scanResult.description || '');
    setEditQr(scanResult.qrCode || scanResult.code);
    setIsEditOpen(true);
  };

  const handleSaveEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!scanResult || !editCode.trim() || !editName.trim()) {
      showToast('Vui lòng nhập đầy đủ Mã vị trí và Tên vị trí');
      return;
    }

    setIsSaving(true);
    try {
      const res = await fetch(`/api/v1/parts/locations/${scanResult.locationId}`, {
        method: 'PATCH',
        headers: getAuthHeaders(),
        body: JSON.stringify({
          code: editCode.trim(),
          name: editName.trim(),
          description: editDesc.trim() || undefined,
          qrCode: editQr.trim() || editCode.trim(),
        }),
      });
      const json = await res.json();
      if (res.ok && json.success) {
        showToast('Cập nhật vị trí kho thành công');
        setIsEditOpen(false);
        if (onRefreshLocations) await onRefreshLocations();
        fetchLocationData(editCode.trim());
      } else {
        showToast(json.message || 'Lỗi khi cập nhật vị trí kho');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi cập nhật vị trí kho');
    } finally {
      setIsSaving(false);
    }
  };

  const handleDeleteLocation = async () => {
    if (!scanResult) return;
    setIsDeleting(true);
    try {
      const res = await fetch(`/api/v1/parts/locations/${scanResult.locationId}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      const json = await res.json();
      if (res.ok && json.success) {
        showToast(`Đã xóa vị trí ${scanResult.name}`);
        setIsDeleteConfirmOpen(false);
        setScanResult(null);
        if (onRefreshLocations) await onRefreshLocations();
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
      <div className="w-modal-card" style={{ maxWidth: '750px', width: '90vw', maxHeight: '90vh', overflowY: 'auto' }}>
        {/* Header */}
        <div className="modal-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <QrCode size={20} className="text-primary" />
            <h3 style={{ margin: 0 }}>Tra Cứu & Quản Lý Vị Trí Kho Bằng QR</h3>
          </div>
          <button className="close-modal-btn" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        {/* Search Bar */}
        <div style={{ padding: '16px 20px' }}>
          <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
            <div style={{ position: 'relative', flex: 1 }}>
              <Search
                size={18}
                style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }}
              />
              <input
                type="text"
                placeholder="Nhập mã kệ, mã ngăn hoặc quét mã QR..."
                value={codeOrQr}
                onChange={(e) => setCodeOrQr(e.target.value)}
                style={{
                  width: '100%',
                  paddingLeft: '38px',
                  paddingRight: '12px',
                  paddingTop: '10px',
                  paddingBottom: '10px',
                  borderRadius: '8px',
                  border: '1px solid #cbd5e1',
                  outline: 'none',
                  fontSize: '0.95rem',
                }}
                autoFocus
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              style={{
                backgroundColor: '#2563eb',
                color: '#fff',
                border: 'none',
                padding: '0 20px',
                borderRadius: '8px',
                fontWeight: 600,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
              }}
            >
              <QrCode size={16} />
              {loading ? 'Đang tra cứu...' : 'Tra cứu'}
            </button>
          </form>

          {/* Quick Select Pill Suggestions */}
          {availableLocations.length > 0 && !scanResult && (
            <div style={{ marginBottom: '16px' }}>
              <div style={{ fontSize: '0.78rem', color: '#64748b', marginBottom: '6px' }}>Vị trí kho có sẵn:</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                {availableLocations.map((loc) => (
                  <button
                    key={loc.id || loc.code}
                    type="button"
                    onClick={() => {
                      setCodeOrQr(loc.code);
                      fetchLocationData(loc.code);
                    }}
                    style={{
                      background: '#f1f5f9',
                      border: '1px solid #cbd5e1',
                      borderRadius: '16px',
                      padding: '3px 10px',
                      fontSize: '0.78rem',
                      cursor: 'pointer',
                      color: '#334155',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                    }}
                  >
                    <MapPin size={12} className="text-primary" />
                    <strong>{loc.code}</strong> - {loc.name}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Results Display */}
          {scanResult ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {/* Location Card Header */}
              <div
                style={{
                  backgroundColor: '#eff6ff',
                  border: '1px solid #bfdbfe',
                  padding: '14px 16px',
                  borderRadius: '10px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  flexWrap: 'wrap',
                  gap: '10px',
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 700, fontSize: '1.1rem', color: '#1e40af' }}>
                    <MapPin size={22} />
                    <span>{scanResult.name} ({scanResult.code})</span>
                  </div>
                  {scanResult.description && (
                    <div style={{ fontSize: '0.84rem', color: '#3b82f6', marginTop: '3px' }}>{scanResult.description}</div>
                  )}
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                  <span style={{ backgroundColor: '#2563eb', color: '#fff', padding: '4px 12px', borderRadius: '12px', fontSize: '0.82rem', fontWeight: 600 }}>
                    {scanResult.totalPartTypes} loại linh kiện · Tổng SL: {scanResult.totalQuantity}
                  </span>

                  {onPrintLocationQr && (
                    <button
                      type="button"
                      onClick={() => onPrintLocationQr(scanResult)}
                      style={{
                        backgroundColor: '#fff',
                        color: '#2563eb',
                        border: '1px solid #2563eb',
                        padding: '5px 10px',
                        borderRadius: '8px',
                        fontSize: '0.8rem',
                        fontWeight: 600,
                        cursor: 'pointer',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px',
                      }}
                      title="In tem QR dán lên kệ/vị trí này"
                    >
                      <Printer size={14} />
                      In QR
                    </button>
                  )}

                  <button
                    type="button"
                    onClick={openEditModal}
                    style={{
                      backgroundColor: '#fff',
                      color: '#475569',
                      border: '1px solid #cbd5e1',
                      padding: '5px 10px',
                      borderRadius: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                    }}
                    title="Chỉnh sửa thông tin vị trí"
                  >
                    <Edit2 size={14} />
                    Sửa
                  </button>

                  <button
                    type="button"
                    onClick={() => setIsDeleteConfirmOpen(true)}
                    style={{
                      backgroundColor: '#fef2f2',
                      color: '#dc2626',
                      border: '1px solid #fecaca',
                      padding: '5px 10px',
                      borderRadius: '8px',
                      fontSize: '0.8rem',
                      fontWeight: 600,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                    }}
                    title="Xóa vị trí kho"
                  >
                    <Trash2 size={14} />
                    Xóa
                  </button>
                </div>
              </div>

              {/* Boards List */}
              {scanResult.boards && scanResult.boards.length > 0 && (
                <div>
                  <div style={{ fontWeight: 600, fontSize: '0.9rem', color: '#334155', marginBottom: '8px' }}>
                    Danh sách bo mạch trong vị trí này ({scanResult.boards.length})
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '14px' }}>
                    {scanResult.boards.map((b) => (
                      <div
                        key={b.boardId || b.qrCode}
                        style={{
                          backgroundColor: '#fff',
                          border: '1px solid #e2e8f0',
                          padding: '12px 16px',
                          borderRadius: '8px',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          gap: '12px',
                          boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                        }}
                      >
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{b.name}</div>
                          <div style={{ fontSize: '0.8rem', color: '#64748b', display: 'flex', gap: '10px', marginTop: '2px' }}>
                            <span>Mã: <strong>{b.qrCode}</strong></span>
                            {b.model && <span>Model: <strong>{b.model}</strong></span>}
                            {b.repairBrand && <span>Hãng: <strong>{b.repairBrand}</strong></span>}
                          </div>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <span style={{ fontSize: '0.88rem', fontWeight: 600, color: b.quantity > 0 ? '#16a34a' : '#dc2626' }}>
                            {b.quantity > 0 ? `SL: ${b.quantity}` : 'Đã mượn hết'}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Parts List */}
              <div>
                <div style={{ fontWeight: 600, fontSize: '0.9rem', color: '#334155', marginBottom: '8px' }}>
                  Danh sách linh kiện trong vị trí này ({scanResult.parts.length})
                </div>

                {scanResult.parts.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '30px', color: '#64748b', backgroundColor: '#f8fafc', borderRadius: '8px' }}>
                    Chưa có linh kiện nào được lưu tại vị trí này.
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                    {scanResult.parts.map((p) => (
                      <div
                        key={p.partLotId}
                        style={{
                          backgroundColor: '#fff',
                          border: '1px solid #e2e8f0',
                          padding: '12px 16px',
                          borderRadius: '8px',
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          gap: '12px',
                          boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                        }}
                      >
                        <div style={{ flex: 1 }}>
                          <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{p.name}</div>
                          <div style={{ fontSize: '0.8rem', color: '#64748b', display: 'flex', gap: '10px', marginTop: '2px' }}>
                            <span>IPN: <strong>{p.ipn}</strong></span>
                            {p.categoryName && <span>Loại: <strong>{p.categoryName}</strong></span>}
                          </div>
                        </div>

                        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <div style={{ textAlign: 'right' }}>
                            <div style={{ fontSize: '0.95rem', fontWeight: 700, color: p.amount > 0 ? '#16a34a' : '#dc2626' }}>
                              {p.amount} {p.unit || 'cái'}
                            </div>
                            <div style={{ fontSize: '0.75rem', color: '#64748b' }}>Tồn tại vị trí</div>
                          </div>

                          {onSelectPartForCheckout && (
                            <button
                              type="button"
                              onClick={() => onSelectPartForCheckout(p, scanResult)}
                              disabled={p.amount <= 0}
                              style={{
                                backgroundColor: p.amount > 0 ? '#2563eb' : '#cbd5e1',
                                color: '#fff',
                                border: 'none',
                                padding: '6px 12px',
                                borderRadius: '6px',
                                fontSize: '0.82rem',
                                fontWeight: 600,
                                cursor: p.amount > 0 ? 'pointer' : 'not-allowed',
                                display: 'flex',
                                alignItems: 'center',
                                gap: '4px',
                              }}
                            >
                              <ArrowUpRight size={14} />
                              Lấy
                            </button>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ) : (
            !loading && (
              <div style={{ textAlign: 'center', padding: '40px 20px', color: '#94a3b8' }}>
                <MapPin size={40} style={{ margin: '0 auto 8px auto', opacity: 0.5 }} />
                <div>Nhập mã hoặc quét QR để xem toàn bộ danh sách bo mạch & linh kiện trong vị trí.</div>
              </div>
            )
          )}
        </div>

        {/* Edit Sub-modal */}
        {isEditOpen && (
          <div className="w-modal-overlay" style={{ zIndex: 1200 }}>
            <div className="w-modal-card" style={{ maxWidth: '480px', width: '90vw' }}>
              <div className="modal-header">
                <h3>Chỉnh Sửa Vị Trí Kho</h3>
                <button className="close-modal-btn" onClick={() => setIsEditOpen(false)}>
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleSaveEdit} className="modal-form">
                <div className="form-group">
                  <label>Mã vị trí (Code) *</label>
                  <input
                    type="text"
                    required
                    value={editCode}
                    onChange={(e) => setEditCode(e.target.value.toUpperCase())}
                    style={{ fontFamily: 'monospace', fontWeight: 600 }}
                  />
                </div>

                <div className="form-group">
                  <label>Tên vị trí / Kệ kho *</label>
                  <input
                    type="text"
                    required
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Mô tả chi tiết</label>
                  <textarea
                    rows={2}
                    value={editDesc}
                    onChange={(e) => setEditDesc(e.target.value)}
                  />
                </div>

                <div className="form-group">
                  <label>Mã QR Code</label>
                  <input
                    type="text"
                    value={editQr}
                    onChange={(e) => setEditQr(e.target.value)}
                  />
                </div>

                <div className="modal-actions-footer">
                  <button
                    type="button"
                    className="btn-cancel"
                    onClick={() => setIsEditOpen(false)}
                    disabled={isSaving}
                  >
                    Hủy
                  </button>
                  <button type="submit" className="btn-submit" disabled={isSaving}>
                    {isSaving ? 'Đang lưu...' : 'Lưu thay đổi'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Delete Confirm / Block Sub-modal */}
        {isDeleteConfirmOpen && scanResult && (
          <div className="w-modal-overlay" style={{ zIndex: 1200 }}>
            <div className="w-modal-card" style={{ maxWidth: '460px', width: '90vw', textAlign: 'center' }}>
              {(scanResult.totalQuantity || 0) > 0 || (scanResult.parts && scanResult.parts.length > 0) || (scanResult.boards && scanResult.boards.length > 0) ? (
                // CASE 1: LOCATION STILL HAS PARTS OR BOARDS -> PREVENT DELETE
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
                      Vị trí <strong style={{ color: '#0f172a' }}>{scanResult.name} ({scanResult.code})</strong> hiện đang còn:{' '}
                      <strong style={{ color: '#dc2626' }}>
                        {(scanResult.parts ? scanResult.parts.length : 0)} loại linh kiện
                      </strong>{' '}
                      {scanResult.boards && scanResult.boards.length > 0 ? (
                        <>và <strong style={{ color: '#dc2626' }}>{scanResult.boards.length} bo mạch</strong> </>
                      ) : null}
                      (Tổng tồn kho: <strong style={{ color: '#dc2626' }}>{scanResult.totalQuantity || 0} cái</strong>).
                    </div>
                    <div style={{ marginTop: '6px', color: '#7f1d1d' }}>
                      ⚠️ Để đảm bảo an toàn số liệu kho, bạn không thể xóa vị trí khi vẫn còn hàng tồn. Vui lòng chuyển hoặc xuất hết linh kiện/bo mạch trước khi xóa.
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
                    <button
                      type="button"
                      className="btn-cancel"
                      onClick={() => setIsDeleteConfirmOpen(false)}
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
                    Vị trí <strong style={{ color: '#0f172a' }}>{scanResult.name} ({scanResult.code})</strong> đang trống (0 linh kiện). Bạn có chắc chắn muốn xóa vị trí này khỏi hệ thống không?
                  </p>

                  <div style={{ display: 'flex', gap: '10px', justifyContent: 'center' }}>
                    <button
                      type="button"
                      className="btn-cancel"
                      onClick={() => setIsDeleteConfirmOpen(false)}
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
    </div>
  );
};

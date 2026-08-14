import React, { useState } from 'react';
import { X, QrCode, MapPin, ArrowUpRight, Search } from 'lucide-react';

import { getAuthHeaders } from '../../utils/auth';
import type { LocationScanData, LocationPartItem } from '../../types/warehouse';

interface LocationQrScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectPartForCheckout?: (partItem: LocationPartItem, locationData: LocationScanData) => void;
  showToast: (msg: string) => void;
}

export const LocationQrScanModal: React.FC<LocationQrScanModalProps> = ({
  isOpen,
  onClose,
  onSelectPartForCheckout,
  showToast,
}) => {
  const [codeOrQr, setCodeOrQr] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [scanResult, setScanResult] = useState<LocationScanData | null>(null);

  if (!isOpen) return null;

  const handleScan = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!codeOrQr.trim()) {
      showToast('Vui lòng nhập hoặc quét mã QR vị trí');
      return;
    }

    setLoading(true);
    setScanResult(null);
    try {
      const res = await fetch(`/api/v1/parts/locations/scan/${encodeURIComponent(codeOrQr.trim())}`, {
        headers: getAuthHeaders(),
      });
      const json = await res.json();

      if (res.ok && json.success && json.data) {
        setScanResult(json.data);
        showToast(`Đã tìm thấy vị trí ${json.data.name} (${json.data.code})`);
      } else {
        showToast(json.message || 'Không tìm thấy vị trí kho với mã này');
      }
    } catch (err) {
      console.error(err);
      showToast('Lỗi kết nối khi quét mã QR vị trí');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop">
      <div className="modal-container" style={{ maxWidth: '650px' }}>
        <div className="modal-header">
          <div className="modal-title-group">
            <QrCode className="text-primary" size={22} />
            <h3>Quét Mã QR / Tra Cứu Vị Trí Kho</h3>
          </div>
          <button className="modal-close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="modal-form">
          {/* Scan Input */}
          <form onSubmit={handleScan} style={{ display: 'flex', gap: '10px', marginBottom: '16px' }}>
            <div style={{ position: 'relative', flex: 1 }}>
              <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                placeholder="Nhập hoặc quét mã QR vị trí (VD: LOC-A1, KE-01)..."
                value={codeOrQr}
                onChange={(e) => setCodeOrQr(e.target.value)}
                style={{ width: '100%', paddingLeft: '38px', paddingRight: '12px', paddingTop: '10px', paddingBottom: '10px', borderRadius: '8px', border: '1px solid #cbd5e1', outline: 'none', fontSize: '0.95rem' }}
                autoFocus
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              style={{ backgroundColor: '#2563eb', color: '#fff', border: 'none', padding: '0 20px', borderRadius: '8px', fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px' }}
            >
              <QrCode size={16} />
              {loading ? 'Đang truy vấn...' : 'Tra cứu'}
            </button>
          </form>

          {/* Results Display */}
          {scanResult ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              {/* Location Card Header */}
              <div style={{ backgroundColor: '#eff6ff', border: '1px solid #bfdbfe', padding: '12px 16px', borderRadius: '10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 700, fontSize: '1.05rem', color: '#1e40af' }}>
                    <MapPin size={20} />
                    <span>{scanResult.name} ({scanResult.code})</span>
                  </div>
                  {scanResult.description && (
                    <div style={{ fontSize: '0.82rem', color: '#3b82f6', marginTop: '2px' }}>{scanResult.description}</div>
                  )}
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span style={{ backgroundColor: '#2563eb', color: '#fff', padding: '4px 12px', borderRadius: '12px', fontSize: '0.8rem', fontWeight: 600 }}>
                    {scanResult.totalPartTypes} loại linh kiện · Tổng: {scanResult.totalQuantity}
                  </span>
                </div>
              </div>

              {/* Part Items at this location */}
              <div style={{ maxHeight: '350px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {scanResult.parts.length === 0 ? (
                  <div style={{ padding: '30px', textAlign: 'center', color: '#64748b' }}>Vị trí kho này hiện chưa xếp linh kiện nào.</div>
                ) : (
                  scanResult.parts.map((item) => (
                    <div
                      key={item.partLotId || item.partId}
                      style={{
                        backgroundColor: '#fff',
                        border: '1px solid #e2e8f0',
                        padding: '12px 16px',
                        borderRadius: '8px',
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{item.name}</div>
                        <div style={{ fontSize: '0.8rem', color: '#64748b', display: 'flex', gap: '12px', marginTop: '2px' }}>
                          <span style={{ fontFamily: 'monospace' }}>IPN: {item.ipn}</span>
                          <span>Danh mục: {item.categoryName || 'Chưa rõ'}</span>
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                        <div style={{ textAlign: 'right' }}>
                          <span style={{ fontSize: '0.78rem', color: '#64748b' }}>Tồn tại vị trí</span>
                          <div style={{ fontWeight: 700, fontSize: '1rem', color: '#16a34a' }}>{item.amount}</div>
                        </div>

                        {onSelectPartForCheckout && (
                          <button
                            onClick={() => {
                              onSelectPartForCheckout(item, scanResult);
                              onClose();
                            }}
                            style={{
                              backgroundColor: '#d97706',
                              color: '#fff',
                              border: 'none',
                              padding: '8px 14px',
                              borderRadius: '6px',
                              fontSize: '0.82rem',
                              fontWeight: 600,
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                            }}
                          >
                            <ArrowUpRight size={14} />
                            Lấy linh kiện
                          </button>
                        )}
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          ) : (
            <div style={{ padding: '40px 20px', textAlign: 'center', color: '#64748b', backgroundColor: '#f8fafc', borderRadius: '10px', border: '1px dashed #cbd5e1' }}>
              <QrCode size={40} style={{ margin: '0 auto 10px', color: '#94a3b8' }} />
              <div style={{ fontWeight: 600 }}>Quét hoặc Nhập Mã QR Vị Trí Kho</div>
              <div style={{ fontSize: '0.82rem', color: '#94a3b8', marginTop: '4px' }}>
                Hệ thống sẽ ngay lập tức trả về thông tin vị trí và toàn bộ danh sách các linh kiện được sắp xếp tại đây.
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

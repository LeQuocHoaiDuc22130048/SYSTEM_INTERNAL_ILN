import React, { useState, useEffect } from 'react';
import { X, QrCode, MapPin, ArrowUpRight, Search, Printer } from 'lucide-react';

import { getAuthHeaders } from '../../utils/auth';
import type { LocationScanData, LocationPartItem } from '../../types/warehouse';

interface LocationQrScanModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialCode?: string;
  availableLocations?: Array<{ id: string; code: string; name: string }>;
  onSelectPartForCheckout?: (partItem: LocationPartItem, locationData: LocationScanData) => void;
  onPrintLocationQr?: (locationData: LocationScanData) => void;
  showToast: (msg: string) => void;
}

export const LocationQrScanModal: React.FC<LocationQrScanModalProps> = ({
  isOpen,
  onClose,
  initialCode = '',
  availableLocations = [],
  onSelectPartForCheckout,
  onPrintLocationQr,
  showToast,
}) => {
  const [codeOrQr, setCodeOrQr] = useState<string>(initialCode);
  const [loading, setLoading] = useState<boolean>(false);
  const [scanResult, setScanResult] = useState<LocationScanData | null>(null);

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
      showToast('Lỗi kết nối khi quét mã QR vị trí');
    } finally {
      setLoading(false);
    }
  };

  const handleScan = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    fetchLocationData(codeOrQr);
  };

  if (!isOpen) return null;

  return (
    <div className="modal-backdrop">
      <div className="modal-container" style={{ maxWidth: '680px', width: '95%' }}>
        <div className="modal-header">
          <div className="modal-title-group" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <QrCode className="text-primary" size={22} />
            <h3 style={{ margin: 0, fontSize: '1.15rem', fontWeight: 700 }}>Quét Mã QR Vị Trí Kho / Kệ Kho</h3>
          </div>
          <button className="modal-close-btn" onClick={onClose}>
            <X size={18} />
          </button>
        </div>

        <div className="modal-form" style={{ padding: '16px' }}>
          {/* Scan / Query Input */}
          <form onSubmit={handleScan} style={{ display: 'flex', gap: '10px', marginBottom: '12px' }}>
            <div style={{ position: 'relative', flex: 1 }}>
              <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                placeholder="Nhập hoặc quét mã QR vị trí (VD: LOC-A1, KE-01)..."
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

                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
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
                      In Tem QR Kệ
                    </button>
                  )}
                </div>
              </div>

              {/* Header label for Parts */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: 600, fontSize: '0.9rem', color: '#334155' }}>
                  Danh sách linh kiện trong vị trí này ({scanResult.parts.length})
                </span>
                <span style={{ fontSize: '0.78rem', color: '#64748b' }}>
                  Quét QR vị trí để tra cứu & lấy linh kiện nhanh
                </span>
              </div>

              {/* Part Items at this location */}
              <div style={{ maxHeight: '350px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {scanResult.parts.length === 0 ? (
                  <div style={{ padding: '30px', textAlign: 'center', color: '#64748b', backgroundColor: '#f8fafc', borderRadius: '8px' }}>
                    Vị trí kho này hiện chưa có linh kiện nào được lưu trữ.
                  </div>
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
                        gap: '12px',
                        boxShadow: '0 1px 2px rgba(0,0,0,0.03)',
                      }}
                    >
                      <div style={{ flex: 1 }}>
                        <div style={{ fontWeight: 600, fontSize: '0.95rem', color: '#0f172a' }}>{item.name}</div>
                        <div style={{ fontSize: '0.8rem', color: '#64748b', display: 'flex', gap: '12px', marginTop: '2px', flexWrap: 'wrap' }}>
                          <span style={{ fontFamily: 'monospace', fontWeight: 600, color: '#1e293b' }}>IPN: {item.ipn}</span>
                          <span>Danh mục: {item.categoryName || 'Chưa rõ'}</span>
                          {item.condition && <span>Tình trạng: {item.condition}</span>}
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ textAlign: 'right', minWidth: '70px' }}>
                          <span style={{ fontSize: '0.75rem', color: '#64748b', display: 'block' }}>Tồn tại kệ</span>
                          <div style={{ fontWeight: 700, fontSize: '1.05rem', color: '#16a34a' }}>{item.amount}</div>
                        </div>

                        {onSelectPartForCheckout && (
                          <button
                            type="button"
                            onClick={() => {
                              onSelectPartForCheckout(item, scanResult);
                              onClose();
                            }}
                            style={{
                              backgroundColor: '#d97706',
                              color: '#fff',
                              border: 'none',
                              padding: '8px 12px',
                              borderRadius: '6px',
                              fontSize: '0.82rem',
                              fontWeight: 600,
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              whiteSpace: 'nowrap',
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
              <QrCode size={44} style={{ margin: '0 auto 12px', color: '#94a3b8' }} />
              <div style={{ fontWeight: 600, fontSize: '1rem', color: '#1e293b' }}>Quét hoặc Nhập Mã QR Vị Trí Kho / Kệ Kho</div>
              <div style={{ fontSize: '0.85rem', color: '#64748b', marginTop: '6px', maxWidth: '420px', margin: '6px auto 0' }}>
                Mỗi vị trí/kệ kho có 1 mã QR. Quét mã QR tại kệ để hiển thị tức thì danh sách toàn bộ linh kiện được lưu trữ tại kệ đó.
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

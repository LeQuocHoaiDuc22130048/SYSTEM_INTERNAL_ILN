import React, { useEffect, useState, useCallback } from 'react';
import { Search, RefreshCw, ArrowUpRight, ArrowDownLeft, CheckCircle2, AlertTriangle, Clock, User, MapPin } from 'lucide-react';
import { getAuthHeaders } from '../../utils/auth';
import type { PartCheckoutHistoryItem } from '../../types/warehouse';



interface PartCheckoutHistoryPanelProps {
  showToast: (msg: string) => void;
  onReturnClick?: (item: PartCheckoutHistoryItem) => void;
}

export const PartCheckoutHistoryPanel: React.FC<PartCheckoutHistoryPanelProps> = ({
  showToast,
  onReturnClick,
}) => {
  const [historyItems, setHistoryItems] = useState<PartCheckoutHistoryItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');

  const fetchHistory = useCallback(async () => {
    setLoading(true);
    try {
      let url = '/api/v1/parts/checkouts/history?size=100';
      if (statusFilter !== 'ALL') {
        url += `&status=${statusFilter}`;
      }
      const res = await fetch(url, { headers: getAuthHeaders() });
      if (res.ok) {
        const json = await res.json();
        const content = json?.data?.content || (Array.isArray(json?.data) ? json.data : []);
        setHistoryItems(content);
      } else {
        showToast('Không thể tải nhật ký lấy/trả linh kiện');
      }
    } catch (err) {
      console.error('Fetch part history error:', err);
      showToast('Lỗi kết nối khi tải nhật ký');
    } finally {
      setLoading(false);
    }
  }, [statusFilter, showToast]);

  useEffect(() => {
    fetchHistory();
  }, [fetchHistory]);

  const filteredItems = historyItems.filter((item) => {
    if (!searchTerm.trim()) return true;
    const term = searchTerm.toLowerCase();
    return (
      (item.partIpn && item.partIpn.toLowerCase().includes(term)) ||
      (item.partName && item.partName.toLowerCase().includes(term)) ||
      (item.takenByName && item.takenByName.toLowerCase().includes(term)) ||
      (item.locationCode && item.locationCode.toLowerCase().includes(term)) ||
      (item.purpose && item.purpose.toLowerCase().includes(term))
    );
  });

  const formatDate = (isoStr?: string) => {
    if (!isoStr) return '-';
    try {
      const d = new Date(isoStr);
      return d.toLocaleString('vi-VN', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    } catch {
      return isoStr;
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'OPEN':
        return (
          <span style={{ backgroundColor: '#fef3c7', color: '#d97706', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
            <Clock size={12} /> Đang mượn
          </span>
        );
      case 'RETURNED':
        return (
          <span style={{ backgroundColor: '#dcfce7', color: '#16a34a', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
            <CheckCircle2 size={12} /> Đã trả đủ
          </span>
        );
      case 'DAMAGED':
        return (
          <span style={{ backgroundColor: '#fee2e2', color: '#dc2626', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
            <AlertTriangle size={12} /> Trả linh kiện hỏng
          </span>
        );
      default:
        return (
          <span style={{ backgroundColor: '#f3f4f6', color: '#4b5563', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600 }}>
            {status}
          </span>
        );
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', height: '100%' }}>
      {/* Top Filter Bar */}
      <div style={{ display: 'flex', gap: '12px', alignItems: 'center', flexWrap: 'wrap', backgroundColor: 'var(--color-bg-surface, #fff)', padding: '12px 16px', borderRadius: '12px', border: '1px solid var(--color-border, #e2e8f0)' }}>
        <div style={{ position: 'relative', flex: 1, minWidth: '220px' }}>
          <Search size={18} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
          <input
            type="text"
            placeholder="Tìm theo linh kiện, IPN, vị trí, người lấy, mục đích..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{ width: '100%', paddingLeft: '38px', paddingRight: '12px', paddingTop: '8px', paddingBottom: '8px', borderRadius: '8px', border: '1px solid #cbd5e1', outline: 'none', fontSize: '0.9rem' }}
          />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '8px 12px', borderRadius: '8px', border: '1px solid #cbd5e1', fontSize: '0.85rem', backgroundColor: '#fff' }}
        >
          <option value="ALL">Tất cả trạng thái</option>
          <option value="OPEN">Đang mượn (Chưa trả)</option>
          <option value="RETURNED">Đã trả đủ</option>
          <option value="DAMAGED">Trả linh kiện hỏng</option>
        </select>

        <button
          onClick={fetchHistory}
          style={{ display: 'flex', alignItems: 'center', gap: '6px', padding: '8px 14px', borderRadius: '8px', backgroundColor: '#f1f5f9', border: '1px solid #cbd5e1', cursor: 'pointer', fontSize: '0.85rem', fontWeight: 500 }}
        >
          <RefreshCw size={14} className={loading ? 'spin-anim' : ''} />
          <span>Làm mới</span>
        </button>
      </div>

      {/* History Table */}
      <div style={{ flex: 1, overflowY: 'auto', backgroundColor: 'var(--color-bg-surface, #fff)', borderRadius: '12px', border: '1px solid var(--color-border, #e2e8f0)' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>Đang tải nhật ký lấy/trả...</div>
        ) : filteredItems.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#64748b' }}>Không có nhật ký hoạt động nào phù hợp.</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.88rem', textAlign: 'left' }}>
            <thead>
              <tr style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid #e2e8f0', color: '#475569', fontWeight: 600 }}>
                <th style={{ padding: '12px 16px' }}>Linh kiện</th>
                <th style={{ padding: '12px 16px' }}>Vị trí kho</th>
                <th style={{ padding: '12px 16px' }}>Người thực hiện</th>
                <th style={{ padding: '12px 16px' }}>Số lượng</th>
                <th style={{ padding: '12px 16px' }}>Mục đích / Ghi chú</th>
                <th style={{ padding: '12px 16px' }}>Thời gian Lấy / Trả</th>
                <th style={{ padding: '12px 16px' }}>Trạng thái</th>
                <th style={{ padding: '12px 16px', textAlign: 'right' }}>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {filteredItems.map((item) => (
                <tr key={item.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ fontWeight: 600, color: '#0f172a' }}>{item.partName || 'Linh kiện'}</div>
                    <div style={{ fontSize: '0.78rem', color: '#64748b', fontFamily: 'monospace' }}>
                      IPN: {item.partIpn || 'N/A'}
                    </div>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px', backgroundColor: '#eff6ff', color: '#2563eb', padding: '3px 8px', borderRadius: '6px', fontWeight: 600, fontSize: '0.8rem' }}>
                      <MapPin size={12} /> {item.locationCode || 'Mặc định'}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 500 }}>
                      <User size={14} style={{ color: '#64748b' }} />
                      <span>{item.takenByName || 'Không xác định'}</span>
                    </div>
                    {item.takenByEmployeeCode && (
                      <div style={{ fontSize: '0.75rem', color: '#94a3b8', marginLeft: '20px' }}>
                        {item.takenByEmployeeCode}
                      </div>
                    )}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ fontWeight: 700, color: '#2563eb' }}>
                      Lấy: {item.quantity}
                    </div>
                    {item.returnedQuantity > 0 && (
                      <div style={{ fontSize: '0.78rem', color: '#16a34a' }}>
                        Đã trả: {item.returnedQuantity}
                      </div>
                    )}
                  </td>
                  <td style={{ padding: '12px 16px', maxWidth: '200px' }}>
                    <div style={{ fontWeight: 500 }}>{item.purpose || 'N/A'}</div>
                    {item.notes && (
                      <div style={{ fontSize: '0.78rem', color: '#64748b', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {item.notes}
                      </div>
                    )}
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: '0.8rem', color: '#475569' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                      <ArrowUpRight size={12} style={{ color: '#d97706' }} />
                      <span>Lấy: {formatDate(item.takenAt)}</span>
                    </div>
                    {item.returnedAt && (
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '3px' }}>
                        <ArrowDownLeft size={12} style={{ color: '#16a34a' }} />
                        <span>Trả: {formatDate(item.returnedAt)}</span>
                      </div>
                    )}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    {getStatusBadge(item.checkoutStatus)}
                  </td>
                  <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                    {item.checkoutStatus === 'OPEN' && onReturnClick && (
                      <button
                        onClick={() => onReturnClick(item)}
                        style={{
                          backgroundColor: '#2563eb',
                          color: '#fff',
                          border: 'none',
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '0.78rem',
                          fontWeight: 600,
                          cursor: 'pointer',
                        }}
                      >
                        Trả linh kiện
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
};

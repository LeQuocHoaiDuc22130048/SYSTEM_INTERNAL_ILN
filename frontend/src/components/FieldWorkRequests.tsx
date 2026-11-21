import { useCallback, useEffect, useState } from 'react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { FieldWorkModal } from './FieldWorkModal';
import { AlertTriangle, Briefcase, RefreshCw, CheckCircle2, ChevronDown, ChevronUp } from 'lucide-react';
import './FieldWorkRequests.css';

type Request = { id: string; employeeId: string; employeeName?: string; workDate: string; note: string; status: string; version: number };
const labels: Record<string, string> = { PENDING: 'Chờ duyệt', APPROVED: 'Đã chấp nhận', REJECTED: 'Đã từ chối' };

export function FieldWorkRequests({ admin, refresh, onChanged }: { admin: boolean; refresh: number; onChanged: () => void }) {
  const [requests, setRequests] = useState<Request[]>([]);
  const [month, setMonth] = useState(() => {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
  });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [expanded, setExpanded] = useState(true);
  const [editing, setEditing] = useState<Request | null>(null);

  const load = useCallback(async () => {
    try {
      const res = await fetch(
        admin
          ? '/api/attendance/field-work/pending'
          : `/api/attendance/me/field-work?from=${month}-01&to=${month}-${new Date(Number(month.slice(0, 4)), Number(month.slice(5)), 0).getDate()}`,
        { headers: getAuthHeaders() }
      );
      if (!res.ok) throw new Error('Không tải được yêu cầu đi công trình');
      const body = await res.json();
      setRequests(Array.isArray(body.data) ? body.data : []);
      setError('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Có lỗi xảy ra');
    } finally {
      setLoaded(true);
    }
  }, [admin, month]);

  useEffect(() => {
    void load();
  }, [load, refresh]);

  const review = async (request: Request, approve: boolean) => {
    if (!window.confirm(approve ? 'Chấp nhận yêu cầu đi công trình này?' : 'Từ chối yêu cầu đi công trình này?')) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/attendance/field-work/${request.id}/review`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ approve, version: request.version }),
      });
      if (!res.ok) {
        const body = await res.json();
        throw new Error(body.message || 'Không thể xét duyệt');
      }
      await load();
      onChanged();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Có lỗi xảy ra');
    } finally {
      setBusy(false);
    }
  };

  // Khi admin không có yêu cầu chờ duyệt và không lỗi, ẩn hoàn toàn để nhường không gian cho KPI & biểu đồ
  if (admin && (!loaded || (requests.length === 0 && !error))) {
    return null;
  }

  // Nhân viên không có yêu cầu trong tháng: thu gọn thành 1 thanh tối giản để vẫn đổi tháng được khi cần
  if (!admin && loaded && requests.length === 0 && !error) {
    return (
      <section className="field-work-compact-bar" aria-label="Yêu cầu đi công trình">
        <div className="field-work-compact-status">
          <CheckCircle2 size={15} className="fw-empty-icon" aria-hidden="true" />
          <span className="fw-compact-title">Đi công trình:</span>
          <span className="fw-compact-muted">Chưa có yêu cầu trong tháng</span>
        </div>
        <div className="field-work-requests-tools">
          <label>
            <span>Tháng</span>
            <input
              aria-label="Tháng yêu cầu"
              type="month"
              value={month}
              onChange={(e) => {
                if (e.target.value) setMonth(e.target.value);
              }}
            />
          </label>
          <button
            className="btn-refresh-dashboard fw-btn-sm"
            type="button"
            disabled={busy}
            onClick={() => void load()}
          >
            <RefreshCw size={13} aria-hidden="true" />
            <span>Làm mới</span>
          </button>
        </div>
      </section>
    );
  }

  const hasUrgentPending = admin && requests.length > 0;

  return (
    <section
      className={`field-work-banner ${hasUrgentPending ? 'is-urgent' : ''} ${error ? 'is-error' : ''}`}
      role={hasUrgentPending || error ? 'region' : undefined}
      aria-label={admin ? 'Duyệt đi công trình' : 'Yêu cầu đi công trình'}
    >
      <div className="field-work-banner-bar">
        <div className="field-work-banner-lead">
          <span className={`fw-banner-icon ${error ? 'error' : hasUrgentPending ? 'urgent' : 'info'}`} aria-hidden="true">
            {error || hasUrgentPending ? <AlertTriangle size={16} /> : <Briefcase size={16} />}
          </span>
          <div className="fw-banner-summary">
            <strong className="fw-banner-title">
              {admin ? 'Cần duyệt đi công trình' : 'Yêu cầu đi công trình'}
            </strong>
            {requests.length > 0 && (
              <span className={`fw-count-badge ${hasUrgentPending ? 'urgent' : ''}`}>
                {requests.length} {admin ? 'chờ duyệt' : 'yêu cầu'}
              </span>
            )}
            {error && <span className="fw-error-inline" role="alert">{error}</span>}
          </div>
        </div>

        <div className="field-work-requests-tools">
          {!admin && (
            <label>
              <span>Tháng</span>
              <input
                aria-label="Tháng yêu cầu"
                type="month"
                value={month}
                onChange={(e) => {
                  if (e.target.value) setMonth(e.target.value);
                }}
              />
            </label>
          )}
          <button
            className="btn-refresh-dashboard fw-btn-sm fw-icon-action-btn"
            type="button"
            disabled={busy}
            onClick={() => void load()}
            title="Làm mới"
            aria-label="Làm mới"
          >
            <RefreshCw size={14} aria-hidden="true" />
            <span className="fw-action-label">Làm mới</span>
          </button>
          {requests.length > 0 && (
            <button
              type="button"
              className="fw-toggle-btn fw-icon-action-btn"
              onClick={() => setExpanded((v) => !v)}
              aria-expanded={expanded}
              title={expanded ? 'Thu gọn' : 'Chi tiết'}
              aria-label={expanded ? 'Thu gọn' : 'Chi tiết'}
            >
              <span className="fw-action-label">{expanded ? 'Thu gọn' : 'Chi tiết'}</span>
              {expanded ? <ChevronUp size={15} aria-hidden="true" /> : <ChevronDown size={15} aria-hidden="true" />}
            </button>
          )}
        </div>
      </div>

      {expanded && requests.length > 0 && (
        <div className="field-work-banner-list">
          {requests.map((r) => (
            <article key={r.id} className="field-work-request">
              <div className="field-work-request-main">
                <div className="field-work-request-heading">
                  <strong>{r.workDate}{admin ? ` — ${r.employeeName || r.employeeId}` : ''}</strong>
                  <span className={`field-work-request-status ${r.status.toLowerCase()}`}>
                    {labels[r.status] || r.status}
                  </span>
                </div>
                {r.note && <p className="field-work-request-note">{r.note}</p>}
              </div>
              <div className="field-work-request-actions">
                {admin ? (
                  <>
                    <button
                      type="button"
                      className="field-work-request-button approve"
                      disabled={busy}
                      onClick={() => void review(r, true)}
                    >
                      Chấp nhận
                    </button>
                    <button
                      type="button"
                      className="field-work-request-button reject"
                      disabled={busy}
                      onClick={() => void review(r, false)}
                    >
                      Từ chối
                    </button>
                  </>
                ) : (
                  <button
                    type="button"
                    className="field-work-request-button"
                    onClick={() => setEditing(r)}
                  >
                    Sửa / Hủy yêu cầu
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      )}

      {editing && (
        <FieldWorkModal
          initialDate={editing.workDate}
          initialNote={editing.note}
          isExisting
          onClose={() => setEditing(null)}
          showToast={setError}
          onSuccess={() => {
            void load();
            onChanged();
          }}
        />
      )}
    </section>
  );
}

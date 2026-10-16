import { useCallback, useEffect, useState } from 'react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { FieldWorkModal } from './FieldWorkModal';
import { Briefcase, RefreshCw, CheckCircle2 } from 'lucide-react';
import './FieldWorkRequests.css';

type Request = { id: string; employeeId: string; employeeName?: string; workDate: string; note: string; status: string; version: number };
const labels: Record<string, string> = { PENDING: 'Chờ duyệt', APPROVED: 'Đã chấp nhận', REJECTED: 'Đã từ chối' };
export function FieldWorkRequests({ admin, refresh, onChanged }: { admin: boolean; refresh: number; onChanged: () => void }) {
  const [requests, setRequests] = useState<Request[]>([]);
  const [month, setMonth] = useState(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`; });
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState<Request | null>(null);
  const load = useCallback(async () => {
    try {
      const res = await fetch(admin ? '/api/attendance/field-work/pending' : `/api/attendance/me/field-work?from=${month}-01&to=${month}-${new Date(Number(month.slice(0, 4)), Number(month.slice(5)), 0).getDate()}`, { headers: getAuthHeaders() });
      if (!res.ok) throw new Error('Không tải được yêu cầu đi công trình');
      const body = await res.json();
      setRequests(body.data); setError('');
    } catch (e) { setError(e instanceof Error ? e.message : 'Có lỗi xảy ra'); }
  }, [admin, month]);
  useEffect(() => { void load(); }, [load, refresh]);
  const review = async (request: Request, approve: boolean) => {
    if (!window.confirm(approve ? 'Chấp nhận yêu cầu đi công trình này?' : 'Từ chối yêu cầu đi công trình này?')) return;
    setBusy(true);
    try {
      const res = await fetch(`/api/attendance/field-work/${request.id}/review`, { method: 'PUT', headers: getJsonAuthHeaders(), body: JSON.stringify({ approve, version: request.version }) });
      if (!res.ok) { const body = await res.json(); throw new Error(body.message || 'Không thể xét duyệt'); }
      await load(); onChanged();
    } catch (e) { setError(e instanceof Error ? e.message : 'Có lỗi xảy ra'); }
    finally { setBusy(false); }
  };
  return <section className="dashboard-panel field-work-requests">
    <div className="field-work-requests-header">
      <h3 className="panel-title"><Briefcase size={18} aria-hidden="true" />{admin ? 'Duyệt đi công trình' : 'Yêu cầu đi công trình'}</h3>
      <div className="field-work-requests-tools">
        {!admin && <label>Tháng <input aria-label="Tháng yêu cầu" type="month" value={month} onChange={e => { if (e.target.value) setMonth(e.target.value); }} /></label>}
        <button className="btn-refresh-dashboard" type="button" disabled={busy} onClick={() => void load()}><RefreshCw size={14} aria-hidden="true" />Làm mới</button>
      </div>
    </div>
    {error && <p className="field-work-requests-error" role="alert">{error}</p>}
    {!requests.length && !error && <div className="field-work-requests-empty"><CheckCircle2 size={18} aria-hidden="true" /><span>Không có yêu cầu{admin ? ' chờ duyệt' : ''}.</span></div>}
    {requests.map(r => <article key={r.id} className="field-work-request">
      <div className="field-work-request-heading">
        <strong>{r.workDate}{admin ? ` — ${r.employeeName || r.employeeId}` : ''}</strong>
        <span className={`field-work-request-status ${r.status.toLowerCase()}`}>{labels[r.status] || r.status}</span>
      </div>
      <p className="field-work-request-note">{r.note}</p>
      <div className="field-work-request-actions">
        {admin ? <><button type="button" className="field-work-request-button approve" disabled={busy} onClick={() => void review(r, true)}>Chấp nhận</button><button type="button" className="field-work-request-button reject" disabled={busy} onClick={() => void review(r, false)}>Từ chối</button></>
          : <button type="button" className="field-work-request-button" onClick={() => setEditing(r)}>Sửa / Hủy yêu cầu</button>}
      </div>
    </article>)}
    {editing && <FieldWorkModal initialDate={editing.workDate} initialNote={editing.note} isExisting onClose={() => setEditing(null)} showToast={setError} onSuccess={() => { void load(); onChanged(); }} />}
  </section>;
}

import { useCallback, useEffect, useState } from 'react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import { FieldWorkModal } from './FieldWorkModal';

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
  return <section className="dashboard-card" style={{ padding: 16, marginBottom: 16 }}>
    <h3>{admin ? 'Duyệt đi công trình' : 'Yêu cầu đi công trình'}</h3>
    {!admin && <label>Tháng <input aria-label="Tháng yêu cầu" type="month" value={month} onChange={e => { if (e.target.value) setMonth(e.target.value); }} /></label>}
    <button type="button" disabled={busy} onClick={() => void load()}>Làm mới</button>
    {error && <p role="alert">{error}</p>}
    {!requests.length && <p>Không có yêu cầu{admin ? ' chờ duyệt' : ''}.</p>}
    {requests.map(r => <article key={r.id} style={{ borderTop: '1px solid #94a3b8', padding: '12px 0' }}>
      <strong>{r.workDate}{admin ? ` — ${r.employeeName || r.employeeId}` : ''}</strong>
      <p style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere' }}>{r.note}</p>
      <p>{labels[r.status] || r.status}</p>
      {admin ? <><button disabled={busy} onClick={() => void review(r, true)}>Chấp nhận</button>{' '}<button disabled={busy} onClick={() => void review(r, false)}>Từ chối</button></>
        : <button onClick={() => setEditing(r)}>Sửa / Hủy yêu cầu</button>}
    </article>)}
    {editing && <FieldWorkModal initialDate={editing.workDate} initialNote={editing.note} isExisting onClose={() => setEditing(null)} showToast={setError} onSuccess={() => { void load(); onChanged(); }} />}
  </section>;
}

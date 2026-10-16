import { useCallback, useEffect, useState } from 'react';
import { canManageTablets, listTablets, listTabletReviews, tabletAction, reviewAction, tabletEvents, tabletStatus, reviewDetail, type AttendanceTablet, type TabletReview, type TabletEvent } from '../utils/attendanceDevices';
import './AttendanceTabletPanel.css';
interface Props {
    role?: string;
    canStatus?: boolean;
    canReview?: boolean;
    showToast: (message: string) => void;
}
const date = (value: string | null) => value ? new Date(value).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }) : 'Chưa có';
export function AttendanceTabletPanel({ role, canStatus = false, canReview = false, showToast }: Props) {
    const [devices, setDevices] = useState<AttendanceTablet[]>([]), [reviews, setReviews] = useState<TabletReview[]>([]);
    const [loading, setLoading] = useState(true), [error, setError] = useState(''), [busy, setBusy] = useState(false);
    const [page, setPage] = useState(0), [last, setLast] = useState(true), [events, setEvents] = useState<TabletEvent[] | null>(null);
    const [action, setAction] = useState<{
        id: string;
        type: 'device' | 'review';
        action: 'approve' | 'block' | 'unblock' | 'reject';
        label: string;
    } | null>(null);
    const [detail, setDetail] = useState<TabletReview | null>(null);
    const [reason, setReason] = useState('');
    const allowed = canManageTablets(role);
    const load = useCallback(async () => { if (!allowed)
        return; setLoading(true); setError(''); try {
        const [d, r] = await Promise.all([listTablets(), listTabletReviews(page)]);
        setDevices(d);
        setReviews(r.content);
        setLast(r.last);
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Không tải được dữ liệu');
    }
    finally {
        setLoading(false);
    } }, [allowed, page]);
    useEffect(() => { void load(); }, [load]);
    if (!allowed)
        return null;
    const select = (id: string, type: 'device' | 'review', command: 'approve' | 'block' | 'unblock' | 'reject', label: string) => { setReason(''); setAction({ id, type, action: command, label }); };
    const submit = async () => { if (!action || !reason.trim() || busy)
        return; setBusy(true); try {
        if (action.type === 'device') {
            await tabletAction(action.id, action.action as 'approve' | 'block' | 'unblock', reason);
        }
        else {
            await reviewAction(action.id, action.action as 'approve' | 'reject', reason);
        }
        setAction(null);
        showToast('Đã lưu thay đổi');
        await load();
    }
    catch (e) {
        showToast(e instanceof Error ? e.message : 'Không lưu được thay đổi');
    }
    finally {
        setBusy(false);
    } };
    const showReview = async (id: string) => { setBusy(true); try {
        setDetail(await reviewDetail(id));
    }
    catch (e) {
        showToast(e instanceof Error ? e.message : 'Không tải được hồ sơ');
    }
    finally {
        setBusy(false);
    } };
    const history = async (id: string) => { setBusy(true); try {
        setEvents(await tabletEvents(id));
    }
    catch (e) {
        showToast(e instanceof Error ? e.message : 'Không tải được lịch sử');
    }
    finally {
        setBusy(false);
    } };
    return <section className="tablet-panel" aria-label="Quản lý tablet chấm công">
  <header><div><h2>Tablet chấm công</h2><p>Quản lý quyền thiết bị và các lượt chờ duyệt. Thời hạn offline: 24 giờ.</p></div><button disabled={loading || busy} onClick={() => void load()}>Làm mới</button></header>
  {error && <p role="alert">{error}</p>}{loading && <p>Đang tải dữ liệu…</p>}
  {!loading && devices.length === 0 && <p>Chưa có tablet đăng ký. Đăng nhập tài khoản chấm công trên tablet và chọn kết nối.</p>}
  <div className="tablet-scroll"><table><thead><tr><th>Tablet / mã đối chiếu</th><th>Quyền và kết nối</th><th>Lần liên lạc / đồng bộ</th><th>Chờ gửi</th><th>Thao tác</th></tr></thead><tbody>{devices.map(d => <tr key={d.id}>
   <td><strong>{d.name}</strong><br /><small>{d.id}</small><br /><small>{d.model} · Android {d.osVersion} · App {d.appVersion}</small></td>
   <td>{tabletStatus(d)}</td><td>{date(d.lastSeenAt)}<br />{date(d.lastSyncAt)}</td><td>{d.pendingCount}<br /><small>Theo lần báo lúc {date(d.lastSeenAt)}</small></td>
   <td><div className="tablet-actions">{canStatus && d.status === 'PENDING' && <button disabled={busy} onClick={() => select(d.id, 'device', 'approve', 'Duyệt tablet')}>Duyệt</button>}{canStatus && (d.status === 'BLOCKED' ? <button disabled={busy} onClick={() => select(d.id, 'device', 'unblock', 'Mở khóa tablet')}>Mở khóa</button> : <button disabled={busy} onClick={() => select(d.id, 'device', 'block', 'Khóa tablet')}>Khóa</button>)}<button disabled={busy} onClick={() => void history(d.id)}>Lịch sử</button></div></td>
  </tr>)}</tbody></table></div>
  <h3>Lượt chấm công chờ duyệt</h3><p>Lượt chờ duyệt chưa được tính công. Dữ liệu cũ thiếu quyền xác nhận cần xử lý bằng luồng chỉnh công.</p>
  {!loading && reviews.length === 0 && <p>Không có lượt đang chờ duyệt.</p>}
  <div className="tablet-scroll"><table><thead><tr><th>Hồ sơ / tablet</th><th>Thời điểm tiếp nhận</th><th>Trạng thái / lý do</th><th>Xử lý</th></tr></thead><tbody>{reviews.map(r => <tr key={r.id}><td><small>{r.id}<br />{r.deviceId}<br />Lượt: {r.localLogId}<br />Nhân viên: {r.employeeId}<br />{r.attendanceType} · {date(r.capturedAt ?? null)}</small></td><td>{date(r.createdAt)}</td><td>{r.status === 'LEGACY_REVIEW' ? 'Dữ liệu cũ — cần chỉnh công' : 'Chờ duyệt'}<br />{r.error}</td><td><div className="tablet-actions"><button disabled={busy} onClick={() => void showReview(r.id)}>Chi tiết</button>{canReview && r.status !== 'LEGACY_REVIEW' && <button disabled={busy} onClick={() => select(r.id, 'review', 'approve', 'Duyệt lượt chấm công')}>Duyệt</button>}{canReview && <button disabled={busy} onClick={() => select(r.id, 'review', 'reject', 'Từ chối lượt chấm công')}>Từ chối</button>}</div></td></tr>)}</tbody></table></div>
  <div className="tablet-actions"><button disabled={page === 0 || loading || busy} onClick={() => setPage(p => p - 1)}>Trang trước</button><span>Trang {page + 1}</span><button disabled={last || loading || busy} onClick={() => setPage(p => p + 1)}>Trang sau</button></div>
  {action && <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label={action.label}><form onSubmit={e => { e.preventDefault(); void submit(); }}><h3>{action.label}</h3><p>{action.type === 'device' && action.action !== 'block' ? 'Duyệt máy này sẽ khóa tablet khác đang được duyệt cho cùng tài khoản.' : 'Thay đổi được ghi vào lịch sử quản trị.'}</p><label>Lý do<textarea autoFocus required maxLength={500} value={reason} onChange={e => setReason(e.target.value)}/></label><div className="tablet-actions"><button disabled={busy || !reason.trim()} type="submit">{busy ? 'Đang lưu…' : 'Xác nhận'}</button><button disabled={busy} type="button" onClick={() => setAction(null)}>Hủy</button></div></form></div>}
  {detail && <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label="Chi tiết lượt chấm công"><div><h3>Chi tiết lượt chấm công</h3><p>Nhân viên: {detail.employeeId}<br />Thời điểm: {date(detail.capturedAt ?? null)}<br />Loại: {detail.attendanceType}<br />Tablet: {detail.deviceId}</p><p>{detail.error}</p>{detail.faceImageBase64 && detail.imageContentType && /^image\/(jpeg|png)$/.test(detail.imageContentType) && <img alt="Ảnh xác minh lượt chấm công" style={{ maxWidth: '100%', maxHeight: 360 }} src={`data:${detail.imageContentType};base64,${detail.faceImageBase64}`}/>}<button onClick={() => setDetail(null)}>Đóng</button></div></div>}
  {events && <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label="Lịch sử tablet"><div><h3>Lịch sử tablet</h3>{events.length === 0 ? <p>Chưa có sự kiện.</p> : <ul>{events.map(e => <li key={e.id}>{date(e.occurredAt)} · {e.action}<br />{e.reason}<br /><small>Người thao tác: {e.actorId}</small></li>)}</ul>}<button onClick={() => setEvents(null)}>Đóng</button></div></div>}
 </section>;
}

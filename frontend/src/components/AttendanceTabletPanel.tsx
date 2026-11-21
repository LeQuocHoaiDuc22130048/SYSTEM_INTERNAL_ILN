import { useCallback, useEffect, useRef, useState } from 'react';
import {
  CheckCircle2,
  ChevronDown,
  ChevronUp,
  Clock,
  RefreshCw,
  Tablet,
} from 'lucide-react';
import {
  canManageTablets,
  listTablets,
  listTabletReviews,
  tabletAction,
  reviewAction,
  tabletEvents,
  tabletStatus,
  reviewDetail,
  type AttendanceTablet,
  type TabletReview,
  type TabletEvent,
} from '../utils/attendanceDevices';
import './AttendanceTabletPanel.css';

interface Props {
  role?: string;
  canStatus?: boolean;
  canReview?: boolean;
  showToast: (message: string) => void;
}

type ActiveSubTab = 'devices' | 'reviews';

const date = (value: string | null) =>
  value ? new Date(value).toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }) : 'Chưa có';

export function AttendanceTabletPanel({ role, canStatus = false, canReview = false, showToast }: Props) {
  const [devices, setDevices] = useState<AttendanceTablet[]>([]);
  const [reviews, setReviews] = useState<TabletReview[]>([]);
  const [totalReviews, setTotalReviews] = useState<number>(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [page, setPage] = useState(0);
  const [last, setLast] = useState(true);
  const [events, setEvents] = useState<TabletEvent[] | null>(null);
  const [activeSubTab, setActiveSubTab] = useState<ActiveSubTab>('devices');
  const [expanded, setExpanded] = useState(false);
  const userToggledRef = useRef(false);

  const [action, setAction] = useState<{
    id: string;
    type: 'device' | 'review';
    action: 'approve' | 'block' | 'unblock' | 'reject';
    label: string;
  } | null>(null);
  const [detail, setDetail] = useState<TabletReview | null>(null);
  const [reason, setReason] = useState('');

  const allowed = canManageTablets(role);

  const load = useCallback(async () => {
    if (!allowed) return;
    setLoading(true);
    setError('');
    try {
      const [d, r] = await Promise.all([listTablets(), listTabletReviews(page)]);
      const reviewCount = typeof r.totalElements === 'number' ? r.totalElements : r.content.length;
      setDevices(d);
      setReviews(r.content);
      setTotalReviews(reviewCount);
      setLast(r.last);

      if (!userToggledRef.current) {
        const hasAnyData = d.length > 0 || reviewCount > 0;
        setExpanded(hasAnyData);
        if (d.length === 0 && reviewCount > 0) {
          setActiveSubTab('reviews');
        }
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Không tải được dữ liệu');
    } finally {
      setLoading(false);
    }
  }, [allowed, page]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!allowed) return null;

  const select = (
    id: string,
    type: 'device' | 'review',
    command: 'approve' | 'block' | 'unblock' | 'reject',
    label: string
  ) => {
    setReason('');
    setAction({ id, type, action: command, label });
  };

  const submit = async () => {
    if (!action || !reason.trim() || busy) return;
    setBusy(true);
    try {
      if (action.type === 'device') {
        await tabletAction(action.id, action.action as 'approve' | 'block' | 'unblock', reason);
      } else {
        await reviewAction(action.id, action.action as 'approve' | 'reject', reason);
      }
      setAction(null);
      showToast('Đã lưu thay đổi');
      await load();
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Không lưu được thay đổi');
    } finally {
      setBusy(false);
    }
  };

  const showReview = async (id: string) => {
    setBusy(true);
    try {
      setDetail(await reviewDetail(id));
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Không tải được hồ sơ');
    } finally {
      setBusy(false);
    }
  };

  const history = async (id: string) => {
    setBusy(true);
    try {
      setEvents(await tabletEvents(id));
    } catch (e) {
      showToast(e instanceof Error ? e.message : 'Không tải được lịch sử');
    } finally {
      setBusy(false);
    }
  };

  const handleToggleExpand = () => {
    userToggledRef.current = true;
    setExpanded((prev) => !prev);
  };

  const handleSwitchTab = (tab: ActiveSubTab) => {
    setActiveSubTab(tab);
    if (!expanded && (devices.length > 0 || totalReviews > 0)) {
      userToggledRef.current = true;
      setExpanded(true);
    }
  };

  const isEmptyAll = !loading && !error && devices.length === 0 && totalReviews === 0;
  const pendingDevicesCount = devices.filter((d) => d.status === 'PENDING').length;

  return (
    <section
      className={`tablet-panel ${isEmptyAll && !expanded ? 'is-compact' : ''} ${totalReviews > 0 || pendingDevicesCount > 0 ? 'has-attention' : ''}`}
      aria-label="Quản lý Chấm công và Phê duyệt"
    >
      <div className="tablet-panel-bar">
        <div className="tablet-panel-lead">
          <span className="tablet-panel-icon" aria-hidden="true">
            {isEmptyAll ? <CheckCircle2 size={16} /> : <Tablet size={16} />}
          </span>
          <div className="tablet-panel-title-group">
            <div className="tablet-panel-heading-row">
              <h2>Quản lý Chấm công &amp; Phê duyệt</h2>
              <div className="tablet-tabs" role="tablist" aria-label="Phân mục tablet chấm công">
                <button
                  type="button"
                  role="tab"
                  aria-selected={activeSubTab === 'devices'}
                  className={`tablet-tab-btn ${activeSubTab === 'devices' ? 'active' : ''}`}
                  onClick={() => handleSwitchTab('devices')}
                >
                  Tablet đăng ký ({devices.length})
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={activeSubTab === 'reviews'}
                  className={`tablet-tab-btn ${activeSubTab === 'reviews' ? 'active' : ''} ${totalReviews > 0 ? 'has-badge' : ''}`}
                  onClick={() => handleSwitchTab('reviews')}
                >
                  Lượt chờ duyệt ({totalReviews})
                </button>
              </div>
            </div>
            {isEmptyAll && !expanded && (
              <p className="tablet-compact-hint">
                {activeSubTab === 'devices'
                  ? 'Chưa có tablet đăng ký. Đăng nhập tài khoản chấm công trên tablet và chọn kết nối (offline tối đa 24 giờ).'
                  : 'Không có lượt chấm công nào đang chờ duyệt.'}
              </p>
            )}
          </div>
        </div>

        <div className="tablet-panel-controls">
          <button
            type="button"
            className="tablet-ctrl-btn"
            disabled={loading || busy}
            onClick={() => void load()}
          >
            <RefreshCw size={14} className={loading ? 'spin' : ''} aria-hidden="true" />
            <span>{loading ? 'Đang tải…' : 'Làm mới'}</span>
          </button>
          <button
            type="button"
            className="tablet-ctrl-btn"
            aria-expanded={expanded}
            onClick={handleToggleExpand}
          >
            <span>{expanded ? 'Thu gọn' : 'Chi tiết'}</span>
            {expanded ? <ChevronUp size={14} aria-hidden="true" /> : <ChevronDown size={14} aria-hidden="true" />}
          </button>
        </div>
      </div>

      {error && (
        <p className="tablet-inline-error" role="alert">
          {error}
        </p>
      )}

      {expanded && (
        <div className="tablet-panel-body" role="tabpanel">
          {loading && devices.length === 0 && reviews.length === 0 ? (
            <div className="tablet-empty-banner">
              <Clock size={15} aria-hidden="true" />
              <span>Đang tải dữ liệu tablet chấm công và lượt chờ duyệt…</span>
            </div>
          ) : activeSubTab === 'devices' ? (
            devices.length === 0 ? (
              <div className="tablet-empty-banner">
                <span>
                  Chưa có tablet đăng ký. Đăng nhập tài khoản chấm công trên tablet và chọn kết nối. Thời hạn offline: 24 giờ.
                </span>
                <button type="button" disabled={loading || busy} onClick={() => void load()}>
                  Kiểm tra lại
                </button>
              </div>
            ) : (
              <div className="tablet-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Tablet / mã đối chiếu</th>
                      <th>Quyền và kết nối</th>
                      <th>Lần liên lạc / đồng bộ</th>
                      <th>Chờ gửi</th>
                      <th>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {devices.map((d) => (
                      <tr key={d.id}>
                        <td>
                          <strong>{d.name}</strong>
                          <br />
                          <small>{d.id}</small>
                          <br />
                          <small>
                            {d.model} · Android {d.osVersion} · App {d.appVersion}
                          </small>
                        </td>
                        <td>{tabletStatus(d)}</td>
                        <td>
                          {date(d.lastSeenAt)}
                          <br />
                          {date(d.lastSyncAt)}
                        </td>
                        <td>
                          {d.pendingCount}
                          <br />
                          <small>Theo lần báo lúc {date(d.lastSeenAt)}</small>
                        </td>
                        <td>
                          <div className="tablet-actions">
                            {canStatus && d.status === 'PENDING' && (
                              <button type="button" disabled={busy} onClick={() => select(d.id, 'device', 'approve', 'Duyệt tablet')}>
                                Duyệt
                              </button>
                            )}
                            {canStatus &&
                              (d.status === 'BLOCKED' ? (
                                <button type="button" disabled={busy} onClick={() => select(d.id, 'device', 'unblock', 'Mở khóa tablet')}>
                                  Mở khóa
                                </button>
                              ) : (
                                <button type="button" disabled={busy} onClick={() => select(d.id, 'device', 'block', 'Khóa tablet')}>
                                  Khóa
                                </button>
                              ))}
                            <button type="button" disabled={busy} onClick={() => void history(d.id)}>
                              Lịch sử
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )
          ) : reviews.length === 0 ? (
            <div className="tablet-empty-banner">
              <span>
                Không có lượt chấm công chờ duyệt. Dữ liệu cũ thiếu quyền xác nhận cần xử lý bằng luồng chỉnh công.
              </span>
              <button type="button" disabled={loading || busy} onClick={() => void load()}>
                Kiểm tra lại
              </button>
            </div>
          ) : (
            <>
              <div className="tablet-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Hồ sơ / tablet</th>
                      <th>Thời điểm tiếp nhận</th>
                      <th>Trạng thái / lý do</th>
                      <th>Xử lý</th>
                    </tr>
                  </thead>
                  <tbody>
                    {reviews.map((r) => (
                      <tr key={r.id}>
                        <td>
                          <small>
                            {r.id}
                            <br />
                            {r.deviceId}
                            <br />
                            Lượt: {r.localLogId}
                            <br />
                            Nhân viên: {r.employeeId}
                            <br />
                            {r.attendanceType} · {date(r.capturedAt ?? null)}
                          </small>
                        </td>
                        <td>{date(r.createdAt)}</td>
                        <td>
                          {r.status === 'LEGACY_REVIEW' ? 'Dữ liệu cũ — cần chỉnh công' : 'Chờ duyệt'}
                          <br />
                          {r.error}
                        </td>
                        <td>
                          <div className="tablet-actions">
                            <button type="button" disabled={busy} onClick={() => void showReview(r.id)}>
                              Chi tiết
                            </button>
                            {canReview && r.status !== 'LEGACY_REVIEW' && (
                              <button type="button" disabled={busy} onClick={() => select(r.id, 'review', 'approve', 'Duyệt lượt chấm công')}>
                                Duyệt
                              </button>
                            )}
                            {canReview && (
                              <button type="button" disabled={busy} onClick={() => select(r.id, 'review', 'reject', 'Từ chối lượt chấm công')}>
                                Từ chối
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              {(page > 0 || !last) && (
                <div className="tablet-actions">
                  <button type="button" disabled={page === 0 || loading || busy} onClick={() => setPage((p) => p - 1)}>
                    Trang trước
                  </button>
                  <span>Trang {page + 1}</span>
                  <button type="button" disabled={last || loading || busy} onClick={() => setPage((p) => p + 1)}>
                    Trang sau
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {action && (
        <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label={action.label}>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              void submit();
            }}
          >
            <h3>{action.label}</h3>
            <p>
              {action.type === 'device' && action.action !== 'block'
                ? 'Duyệt máy này sẽ khóa tablet khác đang được duyệt cho cùng tài khoản.'
                : 'Thay đổi được ghi vào lịch sử quản trị.'}
            </p>
            <label>
              Lý do
              <textarea
                autoFocus
                required
                maxLength={500}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
            </label>
            <div className="tablet-actions">
              <button disabled={busy || !reason.trim()} type="submit">
                {busy ? 'Đang lưu…' : 'Xác nhận'}
              </button>
              <button disabled={busy} type="button" onClick={() => setAction(null)}>
                Hủy
              </button>
            </div>
          </form>
        </div>
      )}

      {detail && (
        <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label="Chi tiết lượt chấm công">
          <div>
            <h3>Chi tiết lượt chấm công</h3>
            <p>
              Nhân viên: {detail.employeeId}
              <br />
              Thời điểm: {date(detail.capturedAt ?? null)}
              <br />
              Loại: {detail.attendanceType}
              <br />
              Tablet: {detail.deviceId}
            </p>
            <p>{detail.error}</p>
            {detail.faceImageBase64 &&
              detail.imageContentType &&
              /^image\/(jpeg|png)$/.test(detail.imageContentType) && (
                <img
                  alt="Ảnh xác minh lượt chấm công"
                  style={{ maxWidth: '100%', maxHeight: 360 }}
                  src={`data:${detail.imageContentType};base64,${detail.faceImageBase64}`}
                />
              )}
            <button type="button" onClick={() => setDetail(null)}>
              Đóng
            </button>
          </div>
        </div>
      )}

      {events && (
        <div className="tablet-dialog" role="dialog" aria-modal="true" aria-label="Lịch sử tablet">
          <div>
            <h3>Lịch sử tablet</h3>
            {events.length === 0 ? (
              <p>Chưa có sự kiện.</p>
            ) : (
              <ul>
                {events.map((e) => (
                  <li key={e.id}>
                    {date(e.occurredAt)} · {e.action}
                    <br />
                    {e.reason}
                    <br />
                    <small>Người thao tác: {e.actorId}</small>
                  </li>
                ))}
              </ul>
            )}
            <button type="button" onClick={() => setEvents(null)}>
              Đóng
            </button>
          </div>
        </div>
      )}
    </section>
  );
}

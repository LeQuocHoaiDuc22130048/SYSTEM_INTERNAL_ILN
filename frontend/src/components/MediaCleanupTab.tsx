import React, { useState, useEffect, useCallback } from 'react';
import {
  HardDrive,
  Play,
  RotateCcw,
  RefreshCw,
  CheckCircle2,
  AlertTriangle,
  Clock,
  Trash2,
  ShieldCheck,
  FileText,
  Database,
  CloudOff,
  Activity,
  X,
  ChevronLeft,
  ChevronRight,
  Loader2,
  Calendar,
  Save,
} from 'lucide-react';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import './MediaCleanupTab.css';

interface CleanupDashboardStats {
  engineEnabled: boolean;
  cronExpression: string;
  batchSize: number;
  activeMediaCount: number;
  eligibleExpiredCandidates: number;
  cleanupInProgressCount: number;
  softDeletedMediaCount: number;
  permanentlyFailedMediaCount: number;
  totalFreedBytes: number;
}

type CleanupScheduleMode = 'SPECIFIC_DATETIME' | 'MONTHLY' | 'WEEKLY' | 'DAILY';

interface MediaCleanupScheduleConfig {
  id: number;
  enabled: boolean;
  scheduleMode: CleanupScheduleMode;
  scheduledRunAt?: string | null;
  dayOfMonth?: number | null;
  dayOfWeek?: number | null;
  timeOfDay: string;
  unreferencedUploadTtlHours: number;
  deletedMessageMediaTtlDays: number;
  closedRepairMediaTtlDays: number;
  lastTriggeredAt?: string | null;
  updatedBy?: string | null;
  updatedAt?: string | null;
}

interface MediaCleanupJob {
  id: string;
  jobCode: string;
  triggerType: 'SCHEDULED' | 'MANUAL_ADMIN' | 'STARTUP_RECOVERY';
  status: 'RUNNING' | 'COMPLETED' | 'PARTIAL_FAILURE' | 'FAILED' | 'INTERRUPTED_RECOVERED';
  instanceId: string;
  batchSize: number;
  totalBatches: number;
  totalProcessed: number;
  deletedCount: number;
  failedCount: number;
  skippedCount: number;
  freedBytes: number;
  errorSummary?: string | null;
  startedAt: string;
  finishedAt?: string | null;
  lastHeartbeatAt: string;
}

interface MediaCleanupLog {
  id: string;
  jobId: string;
  mediaId: string;
  bucketName: string;
  objectKey: string;
  fileSize: number;
  action:
    | 'S3_DELETE_AND_SOFT_DELETE'
    | 'RETRY_SCHEDULED'
    | 'MARK_PERMANENT_FAILED'
    | 'SKIP_REFERENCED'
    | 'RECOVERY_RESET';
  outcome: 'SUCCESS' | 'FAILED' | 'SKIPPED';
  attemptNumber: number;
  durationMs: number;
  errorCode?: string | null;
  errorMessage?: string | null;
  createdAt: string;
}

interface MediaAssetItem {
  id: string;
  bucketName: string;
  objectKey: string;
  storageUrl?: string | null;
  originalFilename?: string | null;
  contentType?: string | null;
  fileSize: number;
  moduleSource: string;
  status: 'ACTIVE' | 'CLEANUP_IN_PROGRESS' | 'SOFT_DELETED' | 'FAILED_PERMANENT';
  expiresAt?: string | null;
  deletedAt?: string | null;
  retryCount: number;
  maxRetries: number;
  nextRetryAt?: string | null;
  lastErrorCode?: string | null;
  lastErrorMessage?: string | null;
  createdAt: string;
  updatedAt: string;
}

interface MediaCleanupTabProps {
  showToast: (message: string) => void;
  refreshTrigger?: number;
}

function formatBytes(bytes: number): string {
  if (!bytes || bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const idx = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
  const value = bytes / Math.pow(1024, idx);
  return `${value.toFixed(idx === 0 ? 0 : 2)} ${units[idx]}`;
}

function formatDateTime(iso?: string | null): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('vi-VN');
  } catch {
    return iso;
  }
}

function toDatetimeLocalValue(iso?: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}T${hh}:${min}`;
}

export const MediaCleanupTab: React.FC<MediaCleanupTabProps> = ({ showToast, refreshTrigger }) => {
  const [stats, setStats] = useState<CleanupDashboardStats | null>(null);
  const [activeSubTab, setActiveSubTab] = useState<'jobs' | 'assets'>('jobs');

  // Schedule state
  const [scheduleEnabled, setScheduleEnabled] = useState<boolean>(false);
  const [scheduleMode, setScheduleMode] = useState<CleanupScheduleMode>('SPECIFIC_DATETIME');
  const [scheduledRunAtInput, setScheduledRunAtInput] = useState<string>('');
  const [dayOfMonth, setDayOfMonth] = useState<number>(1);
  const [dayOfWeek, setDayOfWeek] = useState<number>(1);
  const [timeOfDay, setTimeOfDay] = useState<string>('02:00');
  const [unreferencedTtlHours, setUnreferencedTtlHours] = useState<number>(24);
  const [deletedMsgTtlDays, setDeletedMsgTtlDays] = useState<number>(7);
  const [closedRepairTtlDays, setClosedRepairTtlDays] = useState<number>(180);
  const [lastTriggeredAt, setLastTriggeredAt] = useState<string | null>(null);
  const [savingSchedule, setSavingSchedule] = useState<boolean>(false);

  // Jobs state
  const [jobs, setJobs] = useState<MediaCleanupJob[]>([]);
  const [jobsPage, setJobsPage] = useState(0);
  const [jobsTotalPages, setJobsTotalPages] = useState(1);

  // Assets state
  const [assets, setAssets] = useState<MediaAssetItem[]>([]);
  const [assetStatusFilter, setAssetStatusFilter] = useState<
    'FAILED_PERMANENT' | 'ACTIVE' | 'CLEANUP_IN_PROGRESS' | 'SOFT_DELETED'
  >('FAILED_PERMANENT');
  const [assetsPage, setAssetsPage] = useState(0);
  const [assetsTotalPages, setAssetsTotalPages] = useState(1);

  // Audit Log modal state
  const [selectedJob, setSelectedJob] = useState<MediaCleanupJob | null>(null);
  const [jobLogs, setJobLogs] = useState<MediaCleanupLog[]>([]);
  const [loadingLogs, setLoadingLogs] = useState(false);

  // Loading states
  const [loading, setLoading] = useState(true);
  const [triggeringCleanup, setTriggeringCleanup] = useState(false);
  const [recovering, setRecovering] = useState(false);
  const [retryingMediaId, setRetryingMediaId] = useState<string | null>(null);

  const fetchStats = useCallback(async () => {
    try {
      const res = await fetch('/api/v1/admin/media-cleanup/stats', {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const body = await res.json();
        if (body?.data) setStats(body.data);
      }
    } catch (err) {
      console.error('Lỗi tải thống kê Media Cleanup:', err);
    }
  }, []);

  const fetchSchedule = useCallback(async () => {
    try {
      const res = await fetch('/api/v1/admin/media-cleanup/schedule', {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const body = await res.json();
        const cfg: MediaCleanupScheduleConfig | undefined = body?.data;
        if (cfg) {
          setScheduleEnabled(Boolean(cfg.enabled));
          setScheduleMode(cfg.scheduleMode || 'SPECIFIC_DATETIME');
          setScheduledRunAtInput(toDatetimeLocalValue(cfg.scheduledRunAt));
          setDayOfMonth(cfg.dayOfMonth || 1);
          setDayOfWeek(cfg.dayOfWeek || 1);
          setTimeOfDay(cfg.timeOfDay || '02:00');
          setUnreferencedTtlHours(cfg.unreferencedUploadTtlHours ?? 24);
          setDeletedMsgTtlDays(cfg.deletedMessageMediaTtlDays ?? 7);
          setClosedRepairTtlDays(cfg.closedRepairMediaTtlDays ?? 180);
          setLastTriggeredAt(cfg.lastTriggeredAt || null);
        }
      }
    } catch (err) {
      console.error('Lỗi tải cấu hình lịch hẹn Media Cleanup:', err);
    }
  }, []);

  const fetchJobs = useCallback(async (page = 0) => {
    try {
      const res = await fetch(`/api/v1/admin/media-cleanup/jobs?page=${page}&size=15`, {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const body = await res.json();
        const pageData = body?.data;
        if (pageData) {
          setJobs(pageData.content || []);
          setJobsTotalPages(Math.max(1, pageData.totalPages || 1));
        }
      }
    } catch (err) {
      console.error('Lỗi tải danh sách Cleanup Jobs:', err);
    }
  }, []);

  const fetchAssets = useCallback(
    async (status = assetStatusFilter, page = 0) => {
      try {
        const res = await fetch(
          `/api/v1/admin/media-cleanup/assets?status=${status}&page=${page}&size=15`,
          { headers: getAuthHeaders() }
        );
        if (res.ok) {
          const body = await res.json();
          const pageData = body?.data;
          if (pageData) {
            setAssets(pageData.content || []);
            setAssetsTotalPages(Math.max(1, pageData.totalPages || 1));
          }
        }
      } catch (err) {
        console.error('Lỗi tải danh sách Media Assets:', err);
      }
    },
    [assetStatusFilter]
  );

  const loadAll = useCallback(async () => {
    setLoading(true);
    await Promise.all([
      fetchStats(),
      fetchSchedule(),
      fetchJobs(jobsPage),
      fetchAssets(assetStatusFilter, assetsPage),
    ]);
    setLoading(false);
  }, [fetchStats, fetchSchedule, fetchJobs, fetchAssets, jobsPage, assetStatusFilter, assetsPage]);

  useEffect(() => {
    void loadAll();
  }, [loadAll, refreshTrigger]);

  const handleSaveSchedule = async () => {
    if (scheduleEnabled && scheduleMode === 'SPECIFIC_DATETIME' && !scheduledRunAtInput) {
      showToast('Vui lòng chọn Ngày & Giờ xác định để hẹn chạy Cleanup.');
      return;
    }

    setSavingSchedule(true);
    try {
      const isoTarget =
        scheduledRunAtInput && !Number.isNaN(new Date(scheduledRunAtInput).getTime())
          ? new Date(scheduledRunAtInput).toISOString()
          : null;

      const res = await fetch('/api/v1/admin/media-cleanup/schedule', {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({
          enabled: scheduleEnabled,
          scheduleMode,
          scheduledRunAt: isoTarget,
          dayOfMonth,
          dayOfWeek,
          timeOfDay,
          unreferencedUploadTtlHours: unreferencedTtlHours,
          deletedMessageMediaTtlDays: deletedMsgTtlDays,
          closedRepairMediaTtlDays: closedRepairTtlDays,
        }),
      });
      const body = await res.json();
      if (res.ok && body?.data) {
        const cfg: MediaCleanupScheduleConfig = body.data;
        setScheduledRunAtInput(toDatetimeLocalValue(cfg.scheduledRunAt));
        showToast('Đã lưu cấu hình thời gian chạy Media Cleanup thành công.');
      } else {
        showToast(body?.message || 'Không thể lưu cấu hình lịch hẹn.');
      }
    } catch {
      showToast('Lỗi kết nối khi lưu cấu hình lịch hẹn.');
    } finally {
      setSavingSchedule(false);
    }
  };

  const handleTriggerCleanup = async () => {
    setTriggeringCleanup(true);
    try {
      const res = await fetch('/api/v1/admin/media-cleanup/trigger', {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      const body = await res.json();
      if (res.ok && body?.data) {
        const job: MediaCleanupJob = body.data;
        showToast(
          `Đã chạy Cleanup (${job.jobCode}): Xóa ${job.deletedCount} tệp (${formatBytes(job.freedBytes)}), Lỗi ${job.failedCount}`
        );
        await loadAll();
      } else {
        showToast(body?.message || 'Không thể chạy Media Cleanup thủ công.');
      }
    } catch {
      showToast('Lỗi kết nối khi kích hoạt Media Cleanup.');
    } finally {
      setTriggeringCleanup(false);
    }
  };

  const handleRecoverStuck = async () => {
    setRecovering(true);
    try {
      const res = await fetch('/api/v1/admin/media-cleanup/recover', {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      const body = await res.json();
      if (res.ok && body?.data) {
        const { recoveredJobs, recoveredMediaAssets } = body.data;
        showToast(
          `Phục hồi hoàn tất: ${recoveredJobs} job gián đoạn, ${recoveredMediaAssets} bản ghi CLEANUP_IN_PROGRESS.`
        );
        await loadAll();
      } else {
        showToast(body?.message || 'Không thể chạy phục hồi trạng thái treo.');
      }
    } catch {
      showToast('Lỗi kết nối khi chạy phục hồi trạng thái treo.');
    } finally {
      setRecovering(false);
    }
  };

  const handleRetryAsset = async (mediaId: string) => {
    setRetryingMediaId(mediaId);
    try {
      const res = await fetch(`/api/v1/admin/media-cleanup/assets/${mediaId}/retry`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });
      const body = await res.json();
      if (res.ok) {
        showToast('Đã đặt lại trạng thái retry cho bản ghi Media.');
        await loadAll();
      } else {
        showToast(body?.message || 'Không thể đặt lại trạng thái retry.');
      }
    } catch {
      showToast('Lỗi kết nối máy chủ.');
    } finally {
      setRetryingMediaId(null);
    }
  };

  const handleOpenJobLogs = async (job: MediaCleanupJob) => {
    setSelectedJob(job);
    setLoadingLogs(true);
    setJobLogs([]);
    try {
      const res = await fetch(`/api/v1/admin/media-cleanup/jobs/${job.id}/logs?page=0&size=100`, {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const body = await res.json();
        setJobLogs(body?.data?.content || []);
      } else {
        showToast('Không thể tải nhật ký Audit Log của phiên chạy này.');
      }
    } catch {
      showToast('Lỗi kết nối khi tải Audit Log.');
    } finally {
      setLoadingLogs(false);
    }
  };

  const renderJobStatusBadge = (status: MediaCleanupJob['status']) => {
    switch (status) {
      case 'COMPLETED':
        return <span className="mc-status-badge completed">COMPLETED</span>;
      case 'RUNNING':
        return <span className="mc-status-badge running">RUNNING</span>;
      case 'PARTIAL_FAILURE':
        return <span className="mc-status-badge partial">PARTIAL_FAILURE</span>;
      case 'INTERRUPTED_RECOVERED':
        return <span className="mc-status-badge recovered">RECOVERED</span>;
      default:
        return <span className="mc-status-badge failed">{status}</span>;
    }
  };

  const renderAssetStatusBadge = (status: MediaAssetItem['status']) => {
    switch (status) {
      case 'ACTIVE':
        return <span className="mc-status-badge active">ACTIVE</span>;
      case 'CLEANUP_IN_PROGRESS':
        return <span className="mc-status-badge in-progress">IN_PROGRESS</span>;
      case 'SOFT_DELETED':
        return <span className="mc-status-badge soft-deleted">SOFT_DELETED</span>;
      default:
        return <span className="mc-status-badge permanent">FAILED_PERMANENT</span>;
    }
  };

  return (
    <div className="mc-container">
      {/* Hero Banner */}
      <div className="mc-hero-banner">
        <div className="mc-hero-left">
          <div className="mc-hero-badge-row">
            <span className={`mc-badge-pill ${scheduleEnabled ? 'enabled' : 'info'}`}>
              <CheckCircle2 size={13} />
              {scheduleEnabled ? 'ĐÃ HẸN GIỜ TỰ ĐỘNG' : 'CHỈ CHẠY KHI ĐẾN MỐC CHỈ ĐỊNH'}
            </span>
            <span className="mc-badge-pill info">
              <Clock size={13} />
              {scheduleEnabled && scheduledRunAtInput
                ? `Mốc chạy tiếp theo: ${formatDateTime(new Date(scheduledRunAtInput).toISOString())}`
                : 'Không chạy liên tục hàng ngày'}
            </span>
            <span className="mc-badge-pill info">
              <Database size={13} />
              ShedLock + PostgreSQL SKIP LOCKED (Batch {stats?.batchSize || 100})
            </span>
          </div>
          <h2 className="mc-hero-title">
            <HardDrive size={22} />
            Media Cleanup Engine — Giám sát &amp; Hẹn giờ Xóa
          </h2>
          <p className="mc-hero-desc">
            Chỉ thu hồi tệp S3/MinIO khi đến đúng <strong>mốc thời gian xác định</strong> và tệp đã hết hạn (
            <code>expires_at</code>), không còn tham chiếu (<code>media_references</code>). Xóa theo lô 100 bản
            ghi: S3 xóa trước, PostgreSQL cập nhật <code>SOFT_DELETED</code> sau.
          </p>
        </div>

        <div className="mc-hero-actions">
          <button
            type="button"
            className="mc-btn mc-btn-primary"
            onClick={handleTriggerCleanup}
            disabled={triggeringCleanup}
          >
            {triggeringCleanup ? <Loader2 size={15} className="spin" /> : <Play size={15} />}
            Chạy Cleanup ngay
          </button>
          <button
            type="button"
            className="mc-btn mc-btn-amber"
            onClick={handleRecoverStuck}
            disabled={recovering}
            title="Phục hồi các Job RUNNING hoặc bản ghi CLEANUP_IN_PROGRESS bị kẹt sau restart"
          >
            {recovering ? <Loader2 size={15} className="spin" /> : <RotateCcw size={15} />}
            Phục hồi Job treo
          </button>
          <button
            type="button"
            className="mc-btn mc-btn-ghost"
            onClick={() => void loadAll()}
            disabled={loading}
          >
            <RefreshCw size={15} className={loading ? 'spin' : ''} />
            Làm mới
          </button>
        </div>
      </div>

      {/* Schedule & Retention Config Card */}
      <div className="mc-schedule-card">
        <div className="mc-schedule-header">
          <h3 className="mc-schedule-title">
            <Calendar size={18} color="#2563eb" />
            Hẹn thời gian xác định chạy Media Cleanup (Không xóa liên tục)
          </h3>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
            {lastTriggeredAt && (
              <span style={{ fontSize: 12, color: '#64748b' }}>
                Lần chạy theo lịch gần nhất: <strong>{formatDateTime(lastTriggeredAt)}</strong>
              </span>
            )}
            <label className="mc-toggle-label">
              <input
                type="checkbox"
                checked={scheduleEnabled}
                onChange={(e) => setScheduleEnabled(e.target.checked)}
              />
              Kích hoạt hẹn giờ chạy tự động
            </label>
          </div>
        </div>

        <div className="mc-schedule-grid">
          <div className="mc-field">
            <label>Chế độ hẹn giờ chạy</label>
            <select
              className="mc-select"
              value={scheduleMode}
              onChange={(e) => setScheduleMode(e.target.value as CleanupScheduleMode)}
            >
              <option value="SPECIFIC_DATETIME">
                Chỉ chạy 1 lần vào Ngày &amp; Giờ xác định (Không lặp lại)
              </option>
              <option value="MONTHLY">Định kỳ mỗi tháng 1 lần (Ngày &amp; Giờ cố định)</option>
              <option value="WEEKLY">Định kỳ mỗi tuần 1 lần (Thứ &amp; Giờ cố định)</option>
              <option value="DAILY">Định kỳ mỗi ngày (Giờ cố định)</option>
            </select>
          </div>

          {scheduleMode === 'SPECIFIC_DATETIME' ? (
            <div className="mc-field">
              <label>Thời điểm xác định chạy Cleanup</label>
              <input
                type="datetime-local"
                className="mc-input"
                value={scheduledRunAtInput}
                onChange={(e) => setScheduledRunAtInput(e.target.value)}
              />
            </div>
          ) : (
            <>
              {scheduleMode === 'MONTHLY' && (
                <div className="mc-field">
                  <label>Ngày trong tháng (1 - 28)</label>
                  <input
                    type="number"
                    min={1}
                    max={28}
                    className="mc-input"
                    value={dayOfMonth}
                    onChange={(e) => setDayOfMonth(Number(e.target.value) || 1)}
                  />
                </div>
              )}
              {scheduleMode === 'WEEKLY' && (
                <div className="mc-field">
                  <label>Thứ trong tuần</label>
                  <select
                    className="mc-select"
                    value={dayOfWeek}
                    onChange={(e) => setDayOfWeek(Number(e.target.value))}
                  >
                    <option value={1}>Thứ Hai</option>
                    <option value={2}>Thứ Ba</option>
                    <option value={3}>Thứ Tư</option>
                    <option value={4}>Thứ Năm</option>
                    <option value={5}>Thứ Sáu</option>
                    <option value={6}>Thứ Bảy</option>
                    <option value={7}>Chủ Nhật</option>
                  </select>
                </div>
              )}
              <div className="mc-field">
                <label>Giờ chạy (HH:mm)</label>
                <input
                  type="time"
                  className="mc-input"
                  value={timeOfDay}
                  onChange={(e) => setTimeOfDay(e.target.value)}
                />
              </div>
            </>
          )}

          <div className="mc-field">
            <label>Hạn tệp upload nháp (Giờ)</label>
            <input
              type="number"
              min={1}
              className="mc-input"
              value={unreferencedTtlHours}
              onChange={(e) => setUnreferencedTtlHours(Math.max(1, Number(e.target.value) || 24))}
            />
          </div>

          <div className="mc-field">
            <label>Hạn media tin nhắn đã xóa (Ngày)</label>
            <input
              type="number"
              min={0}
              className="mc-input"
              value={deletedMsgTtlDays}
              onChange={(e) => setDeletedMsgTtlDays(Math.max(0, Number(e.target.value) || 7))}
            />
          </div>

          <div className="mc-field">
            <label>Hạn media đơn đã đóng (Ngày)</label>
            <input
              type="number"
              min={1}
              className="mc-input"
              value={closedRepairTtlDays}
              onChange={(e) => setClosedRepairTtlDays(Math.max(1, Number(e.target.value) || 180))}
            />
          </div>

          <div className="mc-field">
            <button
              type="button"
              className="mc-btn mc-btn-primary"
              onClick={() => void handleSaveSchedule()}
              disabled={savingSchedule}
              style={{ justifyContent: 'center', height: 37 }}
            >
              {savingSchedule ? <Loader2 size={15} className="spin" /> : <Save size={15} />}
              Lưu lịch hẹn
            </button>
          </div>
        </div>
      </div>

      {/* 6 Design Decisions Verification Strip */}
      <div className="mc-decisions-card">
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>Retention dựa trên <code>expires_at</code></span>
        </div>
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>Chỉ xóa Media hết hạn &amp; không còn Reference</span>
        </div>
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>Xóa theo batch {stats?.batchSize || 100} records</span>
        </div>
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>S3 xóa trước, PostgreSQL cập nhật sau</span>
        </div>
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>Giữ bản ghi <code>SOFT_DELETED</code> (không xóa vật lý)</span>
        </div>
        <div className="mc-decision-item">
          <CheckCircle2 size={15} />
          <span>Retry Exponential Backoff &amp; phục hồi sau Restart</span>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="mc-kpi-grid">
        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Media đang hoạt động</span>
            <span className="mc-kpi-icon blue">
              <Database size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">{stats ? stats.activeMediaCount.toLocaleString('vi-VN') : '0'}</div>
          <div className="mc-kpi-sub">Trạng thái ACTIVE trong PostgreSQL</div>
        </div>

        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Đủ điều kiện chờ xóa</span>
            <span className="mc-kpi-icon amber">
              <Clock size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">
            {stats ? stats.eligibleExpiredCandidates.toLocaleString('vi-VN') : '0'}
          </div>
          <div className="mc-kpi-sub">Hết hạn &amp; không còn reference active</div>
        </div>

        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Đang xử lý (Row Locked)</span>
            <span className="mc-kpi-icon cyan">
              <Activity size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">
            {stats ? stats.cleanupInProgressCount.toLocaleString('vi-VN') : '0'}
          </div>
          <div className="mc-kpi-sub">CLEANUP_IN_PROGRESS hiện tại</div>
        </div>

        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Đã dọn dẹp (Soft Deleted)</span>
            <span className="mc-kpi-icon emerald">
              <Trash2 size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">
            {stats ? stats.softDeletedMediaCount.toLocaleString('vi-VN') : '0'}
          </div>
          <div className="mc-kpi-sub">Đã xóa S3 &amp; giữ lịch sử đối soát DB</div>
        </div>

        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Lỗi vĩnh viễn (Cần kiểm tra)</span>
            <span className="mc-kpi-icon rose">
              <CloudOff size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">
            {stats ? stats.permanentlyFailedMediaCount.toLocaleString('vi-VN') : '0'}
          </div>
          <div className="mc-kpi-sub">Vượt quá số lần retry Exponential Backoff</div>
        </div>

        <div className="mc-kpi-card">
          <div className="mc-kpi-header">
            <span>Dung lượng S3 giải phóng</span>
            <span className="mc-kpi-icon purple">
              <ShieldCheck size={17} />
            </span>
          </div>
          <div className="mc-kpi-value">{formatBytes(stats?.totalFreedBytes || 0)}</div>
          <div className="mc-kpi-sub">Tổng dung lượng Object Storage thu hồi</div>
        </div>
      </div>

      {/* Main Panel: Jobs History & Media Assets */}
      <div className="mc-panel">
        <div className="mc-panel-header">
          <div className="mc-subtabs">
            <button
              type="button"
              className={`mc-subtab-btn ${activeSubTab === 'jobs' ? 'active' : ''}`}
              onClick={() => setActiveSubTab('jobs')}
            >
              <FileText size={15} />
              Lịch sử Cleanup Job &amp; Audit Log
            </button>
            <button
              type="button"
              className={`mc-subtab-btn ${activeSubTab === 'assets' ? 'active' : ''}`}
              onClick={() => setActiveSubTab('assets')}
            >
              <HardDrive size={15} />
              Quản lý Bản ghi Media &amp; Retry
            </button>
          </div>

          {activeSubTab === 'assets' && (
            <div className="mc-filter-bar">
              <span style={{ fontSize: 12.5, color: '#64748b', fontWeight: 600 }}>Trạng thái:</span>
              <select
                className="mc-select"
                value={assetStatusFilter}
                onChange={(e) => {
                  const next = e.target.value as typeof assetStatusFilter;
                  setAssetStatusFilter(next);
                  setAssetsPage(0);
                }}
              >
                <option value="FAILED_PERMANENT">FAILED_PERMANENT (Lỗi cần xử lý)</option>
                <option value="ACTIVE">ACTIVE (Đang lưu trữ / Chờ retry)</option>
                <option value="CLEANUP_IN_PROGRESS">CLEANUP_IN_PROGRESS (Đang khóa batch)</option>
                <option value="SOFT_DELETED">SOFT_DELETED (Đã xóa S3, lưu đối soát)</option>
              </select>
            </div>
          )}
        </div>

        {activeSubTab === 'jobs' ? (
          <>
            <div className="mc-table-wrap">
              {jobs.length === 0 ? (
                <div className="mc-empty">
                  <FileText size={32} />
                  <strong>Chưa có phiên chạy Cleanup Job nào</strong>
                  <span>
                    Hệ thống chỉ chạy khi đến đúng thời gian xác định bạn đã hẹn hoặc khi nhấn &ldquo;Chạy
                    Cleanup ngay&rdquo;.
                  </span>
                </div>
              ) : (
                <table className="mc-table">
                  <thead>
                    <tr>
                      <th>Mã Job</th>
                      <th>Nguồn kích hoạt</th>
                      <th>Trạng thái</th>
                      <th>Batch (Size 100)</th>
                      <th>Đã xóa S3</th>
                      <th>Bỏ qua / Lỗi</th>
                      <th>Dung lượng giải phóng</th>
                      <th>Thời gian bắt đầu</th>
                      <th>Chi tiết Audit</th>
                    </tr>
                  </thead>
                  <tbody>
                    {jobs.map((job) => (
                      <tr key={job.id}>
                        <td className="mc-mono" style={{ fontWeight: 700 }}>
                          {job.jobCode}
                        </td>
                        <td>
                          <span className="mc-mono">{job.triggerType}</span>
                        </td>
                        <td>{renderJobStatusBadge(job.status)}</td>
                        <td>
                          {job.totalBatches} batch ({job.totalProcessed} tệp)
                        </td>
                        <td style={{ color: '#059669', fontWeight: 700 }}>{job.deletedCount}</td>
                        <td>
                          <span style={{ color: '#d97706', fontWeight: 600 }}>{job.skippedCount}</span> /{' '}
                          <span style={{ color: job.failedCount > 0 ? '#e11d48' : '#64748b', fontWeight: 700 }}>
                            {job.failedCount}
                          </span>
                        </td>
                        <td style={{ fontWeight: 700 }}>{formatBytes(job.freedBytes)}</td>
                        <td>{formatDateTime(job.startedAt)}</td>
                        <td>
                          <button
                            type="button"
                            className="mc-btn mc-btn-outline"
                            onClick={() => void handleOpenJobLogs(job)}
                          >
                            <FileText size={13} />
                            Audit Log
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            <div className="mc-pagination">
              <span>
                Trang {jobsPage + 1} / {jobsTotalPages}
              </span>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  type="button"
                  className="mc-btn mc-btn-outline"
                  disabled={jobsPage <= 0}
                  onClick={() => setJobsPage((p) => Math.max(0, p - 1))}
                >
                  <ChevronLeft size={14} /> Trước
                </button>
                <button
                  type="button"
                  className="mc-btn mc-btn-outline"
                  disabled={jobsPage + 1 >= jobsTotalPages}
                  onClick={() => setJobsPage((p) => p + 1)}
                >
                  Sau <ChevronRight size={14} />
                </button>
              </div>
            </div>
          </>
        ) : (
          <>
            <div className="mc-table-wrap">
              {assets.length === 0 ? (
                <div className="mc-empty">
                  <HardDrive size={32} />
                  <strong>Không có bản ghi Media nào ở trạng thái {assetStatusFilter}</strong>
                  <span>Bạn có thể chọn bộ lọc trạng thái khác ở góc phải phía trên.</span>
                </div>
              ) : (
                <table className="mc-table">
                  <thead>
                    <tr>
                      <th>Bucket / Object Key</th>
                      <th>Phân hệ</th>
                      <th>Dung lượng</th>
                      <th>Trạng thái</th>
                      <th>Hết hạn (expires_at)</th>
                      <th>Retry / Backoff</th>
                      <th>Lỗi gần nhất</th>
                      <th>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {assets.map((asset) => (
                      <tr key={asset.id}>
                        <td>
                          <div style={{ fontWeight: 600 }}>{asset.originalFilename || asset.objectKey}</div>
                          <div className="mc-mono" style={{ color: '#64748b', fontSize: 11.5 }}>
                            {asset.bucketName}/{asset.objectKey}
                          </div>
                        </td>
                        <td>
                          <span className="mc-mono">{asset.moduleSource}</span>
                        </td>
                        <td>{formatBytes(asset.fileSize)}</td>
                        <td>{renderAssetStatusBadge(asset.status)}</td>
                        <td>
                          <div>{formatDateTime(asset.expiresAt)}</div>
                          {asset.deletedAt && (
                            <div style={{ fontSize: 11, color: '#64748b' }}>
                              Xóa mềm: {formatDateTime(asset.deletedAt)}
                            </div>
                          )}
                        </td>
                        <td>
                          <div style={{ fontWeight: 600 }}>
                            {asset.retryCount} / {asset.maxRetries}
                          </div>
                          {asset.nextRetryAt && (
                            <div style={{ fontSize: 11, color: '#d97706' }}>
                              Kế tiếp: {formatDateTime(asset.nextRetryAt)}
                            </div>
                          )}
                        </td>
                        <td>
                          {asset.lastErrorCode ? (
                            <span style={{ color: '#e11d48', fontSize: 12 }}>
                              <strong>{asset.lastErrorCode}:</strong> {asset.lastErrorMessage}
                            </span>
                          ) : (
                            '—'
                          )}
                        </td>
                        <td>
                          {asset.status !== 'SOFT_DELETED' && (
                            <button
                              type="button"
                              className="mc-btn mc-btn-outline"
                              disabled={retryingMediaId === asset.id}
                              onClick={() => void handleRetryAsset(asset.id)}
                            >
                              {retryingMediaId === asset.id ? (
                                <Loader2 size={13} className="spin" />
                              ) : (
                                <RotateCcw size={13} />
                              )}
                              Đặt lại Retry
                            </button>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            <div className="mc-pagination">
              <span>
                Trang {assetsPage + 1} / {assetsTotalPages}
              </span>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  type="button"
                  className="mc-btn mc-btn-outline"
                  disabled={assetsPage <= 0}
                  onClick={() => setAssetsPage((p) => Math.max(0, p - 1))}
                >
                  <ChevronLeft size={14} /> Trước
                </button>
                <button
                  type="button"
                  className="mc-btn mc-btn-outline"
                  disabled={assetsPage + 1 >= assetsTotalPages}
                  onClick={() => setAssetsPage((p) => p + 1)}
                >
                  Sau <ChevronRight size={14} />
                </button>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Audit Log Modal */}
      {selectedJob && (
        <div className="mc-modal-backdrop" onClick={() => setSelectedJob(null)}>
          <div className="mc-modal" onClick={(e) => e.stopPropagation()}>
            <div className="mc-modal-header">
              <h3 className="mc-modal-title">
                <FileText size={18} />
                Nhật ký Audit Log — Phiên {selectedJob.jobCode}
              </h3>
              <button
                type="button"
                className="mc-btn mc-btn-outline"
                onClick={() => setSelectedJob(null)}
              >
                <X size={15} /> Đóng
              </button>
            </div>
            <div className="mc-modal-body">
              {loadingLogs ? (
                <div className="mc-empty">
                  <Loader2 size={28} className="spin" />
                  <span>Đang tải nhật ký Audit Log...</span>
                </div>
              ) : jobLogs.length === 0 ? (
                <div className="mc-empty">
                  <AlertTriangle size={28} />
                  <span>Không có bản ghi Audit Log nào trong phiên chạy này.</span>
                </div>
              ) : (
                <table className="mc-table">
                  <thead>
                    <tr>
                      <th>Thời gian</th>
                      <th>Bucket / Object Key</th>
                      <th>Hành động</th>
                      <th>Kết quả</th>
                      <th>Lần thử</th>
                      <th>Thời gian S3</th>
                      <th>Chi tiết lỗi</th>
                    </tr>
                  </thead>
                  <tbody>
                    {jobLogs.map((logItem) => (
                      <tr key={logItem.id}>
                        <td>{formatDateTime(logItem.createdAt)}</td>
                        <td className="mc-mono">
                          {logItem.bucketName}/{logItem.objectKey}
                        </td>
                        <td className="mc-mono">{logItem.action}</td>
                        <td>
                          <span
                            className={`mc-status-badge ${
                              logItem.outcome === 'SUCCESS'
                                ? 'success'
                                : logItem.outcome === 'SKIPPED'
                                ? 'skipped'
                                : 'failed'
                            }`}
                          >
                            {logItem.outcome}
                          </span>
                        </td>
                        <td>#{logItem.attemptNumber}</td>
                        <td>{logItem.durationMs} ms</td>
                        <td style={{ color: '#e11d48', fontSize: 12 }}>
                          {logItem.errorCode
                            ? `${logItem.errorCode}: ${logItem.errorMessage || ''}`
                            : logItem.errorMessage || '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

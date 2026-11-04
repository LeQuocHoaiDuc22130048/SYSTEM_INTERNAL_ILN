import { usePermissionCheck } from '../utils/permissionContext';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Plus,
  Rocket,
  Copy,
  ExternalLink,
  AlertCircle,
  CheckCircle2,
  FileText,
  Clock,
  ShieldAlert,
  Loader2,
  Trash2,
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
  RotateCcw,
  Hash,
  HardDrive,
  Filter
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import './UpdateTab.css';

interface AppUpdate {
  id: string;
  version: string;
  changelog: string;
  downloadUrl: string;
  mandatory: boolean;
  status: 'DRAFT' | 'RELEASED' | 'ROLLED_BACK';
  platform: 'ANDROID' | 'IOS' | 'WEB';
  releasedAt: string | null;
  createdAt: string;
  sha256?: string | null;
  fileSize?: number | null;
  minSupportedVersion?: string | null;
  channel?: 'PRODUCTION' | 'BETA' | 'INTERNAL' | string;
}

interface UpdateTabProps {
  showToast: (message: string) => void;
  refreshTrigger?: number;
}

const AndroidIcon: React.FC<{ size?: number; className?: string }> = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className} style={{ display: 'inline-block', verticalAlign: 'middle', flexShrink: 0 }}>
    <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9993.4482.9993.9993.0001.5511-.4483.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.4116 13.8533 8.081 12 8.081c-1.8533 0-3.5902.3306-5.1368.8682L4.8409 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/>
  </svg>
);

const AppleIcon: React.FC<{ size?: number; className?: string }> = ({ size = 16, className = '' }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" className={className} style={{ display: 'inline-block', verticalAlign: 'middle', flexShrink: 0 }}>
    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 4.17c.66-.8 1.11-1.92.99-3.04-1 .04-2.15.67-2.82 1.45-.58.67-1.1 1.76-.96 2.85 1.11.09 2.19-.58 2.79-1.26z"/>
  </svg>
);

export const UpdateTab: React.FC<UpdateTabProps> = ({ showToast, refreshTrigger }) => {
  const canAction = usePermissionCheck();
  const [updates, setUpdates] = useState<AppUpdate[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [releasingId, setReleasingId] = useState<string | null>(null);
  const [rollingBackId, setRollingBackId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [selectedPlatformFilter, setSelectedPlatformFilter] = useState<'ALL' | 'ANDROID' | 'IOS'>('ALL');
  const [selectedChannelFilter, setSelectedChannelFilter] = useState<'ALL' | 'PRODUCTION' | 'BETA' | 'INTERNAL'>('ALL');
  const [expandedChangelogs, setExpandedChangelogs] = useState<Record<string, boolean>>({});

  // Phân trang
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(10);

  const toggleChangelog = (id: string) => {
    setExpandedChangelogs(prev => ({ ...prev, [id]: !prev[id] }));
  };

  // Form State
  const [platform, setPlatform] = useState<'ANDROID' | 'IOS'>('ANDROID');
  const [channel, setChannel] = useState<'PRODUCTION' | 'BETA' | 'INTERNAL'>('PRODUCTION');
  const [version, setVersion] = useState('');
  const [minSupportedVersion, setMinSupportedVersion] = useState('');
  const [changelog, setChangelog] = useState('');
  const [downloadUrl, setDownloadUrl] = useState('');
  const [mandatory, setMandatory] = useState(false);
  const [status, setStatus] = useState<'DRAFT' | 'RELEASED'>('DRAFT');
  const [uploadType, setUploadType] = useState<'file' | 'url'>('file');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);

  // Fetch all updates
  const fetchUpdates = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const response = await fetch('/api/v1/app-updates', {
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setUpdates(result.data);
        }
      } else {
        showToast('Không thể tải danh sách cập nhật.');
      }
    } catch (error) {
      console.error('Lỗi khi fetch updates:', error);
      showToast('Lỗi kết nối tới máy chủ.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [showToast]);

  useEffect(() => {
    fetchUpdates();
  }, [fetchUpdates]);

  // Lắng nghe tín hiệu làm mới dữ liệu từ Header
  useEffect(() => {
    if (refreshTrigger) {
      fetchUpdates(true);
    }
  }, [refreshTrigger, fetchUpdates]);

  // Tự động quay về trang 1 khi đổi bộ lọc
  useEffect(() => {
    setCurrentPage(1);
  }, [selectedPlatformFilter, selectedChannelFilter]);

  // Helper format file size
  const formatFileSize = (bytes?: number | null) => {
    if (bytes === undefined || bytes === null || bytes <= 0) return '-';
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  // Helper format sha256
  const formatSha256 = (sha?: string | null) => {
    if (!sha) return '-';
    if (sha.length <= 16) return sha;
    return `${sha.substring(0, 8)}...${sha.substring(sha.length - 6)}`;
  };

  // Handle copy link
  const handleCopyLink = (url: string) => {
    let fullUrl = url;
    if (url.startsWith('/')) {
      fullUrl = window.location.origin + url;
    }
    navigator.clipboard.writeText(fullUrl);
    showToast('Đã sao chép liên kết tải xuống!');
  };

  // Handle copy SHA-256
  const handleCopySha256 = (sha: string) => {
    navigator.clipboard.writeText(sha);
    showToast('Đã sao chép mã kiểm tra SHA-256!');
  };

  // Helper to compute default URL
  const computeDefaultUrl = (ver: string, targetPlatform: 'ANDROID' | 'IOS', type: 'file' | 'url') => {
    const clean = ver.trim().replace(/[^0-9.]/g, '');
    if (targetPlatform === 'IOS') {
      if (type === 'file') {
        return clean ? `/api/v1/app-updates/download/system_internal_v${clean}.ipa` : '';
      } else {
        return 'https://apps.apple.com/us/app/inverter-like-new-system/id6809314317';
      }
    } else {
      return clean ? `/api/v1/app-updates/download/system_internal_v${clean}.apk` : '';
    }
  };

  const handlePlatformChange = (newPlatform: 'ANDROID' | 'IOS') => {
    setPlatform(newPlatform);
    setSelectedFile(null);
    setDownloadUrl(computeDefaultUrl(version, newPlatform, uploadType));
  };

  const handleUploadTypeChange = (newType: 'file' | 'url') => {
    setUploadType(newType);
    setSelectedFile(null);
    setDownloadUrl(computeDefaultUrl(version, platform, newType));
  };

  const handleVersionChange = (val: string) => {
    setVersion(val);
    setDownloadUrl(computeDefaultUrl(val, platform, uploadType));
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];
      const lowerName = file.name.toLowerCase();

      if (platform === 'ANDROID' && !lowerName.endsWith('.apk')) {
        showToast('Tệp đã chọn không hợp lệ! Vui lòng chọn tệp có đuôi .apk cho Android.');
        e.target.value = '';
        setSelectedFile(null);
        return;
      }
      if (platform === 'IOS' && !lowerName.endsWith('.ipa')) {
        showToast('Tệp đã chọn không hợp lệ! Vui lòng chọn tệp có đuôi .ipa cho iOS.');
        e.target.value = '';
        setSelectedFile(null);
        return;
      }
      setSelectedFile(file);
    } else {
      setSelectedFile(null);
    }
  };

  // Submit new update
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!version.trim()) {
      showToast('Vui lòng nhập số phiên bản.');
      return;
    }
    if (!changelog.trim()) {
      showToast('Vui lòng nhập chi tiết cập nhật.');
      return;
    }
    if (uploadType === 'url' && !downloadUrl.trim()) {
      showToast('Vui lòng nhập đường dẫn tải xuống.');
      return;
    }
    if (uploadType === 'file' && !selectedFile) {
      showToast(`Vui lòng chọn file cài đặt (.${platform === 'IOS' ? 'ipa' : 'apk'}).`);
      return;
    }

    if (uploadType === 'file' && selectedFile) {
      const lowerName = selectedFile.name.toLowerCase();
      if (platform === 'ANDROID' && !lowerName.endsWith('.apk')) {
        showToast('Chỉ cho phép tệp .apk cho hệ điều hành Android!');
        return;
      }
      if (platform === 'IOS' && !lowerName.endsWith('.ipa')) {
        showToast('Chỉ cho phép tệp .ipa cho hệ điều hành iOS!');
        return;
      }
    }

    const formData = new FormData();
    if (selectedFile) {
      formData.append('file', selectedFile);
    }
    formData.append('platform', platform);
    formData.append('channel', channel);
    formData.append('version', version.trim());
    if (minSupportedVersion.trim()) {
      formData.append('minSupportedVersion', minSupportedVersion.trim());
    }
    formData.append('changelog', changelog.trim());
    formData.append('downloadUrl', downloadUrl.trim());
    formData.append('mandatory', String(mandatory));
    formData.append('status', status);

    setSubmitting(true);
    try {
      const response = await fetch('/api/v1/app-updates', {
        method: 'POST',
        headers: {
          ...getAuthHeaders(),
        },
        body: formData,
      });

      if (response.ok) {
        const platformLabel = platform === 'IOS' ? 'iOS' : 'Android';
        const channelLabel = channel === 'PRODUCTION' ? 'Chính thức' : channel === 'BETA' ? 'Beta' : 'Nội bộ';
        showToast(
          status === 'RELEASED'
            ? `Đã tạo và phát hành bản cập nhật ${platformLabel} [${channelLabel}] v${version.trim()} thành công!`
            : `Đã lưu bản nháp cập nhật ${platformLabel} [${channelLabel}] v${version.trim()} thành công!`
        );
        setShowModal(false);
        resetForm();
        fetchUpdates();
      } else {
        let errorMessage = 'Lỗi khi tạo bản cập nhật.';
        try {
          const contentType = response.headers.get('content-type');
          if (contentType && contentType.includes('application/json')) {
            const errResult = await response.json();
            errorMessage = errResult?.message || errorMessage;
          } else {
            if (response.status === 413) {
              errorMessage = 'Dung lượng file tải lên vượt quá giới hạn cho phép (tối đa 500MB).';
            } else if (response.status === 403) {
              errorMessage = 'Bạn không có quyền tạo bản cập nhật (yêu cầu quyền Admin).';
            } else if (response.status === 401) {
              errorMessage = 'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.';
            } else {
              errorMessage = `Lỗi từ máy chủ (HTTP ${response.status}).`;
            }
          }
        } catch (e) {
          console.warn('Lỗi khi đọc phản hồi từ máy chủ:', e);
        }
        showToast(errorMessage);
      }
    } catch (error) {
      console.error('Error creating update:', error);
      showToast('Lỗi kết nối khi gửi yêu cầu.');
    } finally {
      setSubmitting(false);
    }
  };

  // Release a draft update
  const handleRelease = async (id: string, versionStr: string, itemPlatform: string, itemChannel: string = 'PRODUCTION') => {
    const platformLabel = itemPlatform === 'IOS' ? 'iOS' : 'Android';
    const channelLabel = itemChannel === 'PRODUCTION' ? 'Chính thức' : itemChannel === 'BETA' ? 'Beta' : 'Nội bộ';
    if (!window.confirm(`Bạn có chắc chắn muốn phát hành bản cập nhật ${platformLabel} [${channelLabel}] v${versionStr}?\nHành động này sẽ gửi thông báo đẩy tới các thiết bị phù hợp.`)) {
      return;
    }

    setReleasingId(id);
    try {
      const response = await fetch(`/api/v1/app-updates/${id}/release`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast(`Phát hành bản cập nhật ${platformLabel} [${channelLabel}] v${versionStr} thành công!`);
        fetchUpdates();
      } else {
        let errorMessage = 'Có lỗi xảy ra khi phát hành cập nhật.';
        try {
          const contentType = response.headers.get('content-type');
          if (contentType && contentType.includes('application/json')) {
            const errResult = await response.json();
            errorMessage = errResult?.message || errorMessage;
          } else if (response.status === 403) {
            errorMessage = 'Bạn không có quyền phát hành bản cập nhật (yêu cầu quyền Admin).';
          }
        } catch (e) {
          // ignore
        }
        showToast(errorMessage);
      }
    } catch (error) {
      console.error('Error releasing update:', error);
      showToast('Lỗi kết nối khi phát hành cập nhật.');
    } finally {
      setReleasingId(null);
    }
  };

  // Rollback a released update
  const handleRollback = async (id: string, versionStr: string, itemPlatform: string, itemChannel: string = 'PRODUCTION') => {
    const platformLabel = itemPlatform === 'IOS' ? 'iOS' : 'Android';
    const channelLabel = itemChannel === 'PRODUCTION' ? 'Chính thức' : itemChannel === 'BETA' ? 'Beta' : 'Nội bộ';
    if (!window.confirm(`XÁC NHẬN THU HỒI PHÁT HÀNH:\nBạn có chắc chắn muốn thu hồi bản cập nhật ${platformLabel} [${channelLabel}] v${versionStr}?\nSau khi thu hồi, client ứng dụng sẽ không còn nhận được bản cập nhật này nữa (hệ thống sẽ rollback về bản hợp lệ trước đó).`)) {
      return;
    }

    setRollingBackId(id);
    try {
      const response = await fetch(`/api/v1/app-updates/${id}/rollback`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast(`Đã thu hồi thành công bản phát hành ${platformLabel} [${channelLabel}] v${versionStr}!`);
        fetchUpdates();
      } else {
        let errorMessage = 'Có lỗi xảy ra khi thu hồi bản cập nhật.';
        try {
          const contentType = response.headers.get('content-type');
          if (contentType && contentType.includes('application/json')) {
            const errResult = await response.json();
            errorMessage = errResult?.message || errorMessage;
          } else if (response.status === 403) {
            errorMessage = 'Bạn không có quyền thu hồi bản cập nhật.';
          }
        } catch (e) {
          // ignore
        }
        showToast(errorMessage);
      }
    } catch (error) {
      console.error('Error rolling back update:', error);
      showToast('Lỗi kết nối khi thu hồi cập nhật.');
    } finally {
      setRollingBackId(null);
    }
  };

  // Delete an update
  const handleDelete = async (id: string, versionStr: string, itemPlatform: string) => {
    const platformLabel = itemPlatform === 'IOS' ? 'iOS' : 'Android';
    if (!window.confirm(`Bạn có chắc chắn muốn xóa bản cập nhật ${platformLabel} v${versionStr}?\nHành động này không thể hoàn tác.`)) {
      return;
    }

    setDeletingId(id);
    try {
      const response = await fetch(`/api/v1/app-updates/${id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast(`Đã xóa bản cập nhật ${platformLabel} v${versionStr} thành công!`);
        fetchUpdates();
      } else {
        let errorMessage = 'Có lỗi xảy ra khi xóa bản cập nhật.';
        try {
          const contentType = response.headers.get('content-type');
          if (contentType && contentType.includes('application/json')) {
            const errResult = await response.json();
            errorMessage = errResult?.message || errorMessage;
          } else if (response.status === 403) {
            errorMessage = 'Bạn không có quyền xóa bản cập nhật (yêu cầu quyền Admin).';
          }
        } catch (e) {
          // ignore
        }
        showToast(errorMessage);
      }
    } catch (error) {
      console.error('Error deleting update:', error);
      showToast('Lỗi kết nối khi xóa bản cập nhật.');
    } finally {
      setDeletingId(null);
    }
  };

  const resetForm = () => {
    setPlatform('ANDROID');
    setChannel('PRODUCTION');
    setVersion('');
    setMinSupportedVersion('');
    setChangelog('');
    setDownloadUrl('');
    setMandatory(false);
    setStatus('DRAFT');
    setUploadType('file');
    setSelectedFile(null);
  };

  const openCreateModal = (targetPlatform?: 'ANDROID' | 'IOS') => {
    resetForm();
    if (targetPlatform) {
      setPlatform(targetPlatform);
    } else if (selectedPlatformFilter !== 'ALL') {
      setPlatform(selectedPlatformFilter);
    }
    if (selectedChannelFilter !== 'ALL') {
      setChannel(selectedChannelFilter);
    }
    setShowModal(true);
  };

  // Stats calculation
  const latestAndroidRelease = updates.find(u => (u.platform || 'ANDROID') === 'ANDROID' && u.status === 'RELEASED' && (u.channel || 'PRODUCTION') === 'PRODUCTION')?.version || 'Chưa có';
  const latestIosRelease = updates.find(u => u.platform === 'IOS' && u.status === 'RELEASED' && (u.channel || 'PRODUCTION') === 'PRODUCTION')?.version || 'Chưa có';
  const totalReleases = updates.filter(u => u.status === 'RELEASED').length;
  const totalDrafts = updates.filter(u => u.status === 'DRAFT').length;

  const androidCount = updates.filter(u => (u.platform || 'ANDROID') === 'ANDROID').length;
  const iosCount = updates.filter(u => u.platform === 'IOS').length;

  // Filtered list
  const filteredUpdates = useMemo(() => {
    return updates.filter(u => {
      if (selectedPlatformFilter !== 'ALL') {
        const itemPlatform = u.platform || 'ANDROID';
        if (itemPlatform !== selectedPlatformFilter) return false;
      }
      if (selectedChannelFilter !== 'ALL') {
        const itemChannel = u.channel || 'PRODUCTION';
        if (itemChannel !== selectedChannelFilter) return false;
      }
      return true;
    });
  }, [updates, selectedPlatformFilter, selectedChannelFilter]);

  // Phân trang danh sách bản cập nhật (10 bản/trang)
  const totalItems = filteredUpdates.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const paginatedUpdates = useMemo(() => {
    const start = (currentPage - 1) * pageSize;
    return filteredUpdates.slice(start, start + pageSize);
  }, [filteredUpdates, currentPage, pageSize]);

  const getPageNumbers = () => {
    const pages: number[] = [];
    if (totalPages <= 5) {
      for (let i = 1; i <= totalPages; i++) pages.push(i);
    } else {
      pages.push(1);
      if (currentPage > 3) pages.push(-1);
      const start = Math.max(2, currentPage - 1);
      const end = Math.min(totalPages - 1, currentPage + 1);
      for (let i = start; i <= end; i++) {
        if (!pages.includes(i)) pages.push(i);
      }
      if (currentPage < totalPages - 2) pages.push(-1);
      if (!pages.includes(totalPages)) pages.push(totalPages);
    }
    return pages;
  };

  const renderChannelBadge = (ch?: string | null) => {
    const itemChannel = ch || 'PRODUCTION';
    if (itemChannel === 'BETA') {
      return <span className="channel-badge badge-channel-beta" title="Kênh thử nghiệm Beta">Beta</span>;
    }
    if (itemChannel === 'INTERNAL') {
      return <span className="channel-badge badge-channel-internal" title="Kênh phát hành nội bộ / QA">Internal</span>;
    }
    return <span className="channel-badge badge-channel-prod" title="Kênh chính thức Production">Production</span>;
  };

  return (
    <div className="update-container">
      {/* Stats Summary Panel */}
      <div className="update-stats-grid">
        <div className="update-stat-card">
          <div className="update-stat-icon android-stat">
            <AndroidIcon size={26} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Android Production</span>
            <span className="update-stat-value">{latestAndroidRelease !== 'Chưa có' ? `v${latestAndroidRelease}` : 'Chưa có'}</span>
          </div>
        </div>

        <div className="update-stat-card">
          <div className="update-stat-icon ios-stat">
            <AppleIcon size={26} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">iOS Production</span>
            <span className="update-stat-value">{latestIosRelease !== 'Chưa có' ? `v${latestIosRelease}` : 'Chưa có'}</span>
          </div>
        </div>

        <div className="update-stat-card">
          <div className="update-stat-icon published">
            <Rocket size={24} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Đang phát hành</span>
            <span className="update-stat-value">{totalReleases} bản</span>
          </div>
        </div>

        <div className="update-stat-card">
          <div className="update-stat-icon drafts">
            <FileText size={24} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Bản nháp lưu trữ</span>
            <span className="update-stat-value">{totalDrafts} bản</span>
          </div>
        </div>
      </div>

      {/* Control & Search Bar */}
      <div className="update-control-bar">
        <div className="update-control-title">
          <h2>Quản lý Cập nhật Ứng dụng (OTA & Channels)</h2>
          <p>Phân tách kênh phát hành (Production / Beta / Internal), xác thực toàn vẹn mã SHA-256 và hỗ trợ thu hồi bản lỗi.</p>
        </div>
        <div className="update-search-actions">
          {canAction('APP_UPDATE_UPLOAD') && (
            <button className="update-add-btn" onClick={() => openCreateModal()}>
              <Plus size={18} />
              Tạo bản cập nhật mới
            </button>
          )}
        </div>
      </div>

      {/* Filter Bar with Platform and Channel Selectors */}
      <div className="update-filter-bar">
        <div className="update-filter-tabs">
          <button
            className={`platform-tab-btn ${selectedPlatformFilter === 'ALL' ? 'active' : ''}`}
            onClick={() => setSelectedPlatformFilter('ALL')}
          >
            <span>Tất cả nền tảng</span>
            <span className="tab-count">{updates.length}</span>
          </button>
          <button
            className={`platform-tab-btn btn-tab-android ${selectedPlatformFilter === 'ANDROID' ? 'active' : ''}`}
            onClick={() => setSelectedPlatformFilter('ANDROID')}
          >
            <AndroidIcon size={16} />
            <span>Android (APK)</span>
            <span className="tab-count">{androidCount}</span>
          </button>
          <button
            className={`platform-tab-btn btn-tab-ios ${selectedPlatformFilter === 'IOS' ? 'active' : ''}`}
            onClick={() => setSelectedPlatformFilter('IOS')}
          >
            <AppleIcon size={16} />
            <span>iOS (IPA / App Store)</span>
            <span className="tab-count">{iosCount}</span>
          </button>
        </div>

        {/* Channel Filter Selector */}
        <div className="update-channel-filter">
          <Filter size={14} className="channel-filter-icon" />
          <span className="channel-filter-label">Kênh:</span>
          <select
            value={selectedChannelFilter}
            onChange={(e) => setSelectedChannelFilter(e.target.value as any)}
            className="channel-filter-select"
          >
            <option value="ALL">Tất cả kênh phát hành</option>
            <option value="PRODUCTION">Chính thức (Production)</option>
            <option value="BETA">Thử nghiệm (Beta)</option>
            <option value="INTERNAL">Nội bộ (Internal)</option>
          </select>
        </div>
      </div>

      {/* Updates History List */}
      {loading || refreshing ? (
        <div className="update-loading">
          <Loader2 size={32} className="spin loading-icon" />
          <p>{refreshing ? 'Đang làm mới dữ liệu...' : 'Đang tải lịch sử phiên bản cập nhật...'}</p>
        </div>
      ) : filteredUpdates.length === 0 ? (
        <div className="update-empty-state">
          <FileText size={48} className="empty-icon" />
          <h3>Chưa có bản cập nhật nào phù hợp với bộ lọc</h3>
          <p>Hãy tạo bản cập nhật đầu tiên để quản lý phiên bản cho hệ điều hành và kênh này.</p>
          {canAction('APP_UPDATE_UPLOAD') && (
            <button
              className="update-add-btn inline-btn"
              onClick={() => openCreateModal(selectedPlatformFilter !== 'ALL' ? selectedPlatformFilter : undefined)}
            >
              <Plus size={16} /> Tạo bản cập nhật mới
            </button>
          )}
        </div>
      ) : (
        <div className="update-list-wrapper">
          {/* Desktop Table View (>= 768px) */}
          <div className="update-desktop-table-view">
            <table className="update-table">
              <thead>
                <tr>
                  <th className="th-platform">Nền tảng</th>
                  <th className="th-channel">Kênh</th>
                  <th className="th-version">Phiên bản</th>
                  <th className="th-changelog">Chi tiết cập nhật</th>
                  <th className="th-integrity">Tệp & Toàn vẹn</th>
                  <th className="th-mandatory">Bắt buộc</th>
                  <th className="th-status">Trạng thái</th>
                  <th className="th-time">Thời gian</th>
                  <th className="th-actions">Thao tác</th>
                </tr>
              </thead>
              <tbody>
                {paginatedUpdates.map((update) => {
                  const itemPlatform = update.platform || 'ANDROID';
                  const isIos = itemPlatform === 'IOS';
                  const itemChannel = update.channel || 'PRODUCTION';

                  let rowClass = 'row-draft';
                  if (update.status === 'RELEASED') rowClass = 'row-released';
                  else if (update.status === 'ROLLED_BACK') rowClass = 'row-rolledback';

                  return (
                    <tr key={update.id} className={rowClass}>
                      <td className="col-platform">
                        {isIos ? (
                          <span className="platform-badge platform-ios" title="Dành cho iOS (Apple)">
                            <AppleIcon size={14} />
                            <span>iOS</span>
                          </span>
                        ) : (
                          <span className="platform-badge platform-android" title="Dành cho Android">
                            <AndroidIcon size={14} />
                            <span>Android</span>
                          </span>
                        )}
                      </td>
                      <td className="col-channel">
                        {renderChannelBadge(update.channel)}
                      </td>
                      <td className="col-version">
                        <span className="version-tag">v{update.version}</span>
                      </td>
                      <td className="col-changelog">
                        <div className="changelog-text" title={update.changelog}>
                          {update.changelog.split('\n').map((line, i) => (
                            <div key={i}>{line}</div>
                          ))}
                        </div>
                      </td>
                      <td className="col-integrity">
                        <div className="integrity-container">
                          {/* URL và nút tải / copy */}
                          <div className="url-container">
                            <span className="url-text" title={update.downloadUrl}>
                              {update.downloadUrl}
                            </span>
                            <div className="url-actions">
                              <button
                                className="icon-action-btn"
                                onClick={() => handleCopyLink(update.downloadUrl)}
                                title="Sao chép liên kết tải"
                              >
                                <Copy size={13} />
                              </button>
                              {update.status === 'RELEASED' && (
                                <a
                                  href={update.downloadUrl}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="icon-action-btn"
                                  title="Mở liên kết trực tiếp"
                                >
                                  <ExternalLink size={13} />
                                </a>
                              )}
                            </div>
                          </div>

                          {/* File size & SHA-256 Checksum */}
                          <div className="integrity-meta-row">
                            <div className="file-size-tag" title="Kích thước tệp cài đặt">
                              <HardDrive size={11} />
                              <span>{formatFileSize(update.fileSize)}</span>
                            </div>
                            {update.sha256 ? (
                              <div className="sha256-container" title={`Mã kiểm tra SHA-256: ${update.sha256}`}>
                                <Hash size={11} />
                                <span className="sha256-code">{formatSha256(update.sha256)}</span>
                                <button
                                  type="button"
                                  className="sha256-copy-btn"
                                  onClick={() => handleCopySha256(update.sha256!)}
                                  title="Sao chép toàn bộ mã SHA-256"
                                >
                                  <Copy size={10} />
                                </button>
                              </div>
                            ) : (
                              <span className="no-sha-text">Chưa băm mã</span>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="col-mandatory">
                        {update.mandatory ? (
                          <span className="badge badge-danger" title="Bắt buộc nâng cấp ngay lập tức">
                            <ShieldAlert size={12} style={{ marginRight: '4px' }} />
                            Bắt buộc
                          </span>
                        ) : update.minSupportedVersion ? (
                          <div className="min-supported-box" title={`Ép cập nhật nếu bản hiện tại < v${update.minSupportedVersion}`}>
                            <span className="badge badge-secondary">Tùy chọn</span>
                            <span className="min-version-tag">≥ v{update.minSupportedVersion}</span>
                          </div>
                        ) : (
                          <span className="badge badge-secondary">Tùy chọn</span>
                        )}
                      </td>
                      <td className="col-status">
                        {update.status === 'RELEASED' ? (
                          <span className="badge badge-success">Đã phát hành</span>
                        ) : update.status === 'ROLLED_BACK' ? (
                          <span className="badge badge-danger" title="Bản phát hành này đã bị thu hồi">Đã thu hồi</span>
                        ) : (
                          <span className="badge badge-warning">Bản nháp</span>
                        )}
                      </td>
                      <td className="col-time">
                        <div className="time-info">
                          <div className="time-row" title="Ngày tạo">
                            <Clock size={12} className="time-icon" />
                            <span>Tạo: {new Date(update.createdAt).toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' })}</span>
                          </div>
                          {update.releasedAt && (
                            <div className="time-row highlight" title="Ngày phát hành">
                              <Rocket size={12} className="time-icon" />
                              <span>Phát hành: {new Date(update.releasedAt).toLocaleString('vi-VN', { dateStyle: 'short', timeStyle: 'short' })}</span>
                            </div>
                          )}
                        </div>
                      </td>
                      <td className="col-actions">
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          {update.status === 'DRAFT' && canAction('APP_UPDATE_RELEASE') && (
                            <button
                              className="action-btn release-btn"
                              onClick={() => handleRelease(update.id, update.version, itemPlatform, itemChannel)}
                              disabled={releasingId === update.id || deletingId === update.id || rollingBackId === update.id}
                              title="Phát hành bản cập nhật này"
                            >
                              {releasingId === update.id ? (
                                <Loader2 size={14} className="spin" />
                              ) : (
                                <Rocket size={14} />
                              )}
                              <span>Phát hành</span>
                            </button>
                          )}

                          {update.status === 'RELEASED' && (
                            <>
                              <span className="action-done" title="Bản cập nhật đang phục vụ client">
                                <CheckCircle2 size={16} className="text-success" />
                                <span>Đang chạy</span>
                              </span>
                              {canAction('APP_UPDATE_RELEASE') && (
                                <button
                                  className="action-btn rollback-btn"
                                  onClick={() => handleRollback(update.id, update.version, itemPlatform, itemChannel)}
                                  disabled={rollingBackId === update.id || deletingId === update.id}
                                  title="Thu hồi bản phát hành nếu phát hiện sự cố khẩn cấp"
                                >
                                  {rollingBackId === update.id ? (
                                    <Loader2 size={13} className="spin" />
                                  ) : (
                                    <RotateCcw size={13} />
                                  )}
                                  <span>Thu hồi</span>
                                </button>
                              )}
                            </>
                          )}

                          {update.status === 'ROLLED_BACK' && (
                            <span className="action-rolledback-label" title="Phiên bản này đã bị dừng phân phối">
                              <ShieldAlert size={14} style={{ color: '#ef4444' }} />
                              <span>Đã thu hồi</span>
                            </span>
                          )}

                          {canAction('APP_UPDATE_DELETE') && (
                            <button
                              className="icon-action-btn delete-action-btn"
                              onClick={() => handleDelete(update.id, update.version, itemPlatform)}
                              disabled={deletingId === update.id || releasingId === update.id || rollingBackId === update.id}
                              title="Xóa bản cập nhật"
                              style={{ color: '#ef4444' }}
                            >
                              {deletingId === update.id ? (
                                <Loader2 size={14} className="spin" />
                              ) : (
                                <Trash2 size={14} />
                              )}
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {/* Mobile Card Timeline View (< 768px) */}
          <div className="update-mobile-timeline-view">
            {paginatedUpdates.map((update) => {
              const itemPlatform = update.platform || 'ANDROID';
              const isIos = itemPlatform === 'IOS';
              const itemChannel = update.channel || 'PRODUCTION';
              const isChangelogExpanded = !!expandedChangelogs[update.id];
              const hasLongChangelog = update.changelog.length > 70 || update.changelog.includes('\n');
              const releaseDateStr = update.releasedAt
                ? new Date(update.releasedAt).toLocaleDateString('vi-VN')
                : new Date(update.createdAt).toLocaleDateString('vi-VN');

              let cardStatusClass = 'draft';
              if (update.status === 'RELEASED') cardStatusClass = 'released';
              else if (update.status === 'ROLLED_BACK') cardStatusClass = 'rolledback';

              return (
                <div key={update.id} className={`update-timeline-card ${cardStatusClass}`}>
                  <div className="timeline-node">
                    <div className={`timeline-dot ${cardStatusClass}`} />
                    <div className="timeline-stem" />
                  </div>

                  <div className="update-card-content">
                    {/* Card Header: Platform + Version + Channel + Status */}
                    <div className="update-card-header">
                      <div className="update-card-header-left">
                        {isIos ? (
                          <span className="platform-badge platform-ios">
                            <AppleIcon size={14} />
                            <span>iOS</span>
                          </span>
                        ) : (
                          <span className="platform-badge platform-android">
                            <AndroidIcon size={14} />
                            <span>Android</span>
                          </span>
                        )}
                        <span className="version-tag">v{update.version}</span>
                        {renderChannelBadge(update.channel)}
                      </div>

                      <div className="update-card-header-right">
                        {update.mandatory ? (
                          <span className="badge badge-danger">
                            <ShieldAlert size={11} style={{ marginRight: '3px' }} />
                            Bắt buộc
                          </span>
                        ) : update.minSupportedVersion ? (
                          <span className="badge badge-secondary" title={`Phiên bản tối thiểu >= v${update.minSupportedVersion}`}>
                            ≥ v{update.minSupportedVersion}
                          </span>
                        ) : (
                          <span className="badge badge-secondary">Tùy chọn</span>
                        )}

                        {update.status === 'RELEASED' ? (
                          <span className="badge badge-success">Đã phát hành</span>
                        ) : update.status === 'ROLLED_BACK' ? (
                          <span className="badge badge-danger">Đã thu hồi</span>
                        ) : (
                          <span className="badge badge-warning">Bản nháp</span>
                        )}
                      </div>
                    </div>

                    {/* File & SHA-256 Info */}
                    <div className="update-card-integrity-row">
                      <span className="card-size-info">
                        <HardDrive size={12} /> {formatFileSize(update.fileSize)}
                      </span>
                      {update.sha256 && (
                        <span className="card-sha-info" onClick={() => handleCopySha256(update.sha256!)} title="Nhấn để chép SHA-256">
                          <Hash size={12} /> {formatSha256(update.sha256)}
                        </span>
                      )}
                    </div>

                    {/* Changelog */}
                    <div className="update-card-body">
                      <div className={`update-card-changelog ${isChangelogExpanded ? 'expanded' : 'clamped'}`}>
                        {update.changelog}
                      </div>
                      {hasLongChangelog && (
                        <button
                          type="button"
                          className="btn-toggle-changelog"
                          onClick={() => toggleChangelog(update.id)}
                        >
                          {isChangelogExpanded ? 'Thu gọn ▲' : 'Xem thêm ▼'}
                        </button>
                      )}
                    </div>

                    {/* Footer Actions */}
                    <div className="update-card-footer">
                      <div className="update-card-date">
                        <Clock size={13} />
                        <span>{update.releasedAt ? `Phát hành: ${releaseDateStr}` : `Tạo: ${releaseDateStr}`}</span>
                      </div>

                      <div className="update-card-actions">
                        <button
                          type="button"
                          className="card-action-btn copy-btn"
                          onClick={() => handleCopyLink(update.downloadUrl)}
                          title="Sao chép link tải"
                        >
                          <Copy size={13} />
                          <span>Sao chép link</span>
                        </button>

                        {update.status === 'RELEASED' && (
                          <a
                            href={update.downloadUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="card-action-btn download-btn"
                            title="Tải file / Mở liên kết"
                          >
                            <ExternalLink size={13} />
                            <span>Tải file</span>
                          </a>
                        )}

                        {update.status === 'DRAFT' && canAction('APP_UPDATE_RELEASE') && (
                          <button
                            type="button"
                            className="card-action-btn release-btn"
                            onClick={() => handleRelease(update.id, update.version, itemPlatform, itemChannel)}
                            disabled={releasingId === update.id || deletingId === update.id || rollingBackId === update.id}
                          >
                            {releasingId === update.id ? (
                              <Loader2 size={13} className="spin" />
                            ) : (
                              <Rocket size={13} />
                            )}
                            <span>Phát hành</span>
                          </button>
                        )}

                        {update.status === 'RELEASED' && canAction('APP_UPDATE_RELEASE') && (
                          <button
                            type="button"
                            className="card-action-btn rollback-btn"
                            onClick={() => handleRollback(update.id, update.version, itemPlatform, itemChannel)}
                            disabled={rollingBackId === update.id || deletingId === update.id}
                            title="Thu hồi bản phát hành"
                          >
                            {rollingBackId === update.id ? (
                              <Loader2 size={13} className="spin" />
                            ) : (
                              <RotateCcw size={13} />
                            )}
                            <span>Thu hồi</span>
                          </button>
                        )}

                        {canAction('APP_UPDATE_DELETE') && (
                          <button
                            type="button"
                            className="card-action-btn delete-btn"
                            onClick={() => handleDelete(update.id, update.version, itemPlatform)}
                            disabled={releasingId === update.id || deletingId === update.id || rollingBackId === update.id}
                            title="Xóa bản cập nhật"
                          >
                            {deletingId === update.id ? (
                              <Loader2 size={13} className="spin" />
                            ) : (
                              <Trash2 size={13} />
                            )}
                          </button>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Phân trang danh sách (Pagination) */}
          {totalItems > 0 && (
            <div className="update-pagination">
              <div className="pagination-info">
                <span>
                  Hiển thị <strong>{Math.min((currentPage - 1) * pageSize + 1, totalItems)}</strong> -{' '}
                  <strong>{Math.min(currentPage * pageSize, totalItems)}</strong> trên tổng số{' '}
                  <strong>{totalItems}</strong> bản cập nhật
                </span>
                <div className="page-size-selector">
                  <label htmlFor="update-page-size">Mỗi trang:</label>
                  <select
                    id="update-page-size"
                    value={pageSize}
                    onChange={(e) => {
                      setPageSize(Number(e.target.value));
                      setCurrentPage(1);
                    }}
                  >
                    <option value={10}>10</option>
                    <option value={20}>20</option>
                    <option value={30}>30</option>
                  </select>
                </div>
              </div>

              {totalPages > 1 && (
                <div className="pagination-controls">
                  <button
                    type="button"
                    className="page-btn nav-btn"
                    onClick={() => setCurrentPage(1)}
                    disabled={currentPage === 1}
                    title="Trang đầu"
                    aria-label="Trang đầu"
                  >
                    <ChevronsLeft size={16} />
                  </button>
                  <button
                    type="button"
                    className="page-btn nav-btn"
                    onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                    title="Trang trước"
                    aria-label="Trang trước"
                  >
                    <ChevronLeft size={16} />
                  </button>

                  {getPageNumbers().map((p, idx) =>
                    p === -1 ? (
                      <span key={`ellipsis-${idx}`} className="page-ellipsis">
                        ...
                      </span>
                    ) : (
                      <button
                        key={p}
                        type="button"
                        className={`page-btn number-btn ${currentPage === p ? 'active' : ''}`}
                        onClick={() => setCurrentPage(p)}
                      >
                        {p}
                      </button>
                    )
                  )}

                  <button
                    type="button"
                    className="page-btn nav-btn"
                    onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages}
                    title="Trang sau"
                    aria-label="Trang sau"
                  >
                    <ChevronRight size={16} />
                  </button>
                  <button
                    type="button"
                    className="page-btn nav-btn"
                    onClick={() => setCurrentPage(totalPages)}
                    disabled={currentPage === totalPages}
                    title="Trang cuối"
                    aria-label="Trang cuối"
                  >
                    <ChevronsRight size={16} />
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Creation Modal Dialog */}
      {showModal && (
        <div className="update-modal-overlay">
          <div className="update-modal-box">
            <div className="update-modal-header">
              <h3>Tạo Bản cập nhật Ứng dụng mới</h3>
              <button className="close-modal-btn" onClick={() => setShowModal(false)} disabled={submitting}>
                &times;
              </button>
            </div>
            {canAction('APP_UPDATE_UPLOAD') && (
              <form onSubmit={handleSubmit} className="update-modal-form">
                {/* Target Platform Selector */}
                <div className="form-group">
                  <label>Hệ điều hành mục tiêu (OS)*</label>
                  <div className="platform-selector-grid">
                    <div
                      className={`platform-select-card card-android ${platform === 'ANDROID' ? 'selected' : ''}`}
                      onClick={() => !submitting && handlePlatformChange('ANDROID')}
                    >
                      <div className="platform-card-header">
                        <div className="platform-card-icon icon-android">
                          <AndroidIcon size={22} />
                        </div>
                        <div className="platform-card-title">
                          <strong>Android</strong>
                          <span className="file-hint">Tệp cài đặt .apk</span>
                        </div>
                      </div>
                      <div className="platform-card-desc">
                        Tải lên tệp APK kèm kiểm tra mã băm SHA-256 toàn vẹn chống lỗi cài đặt.
                      </div>
                    </div>

                    <div
                      className={`platform-select-card card-ios ${platform === 'IOS' ? 'selected' : ''}`}
                      onClick={() => !submitting && handlePlatformChange('IOS')}
                    >
                      <div className="platform-card-header">
                        <div className="platform-card-icon icon-ios">
                          <AppleIcon size={22} />
                        </div>
                        <div className="platform-card-title">
                          <strong>iOS</strong>
                          <span className="file-hint">Tệp .ipa / App Store</span>
                        </div>
                      </div>
                      <div className="platform-card-desc">
                        Liên kết App Store, TestFlight hoặc tệp IPA ad-hoc nội bộ cho iOS.
                      </div>
                    </div>
                  </div>
                </div>

                {/* Release Channel Selector */}
                <div className="form-group">
                  <label htmlFor="input-channel">Kênh phát hành (Release Channel)*</label>
                  <select
                    id="input-channel"
                    value={channel}
                    onChange={(e) => setChannel(e.target.value as any)}
                    disabled={submitting}
                  >
                    <option value="PRODUCTION">Chính thức (PRODUCTION) - Cập nhật cho toàn thể nhân viên</option>
                    <option value="BETA">Thử nghiệm (BETA) - Dành cho nhóm trải nghiệm sớm</option>
                    <option value="INTERNAL">Nội bộ (INTERNAL) - Dành riêng cho nhóm kỹ thuật kiểm thử</option>
                  </select>
                </div>

                {/* Version Inputs Grid */}
                <div className="form-row-grid">
                  <div className="form-group">
                    <label htmlFor="input-version">Số phiên bản mới (Version)*</label>
                    <input
                      id="input-version"
                      type="text"
                      placeholder={platform === 'IOS' ? 'Ví dụ: 1.1.6 hoặc 1.2.0' : 'Ví dụ: 1.1.7'}
                      value={version}
                      onChange={(e) => handleVersionChange(e.target.value)}
                      disabled={submitting}
                      required
                    />
                  </div>

                  <div className="form-group">
                    <label htmlFor="input-min-version">
                      Phiên bản tối thiểu bắt buộc (Tùy chọn)
                    </label>
                    <input
                      id="input-min-version"
                      type="text"
                      placeholder="Ví dụ: 1.0.0 (Nếu máy client < bản này sẽ bị ép cập nhật)"
                      value={minSupportedVersion}
                      onChange={(e) => setMinSupportedVersion(e.target.value)}
                      disabled={submitting}
                    />
                  </div>
                </div>

                {/* Upload Type Switch */}
                <div className="form-group">
                  <label>Phương thức cung cấp tệp cài đặt*</label>
                  <div style={{ display: 'flex', gap: '20px', margin: '4px 0 8px 0', flexWrap: 'wrap' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.9rem', cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="uploadType"
                        checked={uploadType === 'file'}
                        onChange={() => handleUploadTypeChange('file')}
                        disabled={submitting}
                      />
                      <span>{platform === 'IOS' ? 'Tải lên tệp IPA (.ipa)' : 'Tải lên tệp APK (.apk) (Tự động băm SHA-256)'}</span>
                    </label>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.9rem', cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="uploadType"
                        checked={uploadType === 'url'}
                        onChange={() => handleUploadTypeChange('url')}
                        disabled={submitting}
                      />
                      <span>{platform === 'IOS' ? 'Đường dẫn liên kết (App Store / TestFlight URL)' : 'Đường dẫn tải xuống trực tiếp (URL)'}</span>
                    </label>
                  </div>
                </div>

                {uploadType === 'file' ? (
                  <div className="form-group">
                    <label htmlFor="input-file">Chọn tệp cài đặt ({platform === 'IOS' ? '.ipa' : '.apk'})*</label>
                    <input
                      id="input-file"
                      type="file"
                      accept={platform === 'IOS' ? '.ipa' : '.apk'}
                      onChange={handleFileChange}
                      disabled={submitting}
                      required={uploadType === 'file'}
                    />
                    <span className="input-helper-text">
                      {platform === 'IOS'
                        ? 'Lưu ý: Chỉ chấp nhận định dạng .ipa dành cho iOS. Hệ thống tự động tính dung lượng và mã băm SHA-256.'
                        : 'Lưu ý: Chỉ chấp nhận định dạng .apk dành cho Android. Hệ thống tự động tính dung lượng và mã băm SHA-256.'}
                    </span>
                  </div>
                ) : (
                  <div className="form-group">
                    <label htmlFor="input-url">
                      {platform === 'IOS' ? 'Đường dẫn App Store hoặc Link tải iOS (Download URL)*' : 'Đường dẫn tải tệp APK (Download URL)*'}
                    </label>
                    <input
                      id="input-url"
                      type="text"
                      placeholder={platform === 'IOS' ? 'https://apps.apple.com/us/app/inverter-like-new-system/id6809314317' : 'Nhập đường dẫn URL tải file APK'}
                      value={downloadUrl}
                      onChange={(e) => setDownloadUrl(e.target.value)}
                      disabled={submitting}
                      required={uploadType === 'url'}
                    />
                  </div>
                )}

                {platform === 'IOS' && uploadType === 'url' && (
                  <div className="ios-guidance-note">
                    <AlertCircle size={16} className="ios-guidance-icon" />
                    <span>
                      <strong>Gợi ý cho iOS:</strong> Nếu đã xuất bản lên App Store, hãy dán liên kết <code>https://apps.apple.com/...</code>. Khi người dùng bấm Cập nhật trên iOS, máy sẽ tự động chuyển tiếp mở ứng dụng trong App Store.
                    </span>
                  </div>
                )}

                <div className="form-group">
                  <label htmlFor="input-changelog">Chi tiết cập nhật (Changelog)*</label>
                  <textarea
                    id="input-changelog"
                    rows={4}
                    placeholder={`Ghi nhận các cải tiến và sửa lỗi trong phiên bản này&#10;- Sửa lỗi giao diện ${platform === 'IOS' ? 'trên iOS' : 'trên Android'}&#10;- Cải thiện hiệu năng và bảo mật hệ thống`}
                    value={changelog}
                    onChange={(e) => setChangelog(e.target.value)}
                    disabled={submitting}
                    required
                  />
                </div>

                <div className="form-row-checkbox">
                  <label className="checkbox-label" htmlFor="input-mandatory">
                    <input
                      id="input-mandatory"
                      type="checkbox"
                      checked={mandatory}
                      onChange={(e) => setMandatory(e.target.checked)}
                      disabled={submitting}
                    />
                    <span className="checkbox-text">
                      <strong>Bắt buộc cập nhật toàn bộ:</strong> Mọi thiết bị chưa lên phiên bản này đều bị chặn sử dụng ứng dụng cho tới khi cập nhật thành công.
                    </span>
                  </label>
                </div>

                <div className="form-group">
                  <label htmlFor="select-status">Hành động khi tạo</label>
                  <select
                    id="select-status"
                    value={status}
                    onChange={(e) => setStatus(e.target.value as 'DRAFT' | 'RELEASED')}
                    disabled={submitting}
                  >
                    <option value="DRAFT">Chỉ lưu Bản nháp (Lưu trữ và phát hành sau)</option>
                    <option value="RELEASED">Phát hành ngay (Đẩy cập nhật tới client trên kênh đã chọn)</option>
                  </select>
                </div>

                {status === 'RELEASED' && (
                  <div className="release-warning">
                    <AlertCircle size={16} className="warning-icon" />
                    <span>
                      <strong>Chú ý:</strong> Bản cập nhật <strong>{platform === 'IOS' ? 'iOS' : 'Android'}</strong> trên kênh <strong>{channel}</strong> sẽ có hiệu lực ngay lập tức.
                    </span>
                  </div>
                )}

                <div className="update-modal-footer">
                  <button
                    type="button"
                    className="btn-cancel"
                    onClick={() => setShowModal(false)}
                    disabled={submitting}
                  >
                    Hủy bỏ
                  </button>
                  {canAction('APP_UPDATE_UPLOAD') && (
                    <button type="submit" className="btn-submit" disabled={submitting}>
                      {submitting ? (
                        <>
                          <Loader2 size={16} className="spin" />
                          <span>Đang xử lý...</span>
                        </>
                      ) : (
                        <span>Xác nhận</span>
                      )}
                    </button>
                  )}
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
};

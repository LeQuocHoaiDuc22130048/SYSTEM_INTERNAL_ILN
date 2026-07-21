import React, { useState, useEffect, useCallback } from 'react';
import { 
  Plus, 
  RefreshCw, 
  Rocket, 
  Copy, 
  ExternalLink, 
  AlertCircle,
  CheckCircle2, 
  FileText,
  Clock,
  ShieldAlert,
  Loader2
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import './UpdateTab.css';

interface AppUpdate {
  id: string;
  version: string;
  changelog: string;
  downloadUrl: string;
  mandatory: boolean;
  status: 'DRAFT' | 'RELEASED';
  releasedAt: string | null;
  createdAt: string;
}

interface UpdateTabProps {
  showToast: (message: string) => void;
}

export const UpdateTab: React.FC<UpdateTabProps> = ({ showToast }) => {
  const [updates, setUpdates] = useState<AppUpdate[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [releasingId, setReleasingId] = useState<string | null>(null);

  // Form states
  const [version, setVersion] = useState('');
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

  // Handle version copy
  const handleCopyLink = (url: string) => {
    // Resolve relative URLs if needed, or copy as-is
    let fullUrl = url;
    if (url.startsWith('/')) {
      fullUrl = window.location.origin + url;
    }
    navigator.clipboard.writeText(fullUrl);
    showToast('Đã sao chép link tải xuống!');
  };

  // Submit new update
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!version.trim()) {
      showToast('Vui lòng nhập phiên bản.');
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
      showToast('Vui lòng chọn file cài đặt (.apk).');
      return;
    }

    const formData = new FormData();
    if (selectedFile) {
      formData.append('file', selectedFile);
    }
    formData.append('version', version.trim());
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
          // Lưu ý: KHÔNG đặt Content-Type để trình duyệt tự động định nghĩa boundary của multipart/form-data
        },
        body: formData,
      });

      if (response.ok) {
        showToast(
          status === 'RELEASED'
            ? 'Đã tạo và phát hành bản cập nhật mới thành công!'
            : 'Đã lưu bản nháp cập nhật thành công!'
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
  const handleRelease = async (id: string, versionStr: string) => {
    if (!window.confirm(`Bạn có chắc chắn muốn phát hành bản cập nhật v${versionStr} hàng loạt?\nHành động này sẽ gửi thông báo đẩy tới toàn bộ thiết bị đang hoạt động.`)) {
      return;
    }

    setReleasingId(id);
    try {
      const response = await fetch(`/api/v1/app-updates/${id}/release`, {
        method: 'POST',
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        showToast(`Phát hành hàng loạt bản cập nhật v${versionStr} thành công!`);
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
          // ignore parsing error
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

  const resetForm = () => {
    setVersion('');
    setChangelog('');
    setDownloadUrl('');
    setMandatory(false);
    setStatus('DRAFT');
    setSelectedFile(null);
  };

  // Fill default download URL when version changes
  const handleVersionChange = (val: string) => {
    setVersion(val);
    if (val.trim()) {
      setDownloadUrl(`/api/v1/app-updates/download/system_internal_v${val.trim()}.apk`);
    } else {
      setDownloadUrl('');
    }
  };

  // Stats calculation
  const latestActiveVersion = updates.find(u => u.status === 'RELEASED')?.version || 'Chưa có';
  const totalReleases = updates.filter(u => u.status === 'RELEASED').length;
  const totalDrafts = updates.filter(u => u.status === 'DRAFT').length;

  return (
    <div className="update-container">
      {/* Stats Summary Panel */}
      <div className="update-stats-grid">
        <div className="update-stat-card">
          <div className="update-stat-icon active-ver">
            <CheckCircle2 size={24} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Phiên bản hiện tại</span>
            <span className="update-stat-value">{latestActiveVersion}</span>
          </div>
        </div>

        <div className="update-stat-card">
          <div className="update-stat-icon published">
            <Rocket size={24} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Đã phát hành</span>
            <span className="update-stat-value">{totalReleases} bản</span>
          </div>
        </div>

        <div className="update-stat-card">
          <div className="update-stat-icon drafts">
            <FileText size={24} />
          </div>
          <div className="update-stat-info">
            <span className="update-stat-label">Bản nháp</span>
            <span className="update-stat-value">{totalDrafts} bản</span>
          </div>
        </div>
      </div>

      {/* Control Actions Panel */}
      <div className="update-control-bar">
        <div className="update-control-title">
          <h2>Lịch sử Cập nhật Ứng dụng</h2>
          <p>Quản lý các bản cập nhật APK cho ứng dụng native và phát hành thông báo hàng loạt.</p>
        </div>
        <div className="update-search-actions">
          <button 
            className="update-refresh-btn" 
            onClick={() => fetchUpdates(true)} 
            disabled={refreshing || loading}
            title="Làm mới dữ liệu"
          >
            <RefreshCw size={16} className={refreshing ? 'spin' : ''} />
          </button>
          <button className="update-add-btn" onClick={() => setShowModal(true)}>
            <Plus size={18} />
            Tạo bản cập nhật
          </button>
        </div>
      </div>

      {/* Updates History List */}
      {loading ? (
        <div className="update-loading">
          <Loader2 size={32} className="spin loading-icon" />
          <p>Đang tải lịch sử phiên bản cập nhật...</p>
        </div>
      ) : updates.length === 0 ? (
        <div className="update-empty-state">
          <FileText size={48} className="empty-icon" />
          <h3>Chưa có bản cập nhật nào</h3>
          <p>Hãy tạo bản cập nhật đầu tiên để quản lý các phiên bản client.</p>
          <button className="update-add-btn inline-btn" onClick={() => setShowModal(true)}>
            <Plus size={16} /> Tạo bản cập nhật mới
          </button>
        </div>
      ) : (
        <div className="update-list-wrapper">
          <table className="update-table">
            <thead>
              <tr>
                <th>Phiên bản</th>
                <th>Chi tiết cập nhật</th>
                <th>Đường dẫn file cài đặt</th>
                <th>Bắt buộc</th>
                <th>Trạng thái</th>
                <th>Thời gian</th>
                <th>Thao tác</th>
              </tr>
            </thead>
            <tbody>
              {updates.map((update) => (
                <tr key={update.id} className={update.status === 'RELEASED' ? 'row-released' : 'row-draft'}>
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
                  <td className="col-url">
                    <div className="url-container">
                      <span className="url-text" title={update.downloadUrl}>
                        {update.downloadUrl}
                      </span>
                      <div className="url-actions">
                        <button 
                          className="icon-action-btn" 
                          onClick={() => handleCopyLink(update.downloadUrl)}
                          title="Sao chép link tải"
                        >
                          <Copy size={13} />
                        </button>
                        {update.status === 'RELEASED' && (
                          <a 
                            href={update.downloadUrl} 
                            target="_blank" 
                            rel="noopener noreferrer" 
                            className="icon-action-btn"
                            title="Tải xuống trực tiếp"
                          >
                            <ExternalLink size={13} />
                          </a>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="col-mandatory">
                    {update.mandatory ? (
                      <span className="badge badge-danger" title="Bắt buộc cập nhật ngay lập tức">
                        <ShieldAlert size={12} style={{ marginRight: '4px' }} />
                        Bắt buộc
                      </span>
                    ) : (
                      <span className="badge badge-secondary">Tùy chọn</span>
                    )}
                  </td>
                  <td className="col-status">
                    {update.status === 'RELEASED' ? (
                      <span className="badge badge-success">Đã phát hành</span>
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
                    {update.status === 'DRAFT' ? (
                      <button
                        className="action-btn release-btn"
                        onClick={() => handleRelease(update.id, update.version)}
                        disabled={releasingId === update.id}
                      >
                        {releasingId === update.id ? (
                          <Loader2 size={14} className="spin" />
                        ) : (
                          <Rocket size={14} />
                        )}
                        <span>Phát hành</span>
                      </button>
                    ) : (
                      <span className="action-done" title="Bản cập nhật đã được áp dụng hàng loạt">
                        <CheckCircle2 size={16} className="text-success" />
                        <span>Hoàn tất</span>
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
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
            <form onSubmit={handleSubmit} className="update-modal-form">
              <div className="form-group">
                <label htmlFor="input-version">Số phiên bản mới (Version)*</label>
                <input
                  id="input-version"
                  type="text"
                  placeholder="Ví dụ: 1.1.4"
                  value={version}
                  onChange={(e) => handleVersionChange(e.target.value)}
                  disabled={submitting}
                  required
                />
              </div>

              <div className="form-group">
                <label>Phương thức cung cấp tệp cài đặt*</label>
                <div style={{ display: 'flex', gap: '16px', margin: '4px 0 8px 0' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.88rem', fontWeight: 'normal', cursor: 'pointer' }}>
                    <input 
                      type="radio" 
                      name="uploadType" 
                      checked={uploadType === 'file'} 
                      onChange={() => setUploadType('file')} 
                      disabled={submitting}
                    />
                    Tải lên tệp APK từ máy tính
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.88rem', fontWeight: 'normal', cursor: 'pointer' }}>
                    <input 
                      type="radio" 
                      name="uploadType" 
                      checked={uploadType === 'url'} 
                      onChange={() => setUploadType('url')} 
                      disabled={submitting}
                    />
                    Đường dẫn tải xuống (URL)
                  </label>
                </div>
              </div>

              {uploadType === 'file' ? (
                <div className="form-group">
                  <label htmlFor="input-file">Chọn tệp cài đặt (.apk)*</label>
                  <input
                    id="input-file"
                    type="file"
                    accept=".apk"
                    onChange={(e) => {
                      if (e.target.files && e.target.files.length > 0) {
                        setSelectedFile(e.target.files[0]);
                      }
                    }}
                    disabled={submitting}
                    required={uploadType === 'file'}
                  />
                </div>
              ) : (
                <div className="form-group">
                  <label htmlFor="input-url">Đường dẫn tệp APK cài đặt (Download URL)*</label>
                  <input
                    id="input-url"
                    type="text"
                    placeholder="Nhập đường dẫn URL tải file APK"
                    value={downloadUrl}
                    onChange={(e) => setDownloadUrl(e.target.value)}
                    disabled={submitting}
                    required={uploadType === 'url'}
                  />
                </div>
              )}

              <div className="form-group">
                <label htmlFor="input-changelog">Chi tiết cập nhật (Changelog)*</label>
                <textarea
                  id="input-changelog"
                  rows={4}
                  placeholder="Ghi nhận các cải tiến và sửa lỗi trong phiên bản này&#10;- Sửa lỗi giao diện&#10;- Cải thiện hiệu năng chấm công"
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
                    <strong>Bắt buộc cập nhật:</strong> Người dùng app bắt buộc phải cập nhật lên bản này mới sử dụng được tiếp.
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
                  <option value="RELEASED">Phát hành hàng loạt ngay (Cập nhật và thông báo push ngay lập tức)</option>
                </select>
              </div>

              {status === 'RELEASED' && (
                <div className="release-warning">
                  <AlertCircle size={16} className="warning-icon" />
                  <span>
                    <strong>Chú ý:</strong> Bản cập nhật sẽ được đẩy thông báo hàng loạt đến tất cả thiết bị của nhân viên khi tạo thành công.
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
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

import React, { useState, useEffect, useCallback } from 'react';
import {
  Search, Shield, UserCheck, RefreshCw, ChevronLeft, ChevronRight,
  ShieldAlert, Users, User, Lock, KeyRound,
} from 'lucide-react';
import { PermissionModal } from './PermissionModal';
import type { UserInfo } from '../mockData';
import {
  ROLE_LABELS, ROLE_COLORS, PERMISSION_LABELS, ROLE_DEFAULT_PERMISSIONS,
  getRoleLabel,
} from '../utils/permissions';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import './AccountsTab.css';

interface AccountsTabProps {
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
}

interface UserRecord {
  id: string;
  username: string;
  fullName: string;
  role: string;
  status: string;
  department?: string;
  employeeCode?: string;
  phone?: string;
  avatarUrl?: string;
}

interface PageData {
  content: UserRecord[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
}

const STATUS_LABELS: Record<string, string> = {
  ACTIVE: 'Hoạt động',
  PENDING_APPROVAL: 'Chờ duyệt',
  SUSPENDED: 'Đã khóa',
  REGISTERED: 'Đã đăng ký',
  DELETED: 'Đã xóa',
};

const STATUS_CLASS: Record<string, string> = {
  ACTIVE: 'active',
  PENDING_APPROVAL: 'pending',
  SUSPENDED: 'suspended',
  REGISTERED: 'registered',
  DELETED: 'deleted',
};

function avatarColor(role: string): string {
  return ROLE_COLORS[role?.toUpperCase()] ?? '#6b7280';
}

const PAGE_SIZE = 15;

export const AccountsTab: React.FC<AccountsTabProps> = ({ showToast, currentUser }) => {
  const [keyword, setKeyword] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [page, setPage] = useState(0);
  const [pageData, setPageData] = useState<PageData | null>(null);
  const [loading, setLoading] = useState(false);
  const [updatingId, setUpdatingId] = useState<string | null>(null);

  const isSuperAdmin = currentUser?.role?.toUpperCase() === 'SUPER_ADMIN';
  const isAdmin = currentUser?.role?.toUpperCase() === 'ADMIN' || isSuperAdmin;

  // Modal state
  const [permModalUser, setPermModalUser] = useState<{ id: string; fullName: string; role: string } | null>(null);

  const fetchUsers = useCallback(async (kw: string, pg: number) => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        keyword: kw,
        page: String(pg),
        size: String(PAGE_SIZE),
        sort: 'createdAt,desc',
      });
      const res = await fetch(`/api/v1/auth/users?${params}`, {
        headers: getAuthHeaders(),
      });
      if (!res.ok) throw new Error(`Lỗi ${res.status}`);
      const result = await res.json();
      if (result?.data) {
        setPageData(result.data);
      }
    } catch (e: any) {
      showToast(`Không thể tải danh sách user: ${e.message}`);
    } finally {
      setLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    const timer = setTimeout(() => {
      setPage(0);
      fetchUsers(keyword, 0);
    }, 300);
    return () => clearTimeout(timer);
  }, [keyword, fetchUsers]);

  useEffect(() => {
    fetchUsers(keyword, page);
  }, [page]); // eslint-disable-line

  const handleUpdateRole = async (userId: string, newRole: string) => {
    if (!isSuperAdmin) return;
    setUpdatingId(userId);
    try {
      const res = await fetch(`/api/v1/auth/users/${userId}/role`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ role: newRole }),
      });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || `Lỗi ${res.status}`);
      }
      showToast(`Đã đổi quyền thành ${getRoleLabel(newRole)}`);
      fetchUsers(keyword, page);
    } catch (e: any) {
      showToast(`Lỗi đổi quyền: ${e.message}`);
    } finally {
      setUpdatingId(null);
    }
  };

  const handleToggleStatus = async (user: UserRecord) => {
    const action = user.status === 'ACTIVE' ? 'SUSPEND' : 'ACTIVATE';
    const label = action === 'SUSPEND' ? 'khóa' : 'kích hoạt';
    setUpdatingId(user.id);
    try {
      const res = await fetch(`/api/v1/auth/users/${user.id}/status`, {
        method: 'PATCH',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ action }),
      });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || `Lỗi ${res.status}`);
      }
      showToast(`Đã ${label} tài khoản ${user.fullName}`);
      fetchUsers(keyword, page);
    } catch (e: any) {
      showToast(`Lỗi: ${e.message}`);
    } finally {
      setUpdatingId(null);
    }
  };

  // Lọc thêm theo role filter (client-side)
  const displayUsers = roleFilter
    ? (pageData?.content ?? []).filter(u => u.role === roleFilter)
    : (pageData?.content ?? []);

  // Count stats
  const totalUsers = pageData?.totalElements ?? 0;
  const roleStats: Record<string, number> = {};
  (pageData?.content ?? []).forEach(u => {
    roleStats[u.role] = (roleStats[u.role] ?? 0) + 1;
  });

  return (
    <div className="accounts-tab">
      {/* Header */}
      <div className="accounts-header">
        <div className="accounts-search-box">
          <Search size={16} style={{ color: 'var(--text-muted, #6b7280)', flexShrink: 0 }} />
          <input
            type="text"
            placeholder="Tìm theo tên hoặc mã nhân viên..."
            value={keyword}
            onChange={e => setKeyword(e.target.value)}
            id="accounts-search-input"
          />
        </div>
        <select
          className="accounts-filter-select"
          value={roleFilter}
          onChange={e => setRoleFilter(e.target.value)}
          id="accounts-role-filter"
        >
          <option value="">Tất cả Role</option>
          {Object.entries(ROLE_LABELS).map(([key, label]) => (
            <option key={key} value={key}>{label}</option>
          ))}
        </select>
        <button
          className="btn-icon-sm"
          onClick={() => fetchUsers(keyword, page)}
          title="Làm mới danh sách"
          id="accounts-refresh-btn"
        >
          <RefreshCw size={15} />
        </button>
      </div>

      {/* Stats */}
      <div className="accounts-stats-row">
        <div className="accounts-stat-card">
          <span className="stat-value">{totalUsers}</span>
          <span className="stat-label">Tổng tài khoản</span>
        </div>
        {['SUPER_ADMIN', 'ADMIN', 'MANAGER', 'TECHNICIAN', 'WAREHOUSE', 'EMPLOYEE'].map(role => (
          <div key={role} className="accounts-stat-card" style={{ borderLeftColor: ROLE_COLORS[role], borderLeftWidth: 3 }}>
            <span className="stat-value" style={{ color: ROLE_COLORS[role] }}>
              {roleStats[role] ?? '—'}
            </span>
            <span className="stat-label">{ROLE_LABELS[role]}</span>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className="accounts-table-wrapper">
        <table className="accounts-table">
          <thead>
            <tr>
              <th>Người dùng</th>
              <th>Phòng ban</th>
              <th>Role</th>
              <th>Trạng thái</th>
              <th>Permissions</th>
              <th>Hành động</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={6}>
                  <div className="accounts-loading">
                    <div className="accounts-spinner" />
                    <span>Đang tải danh sách...</span>
                  </div>
                </td>
              </tr>
            ) : displayUsers.length === 0 ? (
              <tr>
                <td colSpan={6}>
                  <div className="accounts-empty">
                    <Users size={40} style={{ opacity: 0.3, marginBottom: '0.75rem' }} />
                    <p>Không tìm thấy tài khoản nào</p>
                  </div>
                </td>
              </tr>
            ) : (
              displayUsers.map(user => {
                const isMe = user.username === currentUser?.username;
                const isBusy = updatingId === user.id;
                const roleKey = user.role?.toUpperCase();
                const perms = ROLE_DEFAULT_PERMISSIONS[roleKey] ?? [];
                const showPerms = perms.slice(0, 4);
                const extraCount = perms.length - showPerms.length;

                return (
                  <tr key={user.id}>
                    {/* User */}
                    <td>
                      <div className="user-cell">
                        <div
                          className="user-avatar-sm"
                          style={{ background: avatarColor(user.role) }}
                        >
                          {(user.fullName || user.username).charAt(0).toUpperCase()}
                        </div>
                        <div className="user-cell-info">
                          <span className="user-cell-name" title={user.fullName}>
                            {user.fullName || user.username}
                            {isMe && (
                              <span style={{ fontSize: '0.7rem', color: 'var(--color-primary, #25437a)', marginLeft: 6 }}>(bạn)</span>
                            )}
                          </span>
                          <span className="user-cell-username">@{user.username}</span>
                        </div>
                      </div>
                    </td>

                    {/* Department */}
                    <td>
                      <span className="dept-text">{user.department || '—'}</span>
                    </td>

                    {/* Role */}
                    <td>
                      <span
                        className="role-badge"
                        style={{
                          color: ROLE_COLORS[roleKey] ?? '#64748b',
                          borderColor: `${ROLE_COLORS[roleKey] ?? '#64748b'}40`,
                          background: `${ROLE_COLORS[roleKey] ?? '#64748b'}15`,
                        }}
                      >
                        <Shield size={11} />
                        {getRoleLabel(user.role)}
                      </span>
                    </td>

                    {/* Status */}
                    <td>
                      <span className={`status-badge ${STATUS_CLASS[user.status] ?? ''}`}>
                        {STATUS_LABELS[user.status] ?? user.status}
                      </span>
                    </td>

                    {/* Permissions */}
                    <td>
                      <div className="permissions-mini">
                        {showPerms.map(p => (
                          <span key={p} className="perm-chip" title={PERMISSION_LABELS[p] ?? p}>
                            {PERMISSION_LABELS[p]?.replace('Quản lý ', '').replace('Xem ', '') ?? p}
                          </span>
                        ))}
                        {extraCount > 0 && (
                          <span className="perm-chip-more">+{extraCount} khác</span>
                        )}
                      </div>
                    </td>

                    {/* Actions */}
                    <td>
                      <div className="accounts-actions">
                        {/* Đổi role — chỉ SUPER_ADMIN */}
                        {isSuperAdmin && !isMe && (
                          <select
                            className="accounts-role-select"
                            value={user.role}
                            disabled={isBusy}
                            onChange={e => handleUpdateRole(user.id, e.target.value)}
                            id={`role-select-${user.id}`}
                            title="Thay đổi role"
                          >
                            {Object.entries(ROLE_LABELS).map(([key, label]) => (
                              <option key={key} value={key}>{label}</option>
                            ))}
                          </select>
                        )}

                        {/* Phân quyền chi tiết — ADMIN+ */}
                        {isAdmin && !isMe && (
                          <button
                            className="btn-icon-sm"
                            onClick={() => setPermModalUser({ id: user.id, fullName: user.fullName || user.username, role: getRoleLabel(user.role) })}
                            disabled={isBusy}
                            title="Phân quyền chi tiết"
                            id={`btn-perms-${user.id}`}
                            style={{ color: 'var(--color-primary, #25437a)' }}
                          >
                            <KeyRound size={14} />
                          </button>
                        )}

                        {/* Suspend / Activate — ADMIN+ */}
                        {!isMe && user.status !== 'PENDING_APPROVAL' && (
                          user.status === 'ACTIVE' ? (
                            <button
                              className="btn-icon-sm danger"
                              onClick={() => handleToggleStatus(user)}
                              disabled={isBusy}
                              title="Khóa tài khoản"
                              id={`btn-suspend-${user.id}`}
                            >
                              <Lock size={14} />
                            </button>
                          ) : user.status === 'SUSPENDED' ? (
                            <button
                              className="btn-icon-sm success"
                              onClick={() => handleToggleStatus(user)}
                              disabled={isBusy}
                              title="Kích hoạt tài khoản"
                              id={`btn-activate-${user.id}`}
                            >
                              <UserCheck size={14} />
                            </button>
                          ) : null
                        )}

                        {/* Self icon */}
                        {isMe && (
                          <span title="Tài khoản của bạn" style={{ color: 'var(--color-primary, #25437a)', opacity: 0.8 }}>
                            <User size={15} />
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>

        {/* Pagination */}
        {pageData && pageData.totalPages > 1 && (
          <div className="accounts-pagination">
            <span className="accounts-pagination-info">
              Hiển thị {pageData.number * pageData.size + 1}–{Math.min((pageData.number + 1) * pageData.size, pageData.totalElements)} / {pageData.totalElements} tài khoản
            </span>
            <div className="accounts-pagination-btns">
              <button
                className="accounts-page-btn"
                onClick={() => setPage(p => p - 1)}
                disabled={pageData.number === 0}
                id="accounts-prev-page"
              >
                <ChevronLeft size={14} />
              </button>
              {Array.from({ length: pageData.totalPages }, (_, i) => i)
                .filter(i => Math.abs(i - pageData.number) <= 2)
                .map(i => (
                  <button
                    key={i}
                    className={`accounts-page-btn ${i === pageData.number ? 'active-page' : ''}`}
                    onClick={() => setPage(i)}
                    id={`accounts-page-${i}`}
                  >
                    {i + 1}
                  </button>
                ))}
              <button
                className="accounts-page-btn"
                onClick={() => setPage(p => p + 1)}
                disabled={pageData.number >= pageData.totalPages - 1}
                id="accounts-next-page"
              >
                <ChevronRight size={14} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Permission Matrix */}
      <div className="accounts-matrix-card">
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1rem' }}>
          <ShieldAlert size={18} style={{ color: 'var(--color-primary, #25437a)' }} />
          <span style={{ fontWeight: 600, fontSize: '0.9rem', color: 'var(--color-text-dark, #0f172a)' }}>Tổng hợp quyền theo Role</span>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="accounts-matrix-table">
            <thead>
              <tr>
                <th>
                  Permission
                </th>
                {['SUPER_ADMIN','ADMIN','MANAGER','TECHNICIAN','WAREHOUSE','EMPLOYEE'].map(r => (
                  <th key={r} style={{ color: ROLE_COLORS[r] }}>
                    {ROLE_LABELS[r]}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {Object.entries(PERMISSION_LABELS).map(([permCode, permLabel]) => (
                <tr key={permCode}>
                  <td>
                    {permLabel}
                  </td>
                  {['SUPER_ADMIN','ADMIN','MANAGER','TECHNICIAN','WAREHOUSE','EMPLOYEE'].map(r => {
                    const has = (ROLE_DEFAULT_PERMISSIONS[r] ?? []).includes(permCode);
                    return (
                      <td key={r} style={{ textAlign: 'center' }}>
                        {has
                          ? <span style={{ color: '#10b981', fontSize: '1rem', fontWeight: 700 }}>✓</span>
                          : <span style={{ color: 'var(--color-text-light, #cbd5e1)', fontSize: '0.85rem' }}>—</span>
                        }
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Permission Modal */}
      {permModalUser && (
        <PermissionModal
          userId={permModalUser.id}
          userName={permModalUser.fullName}
          userRole={permModalUser.role}
          onClose={() => setPermModalUser(null)}
          showToast={showToast}
        />
      )}
    </div>
  );
};

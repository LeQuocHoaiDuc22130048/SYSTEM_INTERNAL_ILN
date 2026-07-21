import React, { useState, useEffect, useCallback } from 'react';
import { X, Shield, RotateCcw, Save, CheckCircle2, XCircle, MinusCircle } from 'lucide-react';
import { PERMISSION_LABELS } from '../utils/permissions';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import './PermissionModal.css';

// ── Types ─────────────────────────────────────────────────────────────────

interface PermissionDetail {
  code: string;
  name: string;
  module: string;
  description: string;
  fromRole: boolean;
  overrideGranted: boolean | null;  // null = kế thừa, true = grant, false = deny
  effectiveGranted: boolean;
}

interface PermissionModalProps {
  userId: string;
  userName: string;
  userRole: string;
  onClose: () => void;
  showToast: (msg: string) => void;
}

// ── Module display names ───────────────────────────────────────────────────

const MODULE_LABELS: Record<string, string> = {
  DASHBOARD:    '📊 Dashboard',
  REPAIR:       '🔧 Sửa chữa',
  INVENTORY:    '📦 Kho hàng',
  MESSAGING:    '💬 Tin nhắn',
  NOTIFICATION: '🔔 Thông báo',
  ATTENDANCE:   '📅 Chấm công',
  EMPLOYEE:     '👥 Nhân viên',
  AUTH:         '🔐 Tài khoản',
  PROFILE:      '👤 Hồ sơ',
};

// Trạng thái override: 'inherited' | 'grant' | 'deny'
type OverrideState = 'inherited' | 'grant' | 'deny';

// ── Helpers ───────────────────────────────────────────────────────────────

function overrideToState(overrideGranted: boolean | null): OverrideState {
  if (overrideGranted === null) return 'inherited';
  return overrideGranted ? 'grant' : 'deny';
}

function stateToOverride(state: OverrideState): boolean | null {
  if (state === 'inherited') return null;
  return state === 'grant';
}

// ── Component ─────────────────────────────────────────────────────────────

export const PermissionModal: React.FC<PermissionModalProps> = ({
  userId, userName, userRole, onClose, showToast,
}) => {
  const [permissions, setPermissions] = useState<PermissionDetail[]>([]);
  const [overrides, setOverrides] = useState<Record<string, OverrideState>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  // ── Load permissions ──────────────────────────────────────────────────

  const loadPermissions = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/v1/auth/users/${userId}/permissions`, {
        headers: getAuthHeaders(),
      });
      if (!res.ok) throw new Error(`Lỗi ${res.status}`);
      const result = await res.json();
      const data: PermissionDetail[] = result.data ?? [];
      setPermissions(data);
      // Init overrides từ server
      const init: Record<string, OverrideState> = {};
      data.forEach(p => {
        init[p.code] = overrideToState(p.overrideGranted);
      });
      setOverrides(init);
      setHasChanges(false);
    } catch (e: any) {
      showToast(`Không tải được quyền: ${e.message}`);
    } finally {
      setLoading(false);
    }
  }, [userId, showToast]);

  useEffect(() => {
    loadPermissions();
  }, [loadPermissions]);

  // ── Handle toggle ─────────────────────────────────────────────────────

  const handleToggle = (code: string, newState: OverrideState) => {
    setOverrides(prev => {
      const updated = { ...prev, [code]: newState };
      setHasChanges(Object.entries(updated).some(([c, s]) => {
        const orig = overrideToState(permissions.find(p => p.code === c)?.overrideGranted ?? null);
        return s !== orig;
      }));
      return updated;
    });
  };

  // ── Save ──────────────────────────────────────────────────────────────

  const handleSave = async () => {
    setSaving(true);
    try {
      // Chỉ gửi các permissions thực sự thay đổi
      const changedOverrides: Record<string, boolean | null> = {};
      permissions.forEach(perm => {
        const original = overrideToState(perm.overrideGranted);
        const current = overrides[perm.code] ?? 'inherited';
        if (current !== original) {
          changedOverrides[perm.code] = stateToOverride(current);
        }
      });

      const res = await fetch(`/api/v1/auth/users/${userId}/permissions`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ overrides: changedOverrides }),
      });

      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.message || `Lỗi ${res.status}`);
      }

      const result = await res.json();
      const updated: PermissionDetail[] = result.data ?? [];
      setPermissions(updated);
      const updatedOverrides: Record<string, OverrideState> = {};
      updated.forEach(p => {
        updatedOverrides[p.code] = overrideToState(p.overrideGranted);
      });
      setOverrides(updatedOverrides);
      setHasChanges(false);

      const grantCount = Object.values(changedOverrides).filter(v => v === true).length;
      const denyCount = Object.values(changedOverrides).filter(v => v === false).length;
      const resetCount = Object.values(changedOverrides).filter(v => v === null).length;
      showToast(`Đã cập nhật quyền cho ${userName} (${grantCount} thêm, ${denyCount} thu hồi, ${resetCount} reset)`);
    } catch (e: any) {
      showToast(`Lỗi lưu quyền: ${e.message}`);
    } finally {
      setSaving(false);
    }
  };

  // ── Reset all overrides ───────────────────────────────────────────────

  const handleResetAll = async () => {
    setSaving(true);
    try {
      const res = await fetch(`/api/v1/auth/users/${userId}/permissions`, {
        method: 'PUT',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ overrides: {} }),  // Map rỗng = reset tất cả
      });
      if (!res.ok) throw new Error(`Lỗi ${res.status}`);
      showToast(`Đã reset tất cả quyền override của ${userName}`);
      await loadPermissions();
    } catch (e: any) {
      showToast(`Lỗi reset quyền: ${e.message}`);
    } finally {
      setSaving(false);
    }
  };

  // ── Group by module ───────────────────────────────────────────────────

  const grouped = permissions.reduce<Record<string, PermissionDetail[]>>((acc, p) => {
    if (!acc[p.module]) acc[p.module] = [];
    acc[p.module].push(p);
    return acc;
  }, {});

  // Đếm thay đổi
  const changedCount = permissions.filter(p => {
    const original = overrideToState(p.overrideGranted);
    return (overrides[p.code] ?? 'inherited') !== original;
  }).length;

  // Đếm override đang active
  const activeGrantCount = Object.values(overrides).filter(s => s === 'grant').length;
  const activeDenyCount = Object.values(overrides).filter(s => s === 'deny').length;

  return (
    <div className="perm-modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="perm-modal">

        {/* Header */}
        <div className="perm-modal-header">
          <div style={{
            width: 40, height: 40, borderRadius: 10,
            background: 'rgba(99,102,241,0.15)',
            border: '1px solid rgba(99,102,241,0.3)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <Shield size={20} color="#818cf8" />
          </div>
          <div className="perm-modal-header-info">
            <p className="perm-modal-title">Phân quyền: {userName}</p>
            <p className="perm-modal-subtitle">
              Role: {userRole} &nbsp;·&nbsp; {activeGrantCount} quyền cấp thêm &nbsp;·&nbsp; {activeDenyCount} quyền thu hồi
            </p>
          </div>
          <button className="perm-modal-close" onClick={onClose} id="perm-modal-close-btn">
            <X size={16} />
          </button>
        </div>

        {/* Legend */}
        <div className="perm-legend">
          <div className="perm-legend-item">
            <div className="perm-legend-dot inherited" />
            <span>Kế thừa từ role</span>
          </div>
          <div className="perm-legend-item">
            <div className="perm-legend-dot granted" />
            <span>Cấp thêm (Grant)</span>
          </div>
          <div className="perm-legend-item">
            <div className="perm-legend-dot denied" />
            <span>Thu hồi (Deny)</span>
          </div>
        </div>

        {/* Body */}
        <div className="perm-modal-body">
          {loading ? (
            <div className="perm-modal-loading">
              <div className="perm-modal-spinner" />
              <span>Đang tải danh sách quyền...</span>
            </div>
          ) : (
            Object.entries(grouped).map(([module, perms]) => (
              <div key={module} className="perm-module-group">
                <div className="perm-module-header">
                  <span className="perm-module-label">
                    {MODULE_LABELS[module] ?? module}
                  </span>
                  <span className="perm-module-count">{perms.length} quyền</span>
                </div>

                {perms.map(perm => {
                  const currentState = overrides[perm.code] ?? 'inherited';

                  // Tính effective theo local state
                  let localEffective: boolean;
                  if (currentState === 'grant') localEffective = true;
                  else if (currentState === 'deny') localEffective = false;
                  else localEffective = perm.fromRole;

                  const isChanged = currentState !== overrideToState(perm.overrideGranted);

                  return (
                    <div key={perm.code} className="perm-row">
                      {/* Effective indicator */}
                      <div className={`perm-effective ${localEffective ? 'yes' : 'no'}`}>
                        {localEffective ? '✓' : '—'}
                      </div>

                      {/* Info */}
                      <div className="perm-row-info">
                        <div className="perm-row-name">
                          {PERMISSION_LABELS[perm.code] ?? perm.name}
                          {isChanged && (
                            <span className="perm-changed-badge">thay đổi</span>
                          )}
                        </div>
                        <div className="perm-row-code">{perm.code}</div>
                        {perm.description && (
                          <div className="perm-row-desc">{perm.description}</div>
                        )}
                      </div>

                      {/* Toggle buttons */}
                      <div className="perm-toggle-group">
                        {/* Kế thừa từ role */}
                        <button
                          className={`perm-toggle-btn inherited ${currentState === 'inherited' ? 'active' : ''}`}
                          onClick={() => handleToggle(perm.code, 'inherited')}
                          title={`Kế thừa từ role (${perm.fromRole ? 'có quyền' : 'không có'})`}
                          id={`perm-inherit-${perm.code}`}
                          disabled={saving}
                        >
                          <MinusCircle size={14} />
                        </button>

                        {/* Grant */}
                        <button
                          className={`perm-toggle-btn grant ${currentState === 'grant' ? 'active' : ''}`}
                          onClick={() => handleToggle(perm.code, 'grant')}
                          title="Cấp thêm quyền này"
                          id={`perm-grant-${perm.code}`}
                          disabled={saving}
                        >
                          <CheckCircle2 size={14} />
                        </button>

                        {/* Deny */}
                        <button
                          className={`perm-toggle-btn deny ${currentState === 'deny' ? 'active' : ''}`}
                          onClick={() => handleToggle(perm.code, 'deny')}
                          title="Thu hồi quyền này"
                          id={`perm-deny-${perm.code}`}
                          disabled={saving}
                        >
                          <XCircle size={14} />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <div className="perm-modal-footer">
          <div className="perm-modal-footer-info">
            {hasChanges
              ? <span className="perm-changed-badge">⚠ {changedCount} thay đổi chưa lưu</span>
              : <span>Không có thay đổi</span>
            }
          </div>
          <div className="perm-footer-btns">
            <button
              className="btn-perm-reset"
              onClick={handleResetAll}
              disabled={saving || loading}
              title="Reset tất cả về mặc định role"
              id="perm-reset-all-btn"
            >
              <RotateCcw size={13} style={{ marginRight: 4 }} />
              Reset tất cả
            </button>
            <button
              className="btn-perm-save"
              onClick={handleSave}
              disabled={saving || loading || !hasChanges}
              id="perm-save-btn"
            >
              <Save size={14} />
              {saving ? 'Đang lưu...' : 'Lưu quyền'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

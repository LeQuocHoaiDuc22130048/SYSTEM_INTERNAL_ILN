import { getAuthHeaders, getJsonAuthHeaders } from './auth';

export interface PortalSupportConfig {
  hotlineNumber: string;
  hotlineLabel: string;
  zaloUrl: string;
  zaloLabel: string;
  workingHours: string;
  workshopAddress: string;
  updatedAt?: string;
}

export interface UpdatePortalSupportConfigRequest {
  hotlineNumber: string;
  hotlineLabel?: string;
  zaloUrl: string;
  zaloLabel?: string;
  workingHours?: string;
  workshopAddress?: string;
}

const API_BASE = '/api/v1';

export async function getPortalSupportConfig(): Promise<PortalSupportConfig> {
  const res = await fetch(`${API_BASE}/portal/support-info`, {
    headers: getAuthHeaders(),
  });
  if (!res.ok) {
    throw new Error('Không thể tải cấu hình kênh hỗ trợ');
  }
  const json = await res.json();
  return json.data;
}

export async function updatePortalSupportConfig(
  req: UpdatePortalSupportConfigRequest
): Promise<PortalSupportConfig> {
  const res = await fetch(`${API_BASE}/admin/portal-config`, {
    method: 'PUT',
    headers: getJsonAuthHeaders(),
    body: JSON.stringify(req),
  });
  if (!res.ok) {
    const errorJson = await res.json().catch(() => ({}));
    throw new Error(errorJson.message || 'Không thể cập nhật cấu hình kênh hỗ trợ');
  }
  const json = await res.json();
  return json.data;
}

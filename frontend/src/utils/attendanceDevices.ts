import { getAuthHeaders, getJsonAuthHeaders } from './auth';
export interface AttendanceTablet {
    id: string;
    accountId: string;
    installationId: string;
    name: string;
    status: 'PENDING' | 'APPROVED' | 'BLOCKED';
    online: boolean;
    model?: string;
    osVersion?: string;
    appVersion?: string;
    lastSeenAt: string | null;
    lastSyncAt: string | null;
    pendingCount: number;
}
export interface TabletReview {
    id: string;
    deviceId: string;
    localLogId: string;
    status: string;
    createdAt: string;
    error?: string;
    reason?: string;
    recordId?: string;
    employeeId?: string;
    capturedAt?: string;
    attendanceType?: string;
    faceImageBase64?: string;
    imageContentType?: string;
}
export interface TabletEvent {
    id: string;
    actorId: string;
    action: string;
    reason: string;
    occurredAt: string;
}
export interface Page<T> {
    content: T[];
    number: number;
    last: boolean;
    totalElements: number;
}
const base = '/api/v1/attendance/devices';
export const canManageTablets = (role?: string) => role === 'ADMIN' || role === 'SUPER_ADMIN';
export function tabletStatus(device: Pick<AttendanceTablet, 'status' | 'online'>): string {
    const status = { PENDING: 'Chờ duyệt', APPROVED: 'Đã duyệt', BLOCKED: 'Đã khóa' }[device.status];
    return `${status} · ${device.online ? 'Đang kết nối' : 'Mất kết nối'}`;
}
async function request<T>(path: string, body?: object): Promise<T> {
    const response = await fetch(base + path, { method: body ? 'POST' : 'GET', headers: body ? getJsonAuthHeaders() : getAuthHeaders(), ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(15000) });
    const result = await response.json();
    if (!response.ok || result.success === false)
        throw new Error(result.message || 'Không thể xử lý yêu cầu');
    return result.data as T;
}
export const listTablets = () => request<AttendanceTablet[]>('');
export const tabletAction = (id: string, action: 'approve' | 'block' | 'unblock', reason: string) => request<AttendanceTablet>(`/${encodeURIComponent(id)}/${action}`, { reason: reason.trim() });
export const listTabletReviews = (page = 0) => request<Page<TabletReview>>(`/reviews?page=${page}`);
export const tabletEvents = (id: string) => request<TabletEvent[]>(`/${encodeURIComponent(id)}/events`);
export const reviewAction = (id: string, action: 'approve' | 'reject', reason: string) => request<TabletReview>(`/reviews/${encodeURIComponent(id)}/${action}`, { reason: reason.trim() });
export const reviewDetail = (id: string) => request<TabletReview>(`/reviews/${encodeURIComponent(id)}`);

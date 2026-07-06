/** Thời gian timeout tối đa cho mỗi request API (ms) */
export const REQUEST_TIMEOUT_MS = 8000;

/** Số phút ân hạn khi tính đi muộn */
export const LATE_GRACE_MINUTES = 15;

/** Số ngày công chuẩn trong tháng */
export const STANDARD_WORK_DAYS = 26;

/**
 * Tạo Authorization headers từ access token lưu trong localStorage.
 * Trả về object headers sẵn sàng truyền vào fetch().
 */
export function getAuthHeaders(): Record<string, string> {
  const token = localStorage.getItem('accessToken');
  if (!token) return {};
  return { Authorization: `Bearer ${token}` };
}

/**
 * Tạo headers JSON + Authorization cho các request có body (POST/PUT).
 */
export function getJsonAuthHeaders(): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    ...getAuthHeaders(),
  };
}

/**
 * Tạo AbortController với timeout tự động.
 * Trả về { signal, clearTimeout } để dùng với fetch().
 */
export function createTimeoutController(timeoutMs = REQUEST_TIMEOUT_MS) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  return { signal: controller.signal, clear: () => clearTimeout(timeoutId) };
}

/**
 * Thiết lập interceptor cho window.fetch toàn cục để tự động refresh token khi gặp lỗi 401/403.
 */
export function setupFetchInterceptor() {
  const originalFetch = window.fetch;
  window.fetch = async function (input, init) {
    const response = await originalFetch(input, init);

    if (response.status === 401 || response.status === 403) {
      const url = typeof input === 'string' ? input : (input instanceof URL ? input.toString() : (input as Request).url);
      
      // Không tự động refresh đối với các API auth cơ bản (login, refresh, logout) để tránh lặp vô hạn
      if (url.includes('/api/v1/auth/refresh') || url.includes('/api/v1/auth/login') || url.includes('/api/v1/auth/logout')) {
        return response;
      }

      const refreshToken = localStorage.getItem('refreshToken');
      if (refreshToken) {
        try {
          const refreshResponse = await originalFetch('/api/v1/auth/refresh', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ refreshToken }),
          });

          if (refreshResponse.ok) {
            const result = await refreshResponse.json();
            if (result && result.data) {
              const { accessToken, refreshToken: newRefreshToken } = result.data;
              localStorage.setItem('accessToken', accessToken);
              localStorage.setItem('refreshToken', newRefreshToken);

              // Cập nhật Authorization header trong init
              const newInit = init ? { ...init } : {};
              if (newInit.headers) {
                if (newInit.headers instanceof Headers) {
                  newInit.headers.set('Authorization', `Bearer ${accessToken}`);
                } else if (Array.isArray(newInit.headers)) {
                  const headersArray = [...newInit.headers];
                  const authIndex = headersArray.findIndex(h => h[0].toLowerCase() === 'authorization');
                  if (authIndex !== -1) {
                    headersArray[authIndex] = ['Authorization', `Bearer ${accessToken}`];
                  } else {
                    headersArray.push(['Authorization', `Bearer ${accessToken}`]);
                  }
                  newInit.headers = headersArray;
                } else {
                  newInit.headers = {
                    ...newInit.headers,
                    'Authorization': `Bearer ${accessToken}`
                  };
                }
              } else {
                newInit.headers = {
                  'Authorization': `Bearer ${accessToken}`
                };
              }

              // Thực hiện lại request ban đầu với token mới
              return originalFetch(input, newInit);
            }
          }
        } catch (e) {
          console.error('[Auth Interceptor] Lỗi khi tự động làm mới token:', e);
        }
      }
    }

    return response;
  };
}

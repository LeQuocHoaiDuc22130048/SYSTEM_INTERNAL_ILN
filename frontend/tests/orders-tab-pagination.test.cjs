const { test } = require('node:test');
const assert = require('node:assert/strict');

test('pagination simulation fetches all pages when totalPages > 1 and aggregates complete order list', async (t) => {
  const mockPages = {
    0: {
      content: Array.from({ length: 1000 }, (_, i) => ({ id: `order-${i + 1}`, orderCode: `RO-${i + 1}` })),
      totalPages: 3,
      totalElements: 2500,
    },
    1: {
      content: Array.from({ length: 1000 }, (_, i) => ({ id: `order-${1000 + i + 1}`, orderCode: `RO-${1000 + i + 1}` })),
      totalPages: 3,
      totalElements: 2500,
    },
    2: {
      content: Array.from({ length: 500 }, (_, i) => ({ id: `order-${2000 + i + 1}`, orderCode: `RO-${2000 + i + 1}` })),
      totalPages: 3,
      totalElements: 2500,
    },
  };

  const fetchedPages = [];
  t.mock.method(global, 'fetch', async (urlStr) => {
    const url = new URL(urlStr, 'https://app.test');
    const page = parseInt(url.searchParams.get('page') || '0', 10);
    fetchedPages.push(page);
    return {
      ok: true,
      json: async () => ({
        success: true,
        data: mockPages[page] || { content: [], totalPages: 0, totalElements: 0 },
      }),
    };
  });

  // Giả lập logic fetchOrders của OrdersTab
  const pageSize = 1000;
  const initialRes = await fetch(`/api/v1/repair-orders?page=0&size=${pageSize}`);
  const result = await initialRes.json();
  let allOrders = [...result.data.content];
  const totalPages = result.data.totalPages || 1;
  const totalElements = result.data.totalElements ?? allOrders.length;

  if (totalPages > 1) {
    const pagePromises = [];
    for (let p = 1; p < totalPages; p++) {
      pagePromises.push(
        fetch(`/api/v1/repair-orders?page=${p}&size=${pageSize}`).then((res) => (res.ok ? res.json() : null))
      );
    }
    const otherResults = await Promise.all(pagePromises);
    for (const r of otherResults) {
      if (r?.data?.content && Array.isArray(r.data.content)) {
        allOrders = allOrders.concat(r.data.content);
      }
    }
  }

  assert.equal(allOrders.length, 2500, 'Tất cả 2500 đơn hàng phải được gom đủ');
  assert.equal(totalElements, 2500, 'Tổng số đơn trong cơ sở dữ liệu phải là 2500');
  assert.deepEqual(fetchedPages.sort(), [0, 1, 2], 'Phải gọi đủ các page 0, 1, 2');
});

test('interceptor logic does not attempt refresh on HTTP 403 Forbidden', () => {
  let refreshCalled = false;
  const intercept = (status) => {
    if (status === 401) {
      refreshCalled = true;
    }
  };

  intercept(403);
  assert.equal(refreshCalled, false, 'Không được gọi refresh token khi gặp 403 Forbidden');

  intercept(401);
  assert.equal(refreshCalled, true, 'Chỉ gọi refresh token khi gặp 401 Unauthorized');
});

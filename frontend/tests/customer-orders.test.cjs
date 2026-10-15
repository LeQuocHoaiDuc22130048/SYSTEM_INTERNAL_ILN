const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

const source = fs.readFileSync(path.join(__dirname, '../src/utils/customerApi.ts'), 'utf8');
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const api = { exports: {} };
new Function('require', 'exports', compiled)(() => ({
  getAuthHeaders: () => ({ Authorization: 'Bearer test' }),
  getJsonAuthHeaders: () => ({ Authorization: 'Bearer test', 'Content-Type': 'application/json' }),
}), api.exports);

test('existing order lookup filters before server pagination and encodes contact search', async t => {
  let url;
  t.mock.method(global, 'fetch', async value => {
    url = new URL(value, 'https://app.test');
    return { ok: true, json: async () => ({ data: { content: [{ id: 'order-1' }], totalPages: 3 } }) };
  });
  const result = await api.exports.getCustomerOrderCandidates('  Nam & An  ', 2);
  assert.equal(url.pathname, '/api/v1/repair-orders');
  assert.equal(url.searchParams.get('keyword'), 'Nam & An');
  assert.equal(url.searchParams.get('page'), '2');
  assert.equal(url.searchParams.get('unlinkedOnly'), 'true');
  assert.equal(result.data.totalPages, 3);
  await api.exports.getCustomerOrderCandidates('', 0, false);
  assert.equal(url.searchParams.get('unlinkedOnly'), 'false');
});

test('link uses selected profile ID and trimmed reason; accepts server replacement name', async t => {
  let request;
  t.mock.method(global, 'fetch', async (url, options) => {
    request = { url, ...options };
    return { ok: true, status: 200, json: async () => ({ data: {
      id: 'order-1', customerId: 'customer-1', customerName: 'Công ty Minh Phát',
    } }) };
  });
  const result = await api.exports.linkRepairOrderCustomer('order-1', 'customer-1', '  Xác minh  ');
  assert.equal(request.url, '/api/v1/repair-orders/order-1/customer');
  assert.equal(request.method, 'PUT');
  assert.deepEqual(JSON.parse(request.body), { customerId: 'customer-1', reason: 'Xác minh' });
  assert.equal(result.data.customerName, 'Công ty Minh Phát');
});

test('permission and connection failures are returned for display without reporting success', async t => {
  t.mock.method(global, 'fetch', async () => ({ ok: false, status: 403, json: async () => ({ message: 'Không có quyền' }) }));
  const result = await api.exports.linkRepairOrderCustomer('order-1', 'customer-1', 'Xác minh');
  assert.equal(result.success, false);
  assert.equal(result.message, 'Không có quyền');
  t.mock.method(global, 'fetch', async () => { throw new Error('offline'); });
  assert.equal((await api.exports.getCustomerOrderCandidates('')).success, false);
});

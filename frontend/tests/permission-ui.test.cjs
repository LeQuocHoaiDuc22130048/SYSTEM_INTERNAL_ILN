const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const modules = new Map();
function load(file) {
  file = path.resolve(file);
  if (modules.has(file)) return modules.get(file).exports;
  const mod = { exports: {} };
  modules.set(file, mod);
  const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
  }).outputText;
  const localRequire = name => {
    if (!name.startsWith('.')) return require(name);
    const base = path.resolve(path.dirname(file), name);
    return load([base + '.ts', base + '.tsx'].find(fs.existsSync));
  };
  new Function('require', 'module', 'exports', code)(localRequire, mod, mod.exports);
  return mod.exports;
}
const { PermissionUserContext } = load('src/utils/permissionContext.ts');
const { OrderListPanel } = load('src/components/orders/OrderListPanel.tsx');
function createButton(user) {
  const props = {
    searchTerm: '', statusFilter: 'ALL', warrantyFilter: 'ALL', dateFilter: 'ALL',
    loading: false, displayedOrders: [], filteredOrders: [], selectedOrder: null, visibleCount: 20,
    listWrapperRef: { current: null },
  };
  const html = renderToStaticMarkup(React.createElement(PermissionUserContext.Provider, { value: user }, React.createElement(OrderListPanel, props)));
  return html.match(/<button[^>]*class="btn-create-order"[^>]*>/)?.[0] ?? null;
}
test('normal admin without create permission does not render the create action', () => {
  assert.equal(createButton({ role: 'ADMIN', permissions: [] }), null);
});
test('an explicit create grant enables the create action for an employee', () => {
  const button = createButton({ role: 'EMPLOYEE', permissions: ['REPAIR_CREATE'] });
  assert.ok(button);
  assert.doesNotMatch(button, /disabled/);
});

test('update permission does not reveal the create action', () => {
  assert.equal(createButton({ role: 'EMPLOYEE', permissions: ['REPAIR_UPDATE'] }), null);
});

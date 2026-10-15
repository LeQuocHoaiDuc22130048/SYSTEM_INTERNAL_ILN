const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
const compiled = ts.transpileModule(fs.readFileSync('src/utils/permissions.ts', 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
const mod = { exports: {} };
const actions = { exports: {} };
new Function('exports', ts.transpileModule(fs.readFileSync('src/utils/actionPermissions.ts', 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText)(actions.exports);
new Function('require', 'exports', compiled)(() => actions.exports, mod.exports);
test('an explicitly empty permission list denies all normal user actions', () => {
  assert.equal(mod.exports.hasPermission({ role: 'EMPLOYEE', permissions: [] }, 'REPAIR_VIEW'), false);
  assert.equal(mod.exports.hasPermission({ role: 'ADMIN', permissions: [] }, 'CUSTOMER_MANAGE'), false);
});
test('SUPER_ADMIN retains system access even without individual grants', () => {
  assert.equal(mod.exports.hasPermission({ role: 'SUPER_ADMIN', permissions: [] }, 'REPAIR_VIEW'), true);
});
test('explicit grants take precedence over a normal role default', () => {
  assert.equal(mod.exports.hasPermission({ role: 'EMPLOYEE', permissions: ['ACCOUNT_APPROVE'] }, 'ACCOUNT_APPROVE'), true);
  assert.equal(mod.exports.hasPermission({ role: 'EMPLOYEE', permissions: ['ACCOUNT_APPROVE'] }, 'REPAIR_VIEW'), false);
});

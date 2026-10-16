const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');

// Exercise the modal's actual state conversion without mounting the network UI.
const source = fs.readFileSync('src/components/PermissionModal.tsx', 'utf8');
const compiled = ts.transpileModule(source + '\nexport { overrideToState, stateToOverride };', {
  compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
}).outputText;
const mod = { exports: {} };
new Function('require', 'module', 'exports', compiled)(
  name => name.startsWith('.') ? {} : require(name), mod, mod.exports,
);
const { overrideToState, stateToOverride } = mod.exports;

test('opening API permissions with an omitted override preserves inheritance', () => {
  const permissions = [
    { code: 'ATTENDANCE_VIEW', fromRole: true, effectiveGranted: true },
    { code: 'BANNER_CREATE', fromRole: false, effectiveGranted: false },
  ];
  const states = permissions.map(p => overrideToState(p.overrideGranted));
  assert.deepEqual(states, ['inherited', 'inherited']);
  assert.equal(states.filter(state => state === 'deny').length, 0);
});

test('explicit null, grant and denial retain their distinct states', () => {
  assert.equal(overrideToState(null), 'inherited');
  assert.equal(overrideToState(true), 'grant');
  assert.equal(overrideToState(false), 'deny');
});

test('saving a reset uses null and preserves explicit grants and denials', () => {
  assert.equal(stateToOverride('inherited'), null);
  assert.equal(stateToOverride('grant'), true);
  assert.equal(stateToOverride('deny'), false);
});

function openModal({ role = 'EMPLOYEE', canUpdate = true } = {}) {
  const React = require('react');
  const permissions = [
    { code: 'BANNER_CREATE', module: 'BANNER', fromRole: false },
    { code: 'BANNER_DELETE', module: 'BANNER', fromRole: true, overrideGranted: true },
    { code: 'REPAIR_VIEW', module: 'REPAIR', fromRole: true, overrideGranted: false },
  ];
  const states = [permissions, {
    BANNER_CREATE: 'inherited', BANNER_DELETE: 'grant', REPAIR_VIEW: 'deny',
  }, false, false, false];
  let stateIndex = 0;
  const hooks = {
    ...React,
    useState: () => {
      const index = stateIndex++;
      return [states[index], value => {
        states[index] = typeof value === 'function' ? value(states[index]) : value;
      }];
    },
    useEffect: () => {},
    useCallback: callback => callback,
  };
  const module = { exports: {} };
  new Function('require', 'module', 'exports', compiled)(name => {
    if (name === 'react') return hooks;
    if (name.endsWith('/permissionContext')) return { usePermissionCheck: () => () => canUpdate };
    if (name.endsWith('/permissions')) return { PERMISSION_LABELS: {} };
    return name.startsWith('.') ? {} : require(name);
  }, module, module.exports);
  const tree = module.exports.PermissionModal({ userId: 'employee', userName: 'Employee', userRole: role });
  function find(node, id) {
    if (Array.isArray(node)) return node.map(child => find(child, id)).find(Boolean);
    if (!React.isValidElement(node)) return undefined;
    return node.props.id === id ? node : find(node.props.children, id);
  }
  return { states, button: id => find(tree, id) };
}

for (const state of ['inherited', 'grant', 'deny']) {
  test(`module ${state} action updates all banner permissions and preserves other modules`, () => {
    const modal = openModal();
    const button = modal.button(`perm-module-${state}-BANNER`);
    assert.ok(button, 'module action must be available');
    button.props.onClick();
    assert.deepEqual(modal.states[1], {
      BANNER_CREATE: state, BANNER_DELETE: state, REPAIR_VIEW: 'deny',
    });
    assert.equal(modal.states[4], true, 'changes are staged for the existing Save action');
  });
}

test('module actions remain hidden for protected users and read-only administrators', () => {
  for (const options of [{ role: 'SUPER_ADMIN' }, { canUpdate: false }]) {
    const modal = openModal(options);
    for (const state of ['inherited', 'grant', 'deny']) {
      assert.equal(modal.button(`perm-module-${state}-BANNER`), undefined);
    }
  }
});

test('individual edits still work after a group action and restoring the original clears changes', () => {
  const modal = openModal();
  modal.button('perm-module-deny-BANNER').props.onClick();
  modal.button('perm-grant-BANNER_CREATE').props.onClick();
  assert.deepEqual(modal.states[1], {
    BANNER_CREATE: 'grant', BANNER_DELETE: 'deny', REPAIR_VIEW: 'deny',
  });
  modal.button('perm-inherit-BANNER_CREATE').props.onClick();
  modal.button('perm-grant-BANNER_DELETE').props.onClick();
  assert.equal(modal.states[4], false);
});

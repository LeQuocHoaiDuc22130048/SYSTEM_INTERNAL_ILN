const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');

function loadThemeModule(mockEnv = {}) {
  const compiled = ts.transpileModule(
    fs.readFileSync(path.join(__dirname, '../src/utils/theme.ts'), 'utf8'),
    { compilerOptions: { module: ts.ModuleKind.CommonJS } }
  ).outputText;
  const mod = { exports: {} };
  const fn = new Function('exports', 'window', 'document', compiled);
  fn(mod.exports, mockEnv.window, mockEnv.document);
  return mod.exports;
}

test('resolveTheme returns explicit light or dark mode directly', () => {
  const theme = loadThemeModule({ window: undefined, document: undefined });
  assert.equal(theme.resolveTheme('light'), 'light');
  assert.equal(theme.resolveTheme('dark'), 'dark');
});

test('resolveTheme reads prefers-color-scheme when mode is system', () => {
  const themeDark = loadThemeModule({
    window: { matchMedia: () => ({ matches: true }) },
    document: undefined,
  });
  assert.equal(themeDark.resolveTheme('system'), 'dark');

  const themeLight = loadThemeModule({
    window: { matchMedia: () => ({ matches: false }) },
    document: undefined,
  });
  assert.equal(themeLight.resolveTheme('system'), 'light');
});

test('applyThemeMode updates documentElement attributes and persists mode', () => {
  const attrs = {};
  const storage = {};
  const mockDocument = {
    documentElement: {
      style: {},
      setAttribute(k, v) {
        attrs[k] = v;
      },
    },
  };
  const mockWindow = {
    localStorage: {
      getItem(k) {
        return Object.prototype.hasOwnProperty.call(storage, k) ? storage[k] : null;
      },
      setItem(k, v) {
        storage[k] = String(v);
      },
    },
    matchMedia: () => ({ matches: false }),
  };

  const theme = loadThemeModule({ window: mockWindow, document: mockDocument });
  const resolved = theme.applyThemeMode('dark');

  assert.equal(resolved, 'dark');
  assert.equal(attrs['data-theme'], 'dark');
  assert.equal(mockDocument.documentElement.style.colorScheme, 'dark');
  assert.equal(theme.getStoredThemeMode(), 'dark');
});

test('getStoredThemeMode falls back to light for invalid or throwing localStorage', () => {
  const themeInvalid = loadThemeModule({
    window: { localStorage: { getItem: () => 'sepia' } },
    document: undefined,
  });
  assert.equal(themeInvalid.getStoredThemeMode(), 'light');

  const themeThrowing = loadThemeModule({
    window: {
      localStorage: {
        getItem() {
          throw new Error('Storage blocked');
        },
      },
    },
    document: undefined,
  });
  assert.equal(themeThrowing.getStoredThemeMode(), 'light');
});

test('index.css defines CRM brand, dark theme, motion tokens, and prefers-reduced-motion', () => {
  const css = fs.readFileSync(path.join(__dirname, '../src/index.css'), 'utf8');

  const requiredTokens = [
    '--brand-navy: #263F63',
    '--brand-blue: #4778B8',
    '--brand-cyan: #55C7E8',
    ":root[data-theme='dark']",
    '--motion-instant: 100ms',
    '--motion-fast: 150ms',
    '--motion-normal: 250ms',
    '--motion-medium: 350ms',
    '--motion-slow: 500ms',
    '--motion-data: 800ms',
    '--motion-ease-standard: cubic-bezier(0.2, 0, 0, 1)',
    '--motion-ease-enter: cubic-bezier(0, 0, 0.2, 1)',
    '--motion-ease-exit: cubic-bezier(0.4, 0, 1, 1)',
    '--motion-distance-xs: 4px',
    '--motion-distance-sm: 8px',
    '--motion-distance-md: 16px',
    '--motion-scale-pressed: 0.97',
    '--motion-scale-enter: 0.98',
    '@media (prefers-reduced-motion: reduce)',
  ];

  for (const token of requiredTokens) {
    assert.ok(css.includes(token), `Missing required token/rule in index.css: ${token}`);
  }
});

test('CSS stylesheets do not use bouncy spring curves, form-shake, or decorative infinite sparkles', () => {
  const srcDir = path.join(__dirname, '../src');
  const cssFiles = [];

  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(fullPath);
      else if (entry.name.endsWith('.css')) cssFiles.push(fullPath);
    }
  }
  walk(srcDir);

  assert.ok(cssFiles.length > 0);
  for (const file of cssFiles) {
    const content = fs.readFileSync(file, 'utf8');
    assert.ok(
      !content.includes('cubic-bezier(0.34, 1.56, 0.64, 1)'),
      `Bouncy spring curve found in ${file}`
    );
    assert.ok(
      !content.includes('@keyframes shake'),
      `Forbidden @keyframes shake found in ${file}`
    );
    assert.ok(
      !content.includes('@keyframes sparkleRotate'),
      `Forbidden infinite sparkleRotate found in ${file}`
    );
  }
});


import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';

const code = ts.transpileModule(
  readFileSync(new URL('./monthlyTooltipUtils.ts', import.meta.url), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } },
).outputText;

const { computeFloatingTooltipPosition } = await import(
  `data:text/javascript;base64,${Buffer.from(code).toString('base64')}`
);

test('flips tooltip below when anchor is near top sticky header and clamps inside viewport horizontally', () => {
  const topRowAnchor = { top: 150, bottom: 177, left: 1180, width: 15 };
  const tipSize = { width: 320, height: 130 };
  const viewport = { width: 1280, height: 800 };

  const pos = computeFloatingTooltipPosition(topRowAnchor, tipSize, viewport);
  assert.equal(pos.placement, 'bottom');
  assert.equal(pos.top, 187);
  // Clamped to viewport.width - tipSize.width - 12 = 948
  assert.equal(pos.left, 948);
  assert.ok(pos.left + tipSize.width <= viewport.width - 12);
  // Arrow still points at anchor center (1187.5 - 948 = 239.5)
  assert.equal(pos.arrowLeft, 239.5);
});

test('places tooltip above anchor when space above is sufficient and clamps near left edge', () => {
  const lowerRowAnchor = { top: 420, bottom: 447, left: 20, width: 15 };
  const tipSize = { width: 280, height: 120 };
  const viewport = { width: 1280, height: 800 };

  const pos = computeFloatingTooltipPosition(lowerRowAnchor, tipSize, viewport);
  assert.equal(pos.placement, 'top');
  assert.equal(pos.top, 290);
  assert.equal(pos.left, 12);
  assert.equal(pos.arrowLeft, 15.5);
});

test('MonthlyTab renders day tooltip through React portal with wrapping CSS', () => {
  const tsx = readFileSync(new URL('./MonthlyTab.tsx', import.meta.url), 'utf8');
  const css = readFileSync(new URL('./MonthlyTab.css', import.meta.url), 'utf8');

  assert.ok(tsx.includes('createPortal('));
  assert.ok(tsx.includes('mini-day-tooltip--portal'));
  assert.match(css, /\.mini-day-tooltip\s*\{[^}]*position:\s*fixed/s);
  assert.match(css, /\.mini-day-tooltip\s*\{[^}]*white-space:\s*normal/s);
});

test('attendance tabs have vertical spacing between layout sections and table rows', () => {
  const indexCss = readFileSync(new URL('../index.css', import.meta.url), 'utf8');
  const appCss = readFileSync(new URL('../App.css', import.meta.url), 'utf8');

  assert.match(indexCss, /\.crm-tab-panel\s*\{[^}]*display:\s*flex;\s*flex-direction:\s*column;\s*gap:\s*20px;/s);
  assert.match(appCss, /\.attendance-table\s*\{[^}]*border-spacing:\s*0\s+8px;/s);
  assert.match(appCss, /\.daily-table\s*\{[^}]*border-spacing:\s*0\s+8px;/s);
  assert.match(appCss, /\.attendance-table:not\(\.daily-table\)\s+th:nth-child\(6\)/);
  assert.match(appCss, /\.daily-table\s+th:nth-child\(3\)[^}]*min-width:\s*120px/s);
});


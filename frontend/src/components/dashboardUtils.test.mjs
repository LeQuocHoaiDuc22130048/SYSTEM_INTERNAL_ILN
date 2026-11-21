import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';

const code = ts.transpileModule(
  readFileSync(new URL('./dashboardUtils.ts', import.meta.url), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } },
).outputText;

const {
  toLocalDateStr,
  getCurvedPath,
  computeDashboardDateRange,
  formatFilterSummaryText,
  getComboChartHeading,
} = await import(`data:text/javascript;base64,${Buffer.from(code).toString('base64')}`);

test('getComboChartHeading omits technical (Cột & Đường) suffix across all presets', () => {
  const range = { startDateStr: '2026-11-12', endDateStr: '2026-11-18' };
  const refDate = new Date('2026-11-18T09:00:00');

  assert.equal(getComboChartHeading('7days', range, undefined, undefined, refDate).title, 'Thống kê đơn 7 ngày qua');
  assert.equal(getComboChartHeading('today', range, undefined, undefined, refDate).title, 'Thống kê đơn hôm nay theo khung giờ');
  assert.equal(getComboChartHeading('month', range, 2026, 11, refDate).title, 'Thống kê đơn Tháng 11/2026');

  for (const preset of ['today', '7days', 'month', 'custom']) {
    const { title, subtitle } = getComboChartHeading(preset, range, 2026, 11, refDate);
    assert.ok(!title.includes('(Cột & Đường)'), `unexpected technical suffix in ${title}`);
    assert.ok(subtitle.length > 0);
  }
});

test('computeDashboardDateRange computes 7days, month, today, and normalizes reversed custom dates', () => {
  const ref = new Date('2026-11-18T10:30:00');

  const today = computeDashboardDateRange('today', '', '', undefined, undefined, ref);
  assert.equal(today.startDateStr, '2026-11-18');
  assert.equal(today.endDateStr, '2026-11-18');

  const sevenDays = computeDashboardDateRange('7days', '', '', undefined, undefined, ref);
  assert.equal(sevenDays.startDateStr, '2026-11-12');
  assert.equal(sevenDays.endDateStr, '2026-11-18');

  const month = computeDashboardDateRange('month', '', '', 2026, 2, ref);
  assert.equal(month.startDateStr, '2026-02-01');
  assert.equal(month.endDateStr, '2026-02-28');

  const customReversed = computeDashboardDateRange('custom', '2026-11-15', '2026-11-10', undefined, undefined, ref);
  assert.equal(customReversed.startDateStr, '2026-11-10');
  assert.equal(customReversed.endDateStr, '2026-11-15');
  assert.equal(formatFilterSummaryText(customReversed, 'custom'), '10/11/2026 - 15/11/2026 (6 ngày)');
});

test('getCurvedPath and toLocalDateStr format valid outputs', () => {
  assert.equal(toLocalDateStr(new Date(2026, 0, 5)), '2026-01-05');
  assert.equal(getCurvedPath([]), '');
  assert.equal(getCurvedPath([{ x: 10, y: 20 }]), 'M 10 20');
  assert.match(getCurvedPath([{ x: 0, y: 10 }, { x: 30, y: 40 }]), /^M 0 10 C /);
});

test('dashboard KPI layout, shortened copy, unified empty states, and header filter contract', () => {
  const tsx = readFileSync(new URL('./DashboardTab.tsx', import.meta.url), 'utf8');
  const css = readFileSync(new URL('./DashboardTab.css', import.meta.url), 'utf8');
  const headerTsx = readFileSync(new URL('./Header.tsx', import.meta.url), 'utf8');
  const headerCss = readFileSync(new URL('./Header.css', import.meta.url), 'utf8');
  const fieldWorkTsx = readFileSync(new URL('./FieldWorkRequests.tsx', import.meta.url), 'utf8');

  // 2x4 grid on desktop and explicit aspect-ratio on chart SVG
  assert.match(css, /grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)/);
  assert.match(css, /aspect-ratio:\s*680\s*\/\s*260/);
  assert.match(css, /stat-card--attention/);

  // Shortened KPI copy without redundant lines
  assert.ok(!tsx.includes('Tổng số đơn trong khoảng lọc'));
  assert.ok(!tsx.includes('Đơn cần theo dõi'));
  assert.ok(!tsx.includes('Đơn đã sửa xong'));
  assert.ok(!tsx.includes('Bo mạch có sẵn trong kho'));
  assert.ok(!tsx.includes('Đã check-in hệ thống'));
  assert.ok(tsx.includes('Đang sửa chữa'));
  assert.ok(tsx.includes('Trong kho'));
  assert.ok(tsx.includes('Đã check-in'));

  // Unified empty states across chart and lists, plus header time filters & collapsible field-work banner
  assert.ok(tsx.includes('empty-state--chart'));
  assert.ok(tsx.includes('empty-state-icon'));
  assert.ok(headerTsx.includes('header-dashboard-filters'));
  assert.ok(headerTsx.includes('header-mobile-select'));
  assert.ok(headerTsx.includes("import './Header.css'"));
  assert.ok(headerCss.includes('.header-preset-buttons'));
  assert.ok(headerCss.includes('.header-preset-btn.active'));
  assert.ok(headerCss.includes('.header-mobile-filter-row'));
  assert.match(css, /\.stat-card\s*\{[^}]*min-height:\s*92px/s);
  assert.doesNotMatch(css, /@media\s*\(max-width:\s*380px\)\s*\{\s*\.dashboard-stats-grid\s*\{\s*grid-template-columns:\s*1fr/);
  assert.ok(fieldWorkTsx.includes('field-work-banner'));
  assert.ok(fieldWorkTsx.includes('if (admin && (!loaded || (requests.length === 0 && !error))) {\n    return null;'));
});


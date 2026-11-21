import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import ts from 'typescript';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';

const utilsCode = ts.transpileModule(
  readFileSync(new URL('./deviceUtils.ts', import.meta.url), 'utf8'),
  { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 } },
).outputText;

const {
  isStaticIpAddress,
  getDeviceConnectionCategory,
  detectDevicePlatform,
  computeDeviceStats,
  filterDevices,
} = await import(`data:text/javascript;base64,${Buffer.from(utilsCode).toString('base64')}`);

const sampleDevices = [
  {
    id: '1',
    deviceId: 'ATT-FREAD-01',
    name: 'Face ID Cổng Chính',
    type: 'ATTENDANCE',
    status: 'ONLINE',
    ipAddress: '192.168.1.50',
    lastActiveAt: '2026-11-21T06:00:00Z',
    pingMs: 12,
    version: '1.2.0',
  },
  {
    id: '2',
    deviceId: 'WH-SCAN-01',
    name: 'Máy quét Kho A',
    type: 'WAREHOUSE',
    status: 'OFFLINE',
    ipAddress: '192.168.1.61',
    lastActiveAt: '2026-11-20T06:00:00Z',
    pingMs: 0,
    version: '1.0.5',
  },
  {
    id: '3',
    deviceId: 'TECH-TAB-02',
    name: 'Tablet Kỹ Thuật 02',
    type: 'TECHNICIAN',
    status: 'ONLINE',
    ipAddress: '10.0.0.22',
    lastActiveAt: '2026-11-21T06:10:00Z',
    pingMs: 42,
    version: '2.0.1',
  },
  {
    id: '4',
    deviceId: 'flutter-mobile-emp1',
    name: 'Nguyễn Văn A (iPhone 15)',
    type: 'EMPLOYEE',
    status: 'ONLINE',
    ipAddress: 'Mobile / App',
    lastActiveAt: '2026-11-21T06:12:00Z',
    pingMs: 28,
    version: '1.1.25',
  },
  {
    id: '5',
    deviceId: 'android-tech-05',
    name: 'Trần Văn B (Samsung)',
    type: 'TECHNICIAN',
    status: 'OFFLINE',
    ipAddress: 'Mobile / App',
    lastActiveAt: '2026-11-21T05:00:00Z',
    pingMs: 0,
    version: '1.1.25',
  },
  {
    id: '6',
    deviceId: 'web-browser-admin',
    name: 'Admin Web Console',
    type: 'ADMIN',
    status: 'OFFLINE',
    ipAddress: 'Mobile / App',
    lastActiveAt: '2026-11-21T04:00:00Z',
    pingMs: 0,
    version: '0.0.0',
  },
];

test('isStaticIpAddress distinguishes static IPs from Mobile / App labels', () => {
  assert.equal(isStaticIpAddress('192.168.1.50'), true);
  assert.equal(isStaticIpAddress('10.0.0.1:8080'), true);
  assert.equal(isStaticIpAddress('fe80::1'), true);
  assert.equal(isStaticIpAddress('Mobile / App'), false);
  assert.equal(isStaticIpAddress('999.999.1.1'), false);
  assert.equal(isStaticIpAddress(''), false);
  assert.equal(isStaticIpAddress(null), false);
});

test('getDeviceConnectionCategory separates hardware static IPs from Mobile/App sessions', () => {
  assert.equal(getDeviceConnectionCategory(sampleDevices[0]), 'HARDWARE');
  assert.equal(getDeviceConnectionCategory(sampleDevices[2]), 'HARDWARE');
  assert.equal(getDeviceConnectionCategory(sampleDevices[3]), 'MOBILE_APP');
  assert.equal(getDeviceConnectionCategory(sampleDevices[4]), 'MOBILE_APP');
  assert.equal(getDeviceConnectionCategory(sampleDevices[5]), 'MOBILE_APP');
});

test('detectDevicePlatform resolves iOS, Android, Web, and fallback Mobile', () => {
  assert.equal(detectDevicePlatform(sampleDevices[3]), 'IOS');
  assert.equal(detectDevicePlatform(sampleDevices[4]), 'ANDROID');
  assert.equal(detectDevicePlatform(sampleDevices[5]), 'WEB');
  assert.equal(
    detectDevicePlatform({ ipAddress: 'Mobile / App', deviceId: 'session-99', name: 'Tài khoản NV', version: '1.0' }),
    'MOBILE',
  );
  assert.equal(
    detectDevicePlatform({ ipAddress: 'Mobile / App', deviceId: 'x', name: 'x', version: '1.0', platform: 'IOS' }),
    'IOS',
  );
});

test('computeDeviceStats and filterDevices handle KPI status, connection, role, search, and latency sort', () => {
  const stats = computeDeviceStats(sampleDevices);
  assert.deepEqual(stats, {
    total: 6,
    online: 3,
    offline: 3,
    avgLatency: 27,
    hardwareCount: 3,
    mobileAppCount: 3,
  });

  const offlineOnly = filterDevices(sampleDevices, {
    searchTerm: '',
    selectedType: 'ALL',
    connectionFilter: 'ALL',
    statusFilter: 'OFFLINE',
  });
  assert.equal(offlineOnly.length, 3);
  assert.ok(offlineOnly.every((d) => d.status === 'OFFLINE'));

  const mobileTechOnly = filterDevices(sampleDevices, {
    searchTerm: '',
    selectedType: 'TECHNICIAN',
    connectionFilter: 'MOBILE_APP',
    statusFilter: 'ALL',
  });
  assert.deepEqual(mobileTechOnly.map((d) => d.id), ['5']);

  const iosSearch = filterDevices(sampleDevices, {
    searchTerm: 'ios',
    selectedType: 'ALL',
    connectionFilter: 'ALL',
    statusFilter: 'ALL',
  });
  assert.deepEqual(iosSearch.map((d) => d.id), ['4']);

  const sortedOnline = filterDevices(sampleDevices, {
    searchTerm: '',
    selectedType: 'ALL',
    connectionFilter: 'ALL',
    statusFilter: 'ONLINE',
    sortByLatency: true,
  });
  assert.deepEqual(sortedOnline.map((d) => d.id), ['3', '4', '1']);
});

test('DeviceTab layout & CSS contract: 4-col KPI priority, grouped compact tablet panel, platform icons, switch & confirm dialog', () => {
  const deviceTsx = readFileSync(new URL('./DeviceTab.tsx', import.meta.url), 'utf8');
  const deviceCss = readFileSync(new URL('./DeviceTab.css', import.meta.url), 'utf8');
  const tabletTsx = readFileSync(new URL('./AttendanceTabletPanel.tsx', import.meta.url), 'utf8');
  const tabletCss = readFileSync(new URL('./AttendanceTabletPanel.css', import.meta.url), 'utf8');

  // 1. KPI cards appear before AttendanceTabletPanel and use 4-column desktop grid
  const kpiIndex = deviceTsx.indexOf('<div className="device-stats-grid"');
  const tabletIndex = deviceTsx.indexOf('<AttendanceTabletPanel');
  assert.ok(kpiIndex > -1 && tabletIndex > -1 && kpiIndex < tabletIndex);
  assert.match(deviceCss, /\.device-stats-grid\s*\{[^}]*grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)/s);

  // 2. Grouped Attendance & Approval panel with 2 tabs & compact empty bar (no empty table when 0 items)
  assert.ok(tabletTsx.includes('Quản lý Chấm công &amp; Phê duyệt'));
  assert.ok(tabletTsx.includes('Tablet đăng ký ({devices.length})'));
  assert.ok(tabletTsx.includes('Lượt chờ duyệt ({totalReviews})'));
  assert.ok(tabletTsx.includes('tablet-empty-banner'));
  assert.ok(tabletCss.includes('.tablet-panel.is-compact'));

  // 3. Hardware vs Mobile/App filters + platform badges
  assert.ok(deviceTsx.includes('Thiết bị vật lý (IP cố định)'));
  assert.ok(deviceTsx.includes('Thiết bị cá nhân / App (Mobile)'));
  assert.ok(deviceTsx.includes('<PlatformBadge'));

  // 4. Switch + Confirm dialog when turning off + overflow menu (⋮)
  assert.ok(deviceTsx.includes('role="switch"'));
  assert.ok(deviceTsx.includes('Xác nhận tắt / ngắt kết nối'));
  assert.ok(deviceTsx.includes('Xem chi tiết'));
  assert.ok(deviceTsx.includes('Ping lại'));
  assert.ok(deviceTsx.includes('Ngắt kết nối'));
  assert.doesNotMatch(deviceCss, /\.device-card\s*\{[^}]*overflow:\s*hidden/s);
});

test('AttendanceTabletPanel renders compact empty state without empty table headers on initial SSR', async () => {
  // Verify SSR of AttendanceTabletPanel when user is ADMIN (initial loading state is compact/collapsed)
  const panelSource = readFileSync(new URL('./AttendanceTabletPanel.tsx', import.meta.url), 'utf8');
  const transpiled = ts.transpileModule(panelSource, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true },
  }).outputText;

  const { createRequire } = await import('node:module');
  const require = createRequire(import.meta.url);
  const lucide = require('lucide-react');
  const mod = { exports: {} };
  const localRequire = (name) => {
    if (name === 'react') return React;
    if (name === 'lucide-react') return lucide;
    if (name.endsWith('.css')) return {};
    if (name === '../utils/attendanceDevices') {
      return {
        canManageTablets: (r) => r === 'ADMIN' || r === 'SUPER_ADMIN',
        listTablets: async () => [],
        listTabletReviews: async () => ({ content: [], number: 0, last: true, totalElements: 0 }),
        tabletAction: async () => ({}),
        reviewAction: async () => ({}),
        tabletEvents: async () => [],
        tabletStatus: () => '',
        reviewDetail: async () => ({}),
      };
    }
    return require(name);
  };
  new Function('require', 'module', 'exports', transpiled)(localRequire, mod, mod.exports);

  const html = renderToStaticMarkup(
    React.createElement(mod.exports.AttendanceTabletPanel, {
      role: 'ADMIN',
      canStatus: true,
      canReview: true,
      showToast: () => {},
    }),
  );

  assert.ok(html.includes('Quản lý Chấm công &amp; Phê duyệt'));
  assert.ok(html.includes('Tablet đăng ký (0)'));
  assert.ok(html.includes('Lượt chờ duyệt (0)'));
  assert.ok(!html.includes('<table'), 'Should not render empty tables when collapsed/empty');
});


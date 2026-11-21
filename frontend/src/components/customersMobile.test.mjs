import { readFileSync } from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';

test('CustomersTab optimizes mobile actions, single-line subtabs, 2-col filters, and mobile card list', () => {
  const tsx = readFileSync(new URL('./CustomersTab.tsx', import.meta.url), 'utf8');
  const css = readFileSync(new URL('./CustomersTab.css', import.meta.url), 'utf8');

  // Shortened subtab labels with nowrap
  assert.ok(tsx.includes('Danh sách ({customerPage?.totalElements || 0})'));
  assert.ok(tsx.includes('Đánh giá CSKH'));
  assert.match(css, /\.customers-subtab-btn\s*\{[^}]*white-space:\s*nowrap/s);

  // Mobile action layout: full-width add button + icon-only refresh + portal button
  assert.ok(tsx.includes('customers-actions-group'));
  assert.ok(tsx.includes('btn-portal-support'));
  assert.match(css, /\.customers-actions-group\s+\.btn-primary-add\s*\{[^}]*width:\s*100%/s);

  // Mobile filters grid (2 columns for dropdowns) and hidden duplicate title
  assert.match(css, /\.customers-title-area\s*\{\s*display:\s*none;\s*\}/);
  assert.match(css, /\.customers-filters-row\s*\{[^}]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/s);

  // Mobile card list with tel: link, address, customerCode, and action buttons
  assert.ok(tsx.includes('customers-mobile-list'));
  assert.ok(tsx.includes('customer-mobile-card'));
  assert.ok(tsx.includes('href={`tel:${c.phone}`}'));
  assert.match(css, /@media\s*\(max-width:\s*767px\)[\s\S]*\.customers-mobile-list\s*\{[^}]*display:\s*flex/s);
});


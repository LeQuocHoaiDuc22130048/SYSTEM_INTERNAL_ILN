const test = require('node:test');
const assert = require('node:assert/strict');

const BUSINESS_ACRONYMS = new Set([
  'TNHH',
  'CP',
  'JSC',
  'MTV',
  'TM',
  'DV',
  'TMDV',
  'XNK',
  'KCN',
  'PCCC',
  'EVN',
  'ABB',
  'VFD',
  'PLC',
  'SCADA',
  'CNC',
  'IT',
  'AI',
  'LLC',
  'LTD',
  'CO',
  'CORP',
  'INC',
]);

const LOWERCASE_COMPANY_WORDS = new Set(['ty', 'và', 'của', 'tại', 'cho']);

function normalizeWord(word, isCompany, index) {
  if (!word) return '';
  if (word.includes('-')) {
    return word.split('-').map((p) => normalizeWord(p, isCompany, index)).join('-');
  }
  const upper = word.toUpperCase();
  if (isCompany && BUSINESS_ACRONYMS.has(upper)) {
    return upper;
  }
  const lower = word.toLowerCase();
  if (isCompany && index > 0 && LOWERCASE_COMPANY_WORDS.has(lower)) {
    return lower;
  }
  const first = word.charAt(0).toUpperCase();
  const rest = word.slice(1).toLowerCase();
  return first + rest;
}

function normalizeCustomerName(name, type = 'INDIVIDUAL') {
  if (!name || typeof name !== 'string') return '';
  const trimmed = name.trim().replace(/\s+/g, ' ');
  if (!trimmed) return '';
  const isCompany = type === 'COMPANY';
  return trimmed.split(' ').map((w, idx) => normalizeWord(w, isCompany, idx)).join(' ');
}

test('normalizes individual customer names with IME uppercase glitches', () => {
  assert.equal(normalizeCustomerName('anh dŨNG', 'INDIVIDUAL'), 'Anh Dũng');
  assert.equal(normalizeCustomerName('NguyÊn LƯƠNG TuÂn', 'INDIVIDUAL'), 'Nguyên Lương Tuân');
  assert.equal(normalizeCustomerName('nguyen van a', 'INDIVIDUAL'), 'Nguyen Van A');
  assert.equal(normalizeCustomerName('NGUYEN VAN A', 'INDIVIDUAL'), 'Nguyen Van A');
  assert.equal(normalizeCustomerName('trần bá tường', 'INDIVIDUAL'), 'Trần Bá Tường');
});

test('normalizes company customer names and preserves acronyms and natural words', () => {
  assert.equal(
    normalizeCustomerName('công ty tnhh mtv giải pháp abb', 'COMPANY'),
    'Công ty TNHH MTV Giải Pháp ABB'
  );
  assert.equal(
    normalizeCustomerName('công ty cp tm-dv năng lượng xanh', 'COMPANY'),
    'Công ty CP TM-DV Năng Lượng Xanh'
  );
  assert.equal(
    normalizeCustomerName('  Công ty A  ', 'COMPANY'),
    'Công ty A'
  );
});

test('handles empty and whitespace-only inputs gracefully', () => {
  assert.equal(normalizeCustomerName(''), '');
  assert.equal(normalizeCustomerName('   '), '');
  assert.equal(normalizeCustomerName(null), '');
});

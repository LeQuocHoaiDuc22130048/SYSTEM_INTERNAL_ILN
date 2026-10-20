export const BUSINESS_ACRONYMS = new Set([
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

/**
 * Normalizes a single token/word:
 * - If hyphenated (e.g. TM-DV), normalizes each sub-part.
 * - If type is COMPANY and word is a known business acronym, preserves uppercase.
 * - If type is COMPANY and word is a minor connector (e.g. 'ty', 'và'), lowercases it.
 * - Otherwise, title-cases: first char capitalized, rest lowercased.
 *   This eliminates Vietnamese IME (UniKey / EVKey) uppercase glitches like:
 *   'dŨNG' -> 'Dũng', 'TuÂn' -> 'Tuân', 'NguyÊn' -> 'Nguyễn', 'LƯƠNG' -> 'Lương'
 */
function normalizeWord(word: string, isCompany: boolean, index: number): string {
  if (!word) return '';

  if (word.includes('-')) {
    return word
      .split('-')
      .map((part) => normalizeWord(part, isCompany, index))
      .join('-');
  }

  const upper = word.toUpperCase();
  if (BUSINESS_ACRONYMS.has(upper)) {
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

/**
 * Cleans and formats customer names:
 * - Removes leading/trailing and redundant internal whitespace.
 * - Fixes accidental all-lowercase typing (e.g. 'anh dũng' -> 'Anh Dũng').
 * - Fixes Telex/IME capitalization glitches (e.g. 'anh dŨNG' -> 'Anh Dũng', 'NguyÊn LƯƠNG TuÂn' -> 'Nguyễn Lương Tuân').
 * - Formats company names naturally (e.g. 'Công ty TNHH MTV Giải Pháp ABB').
 */
export function normalizeCustomerName(
  name: string,
  type: 'INDIVIDUAL' | 'COMPANY' = 'INDIVIDUAL'
): string {
  if (!name || typeof name !== 'string') return '';
  const trimmed = name.trim().replace(/\s+/g, ' ');
  if (!trimmed) return '';

  const isCompany = type === 'COMPANY';
  return trimmed
    .split(' ')
    .map((w, idx) => normalizeWord(w, isCompany, idx))
    .join(' ');
}

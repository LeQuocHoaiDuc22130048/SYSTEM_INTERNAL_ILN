const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const ExcelJS = require('exceljs');

// Load the browser exporter without adding a separate test runner.
const source = fs.readFileSync(path.join(__dirname, '../src/utils/excel.ts'), 'utf8');
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, esModuleInterop: true },
}).outputText;
const exporter = { exports: {} };
new Function('require', 'module', 'exports', compiled)(require, exporter, exporter.exports);

test('Excel preserves late half days and Sunday attendance credits', async (t) => {
  let blob;
  t.mock.method(URL, 'createObjectURL', (value) => { blob = value; return 'blob:test'; });
  t.mock.method(URL, 'revokeObjectURL', () => {});
  const originalDocument = global.document;
  global.document = {
    createElement: () => ({ setAttribute() {}, click() {} }),
    body: { appendChild() {}, removeChild() {} },
  };
  t.after(() => {
    if (originalDocument === undefined) delete global.document;
    else global.document = originalDocument;
  });

  for (const [status, sundayDays, weekdayDays, dailyWorkDays] of [
    ['p', 1.5, 1], ['l', 1.5, 1], ['m', 1.5, 0.5],
    ['c', 1.5, 0.5], ['o', 1.5, 1.5], ['h', 0, 0], ['a', 0, 0], ['f', '', ''],
    ['l', 1.5, 0.5, { 7: 1.5, 8: 0.5 }],
    ['p', 1.5, 1, { 7: 1.5, 8: 1 }],
  ]) {
    // June 7, 2026 is Sunday; June 8 is Monday; June 14 is an empty Sunday.
    const dailyPattern = 'aaaaaa' + status + status + 'aaaaahaaaaaahaaaaaahaa';
    await exporter.exports.exportAttendanceExcel([{ name: 'Test', dailyPattern, dailyWorkDays }], 6, 2026);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(Buffer.from(await blob.arrayBuffer()));
    const row = workbook.worksheets[0].getRow(4);
    assert.equal(row.getCell(9).value, sundayDays, `Sunday status ${status}`);
    assert.equal(row.getCell(10).value, weekdayDays, `Monday status ${status}`);
    assert.equal(row.getCell(16).value, 0, 'Sunday without attendance');
    assert.equal(row.getCell(33).value.formula, 'SUM(C4:AF4)');
  }

  await exporter.exports.exportAttendanceExcel([{
    name: 'Late afternoon shift',
    dailyPattern: 'a'.repeat(20) + 'l' + 'a'.repeat(9),
    dailyWorkDays: { 21: 0.5 },
  }], 9, 2026);
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(Buffer.from(await blob.arrayBuffer()));
  const day21 = workbook.worksheets[0].getRow(4).getCell(23);
  assert.equal(day21.value, 0.5, 'September 21 late afternoon shift');
  assert.equal(day21.numFmt, '0.0');
  assert.equal(day21.fill.fgColor.argb, 'FFFF0000', 'Late attendance remains highlighted');

  for (const [checkIn, status, label] of [
    ['13:30', 'PRESENT', 'Đúng giờ'], ['08:30', 'OVERTIME', 'Tăng ca'],
  ]) {
    await exporter.exports.exportEmployeeHistoryExcel({
      employee: { name: 'Test', dept: 'Test' },
      summary: { workDays: checkIn === '13:30' ? 1 : 1.5, totalHours: 0, lateCount: 0 },
      days: [{ date: '2026-06-08', dayOfWeek: 'T2', status, events: [
        { type: 'CHECK_IN', logTime: checkIn, source: 'FACE', note: '' },
        { type: 'CHECK_OUT', logTime: '21:00', source: 'FACE', note: '' },
      ] }],
    }, 6, 2026);
    const detailWorkbook = new ExcelJS.Workbook();
    await detailWorkbook.xlsx.load(Buffer.from(await blob.arrayBuffer()));
    assert.equal(detailWorkbook.worksheets[0].getCell('G9').value, label);
  }
});

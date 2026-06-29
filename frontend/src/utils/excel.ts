import ExcelJS from 'exceljs';
import type { EmployeeMonthlyStats } from '../mockData';

/**
 * Xuất danh sách chấm công tháng ra file Excel (.xlsx) định dạng lịch chi tiết (Calendar-style)
 * khớp với giao diện yêu cầu trong hình ảnh.
 */
export async function exportAttendanceExcel(
  employees: EmployeeMonthlyStats[],
  month: number,
  year: number
): Promise<void> {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet(`Chấm công Tháng ${month.toString().padStart(2, '0')}`);

  // Đảm bảo luôn hiển thị lưới dòng kẻ (Gridlines) trong Excel
  worksheet.views = [{ showGridLines: true }];

  const daysInMonth = new Date(year, month, 0).getDate();

  // 1. Cấu hình cột: STT, Họ tên, 1..N cột ngày, Tổng cộng, Ghi chú
  const columns: any[] = [
    { key: 'stt', width: 5 },
    { key: 'name', width: 26 }
  ];

  for (let d = 1; d <= daysInMonth; d++) {
    columns.push({ key: `day_${d}`, width: 4 });
  }

  columns.push({ key: 'totalWorkDays', width: 14 });
  columns.push({ key: 'notes', width: 22 });

  worksheet.columns = columns;

  // Định nghĩa styles dùng chung
  const thinBorder: ExcelJS.Border = { style: 'thin', color: { argb: 'FF000000' } };
  const borderAllBlack: Partial<ExcelJS.Borders> = {
    top: thinBorder,
    left: thinBorder,
    bottom: thinBorder,
    right: thinBorder
  };

  const yellowFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFFFFF00' } // Vàng tươi cho Chủ Nhật (CN)
  };

  const greenFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFC2E0B4' } // Xanh lá pastel cho nghỉ phép (v)
  };

  const redFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFFF0000' } // Đỏ cho đi muộn (l) hoặc vắng không phép (a)
  };

  const startDayColIndex = 3; // Cột C (bắt đầu từ ngày 1)
  const endDayColIndex = 2 + daysInMonth; // Cột cuối cùng của ngày
  const totalColIndex = 2 + daysInMonth + 1; // Cột Tổng cộng
  const notesColIndex = 2 + daysInMonth + 2; // Cột Ghi chú

  // 2. TẠO HÀNG TIÊU ĐỀ 1: "Tháng MM" (Gộp từ cột C đến cột cuối cùng của ngày)
  const row1 = worksheet.getRow(1);
  row1.height = 25;

  worksheet.mergeCells(1, startDayColIndex, 1, endDayColIndex);
  const monthCell = row1.getCell(startDayColIndex);
  monthCell.value = `Tháng ${month.toString().padStart(2, '0')}`;
  monthCell.font = { name: 'Arial', size: 10, bold: true };
  monthCell.alignment = { vertical: 'middle', horizontal: 'center' };

  // Thêm viền cho toàn bộ vùng ngày ở dòng 1
  for (let col = startDayColIndex; col <= endDayColIndex; col++) {
    row1.getCell(col).border = borderAllBlack;
  }

  // 3. TẠO HÀNG TIÊU ĐỀ 2: "Ngày" & Các ngày 1..31 & "TỔNG CỘNG"
  const row2 = worksheet.getRow(2);
  row2.height = 22;

  // Ô B2: "Ngày"
  const dayHeaderCell = row2.getCell(2);
  dayHeaderCell.value = 'Ngày';
  dayHeaderCell.font = { name: 'Arial', size: 10, bold: true };
  dayHeaderCell.alignment = { vertical: 'middle', horizontal: 'center' };
  dayHeaderCell.border = borderAllBlack;

  const sundayColIndexes: number[] = [];

  // Các ngày 1..N
  for (let d = 1; d <= daysInMonth; d++) {
    const colIndex = 2 + d;
    const cell = row2.getCell(colIndex);
    cell.value = d;
    cell.font = { name: 'Arial', size: 10, bold: true };
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
    cell.border = borderAllBlack;

    // Đánh dấu cột Chủ Nhật
    const date = new Date(year, month - 1, d);
    if (date.getDay() === 0) {
      cell.fill = yellowFill;
      sundayColIndexes.push(colIndex);
    }
  }

  // Ô Tổng cộng ở hàng 2: "TỔNG CỘNG"
  const totalTitleCell = row2.getCell(totalColIndex);
  totalTitleCell.value = 'TỔNG CỘNG';
  totalTitleCell.font = { name: 'Arial', size: 10, bold: true };
  totalTitleCell.alignment = { vertical: 'middle', horizontal: 'center' };
  totalTitleCell.border = borderAllBlack;

  // 4. TẠO HÀNG TIÊU ĐỀ 3: "Thứ" & Các thứ T2..CN & "NGÀY CÔNG" & "Ghi Chú"
  const row3 = worksheet.getRow(3);
  row3.height = 22;

  // Ô B3: "Thứ"
  const weekdayHeaderCell = row3.getCell(2);
  weekdayHeaderCell.value = 'Thứ';
  weekdayHeaderCell.font = { name: 'Arial', size: 10, bold: true };
  weekdayHeaderCell.alignment = { vertical: 'middle', horizontal: 'center' };
  weekdayHeaderCell.border = borderAllBlack;

  const weekdayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  // Điền thứ T2..CN
  for (let d = 1; d <= daysInMonth; d++) {
    const colIndex = 2 + d;
    const cell = row3.getCell(colIndex);
    const date = new Date(year, month - 1, d);
    const dayOfWeek = date.getDay();
    cell.value = weekdayLabels[dayOfWeek];
    cell.font = { name: 'Arial', size: 10, bold: true };
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
    cell.border = borderAllBlack;

    if (dayOfWeek === 0) {
      cell.fill = yellowFill;
    }
  }

  // Ô Tổng cộng ở hàng 3: "NGÀY CÔNG"
  const workdayTitleCell = row3.getCell(totalColIndex);
  workdayTitleCell.value = 'NGÀY CÔNG';
  workdayTitleCell.font = { name: 'Arial', size: 10, bold: true };
  workdayTitleCell.alignment = { vertical: 'middle', horizontal: 'center' };
  workdayTitleCell.border = borderAllBlack;

  // Gộp cột Ghi chú ở dòng 2 và dòng 3 lại
  worksheet.mergeCells(2, notesColIndex, 3, notesColIndex);
  const notesTitleCell = row2.getCell(notesColIndex);
  notesTitleCell.value = 'Ghi Chú';
  notesTitleCell.font = { name: 'Arial', size: 10, bold: true };
  notesTitleCell.alignment = { vertical: 'middle', horizontal: 'center' };
  row2.getCell(notesColIndex).border = borderAllBlack;
  row3.getCell(notesColIndex).border = borderAllBlack;

  // Gộp ô STT ở cột A dòng 2 và 3
  worksheet.mergeCells(2, 1, 3, 1);
  row2.getCell(1).border = borderAllBlack;
  row3.getCell(1).border = borderAllBlack;

  // 5. TẠO CÁC HÀNG DỮ LIỆU NHÂN VIÊN (Dòng 4 trở đi)
  employees.forEach((emp, index) => {
    const currentRowNum = 4 + index;
    const row = worksheet.getRow(currentRowNum);
    row.height = 22;

    // Cột A: Số thứ tự (STT)
    const cellSTT = row.getCell(1);
    cellSTT.value = index + 1;
    cellSTT.font = { name: 'Arial', size: 10 };
    cellSTT.alignment = { vertical: 'middle', horizontal: 'center' };
    cellSTT.border = borderAllBlack;

    // Cột B: Họ và tên nhân viên
    const cellName = row.getCell(2);
    cellName.value = emp.name;
    cellName.font = { name: 'Arial', size: 10, bold: false };
    cellName.alignment = { vertical: 'middle', horizontal: 'center' }; // Center aligned names like screenshot
    cellName.border = borderAllBlack;

    // Điền dữ liệu chấm công hàng ngày
    for (let d = 1; d <= daysInMonth; d++) {
      const colIndex = 2 + d;
      const cell = row.getCell(colIndex);
      cell.border = borderAllBlack;
      cell.font = { name: 'Arial', size: 10 };
      cell.alignment = { vertical: 'middle', horizontal: 'center' };

      const isSunday = sundayColIndexes.includes(colIndex);
      if (isSunday) {
        cell.fill = yellowFill;
      }

      // Lấy trạng thái của ngày d
      const statusChar = emp.dailyPattern && d <= emp.dailyPattern.length 
        ? emp.dailyPattern[d - 1] 
        : 'f';

      if (statusChar === 'p') {
        cell.value = 1;
      } else if (statusChar === 'l') {
        // Đi muộn -> hiện số 1 trên nền đỏ
        cell.value = 1;
        cell.fill = redFill;
        cell.font = { name: 'Arial', size: 10, color: { argb: 'FFFFFFFF' } }; // Chữ trắng trên nền đỏ
      } else if (statusChar === 'a') {
        // Vắng không phép -> hiện số 1 trên nền đỏ
        cell.value = 1;
        cell.fill = redFill;
        cell.font = { name: 'Arial', size: 10, color: { argb: 'FFFFFFFF' } };
      } else if (statusChar === 'v') {
        // Nghỉ phép -> hiện số 0 trên nền xanh lá pastel
        cell.value = 0;
        cell.fill = greenFill;
        cell.font = { name: 'Arial', size: 10, color: { argb: 'FF000000' } };
      } else if (statusChar === 'o') {
        // Tăng ca -> mặc định 1.5 ngày công (nếu là CN thì màu chữ đỏ/cam trên nền vàng)
        cell.value = 1.5;
        if (isSunday) {
          cell.font = { name: 'Arial', size: 10, color: { argb: 'FFD66A00' }, bold: true }; // Màu chữ cam đậm
        } else {
          cell.font = { name: 'Arial', size: 10, bold: true };
        }
      } else {
        // Cuối tuần/lễ (h) hoặc tương lai (f): để trống
        cell.value = '';
      }

      // Cấu hình định dạng hiển thị cho số ngày công
      if (cell.value === 1.5 || cell.value === 0.5) {
        cell.numFmt = '0.0';
      } else if (cell.value === 1 || cell.value === 0) {
        cell.numFmt = '0';
      }
    }

    // Cột AH: TỔNG CỘNG NGÀY CÔNG (Sử dụng Công thức SUM động của Excel)
    const totalCell = row.getCell(totalColIndex);
    const startColLetter = 'C';
    const endColLetter = worksheet.getColumn(endDayColIndex).letter;
    
    totalCell.value = {
      formula: `SUM(${startColLetter}${currentRowNum}:${endColLetter}${currentRowNum})`
    };
    totalCell.font = { name: 'Arial', size: 10, bold: true };
    totalCell.alignment = { vertical: 'middle', horizontal: 'center' };
    totalCell.border = borderAllBlack;
    totalCell.numFmt = '0.0';

    // Cột AI: Ghi Chú
    const notesCell = row.getCell(notesColIndex);
    notesCell.value = emp.name === 'Nguyễn Kim Thy' ? 'Làm việc Online' : '';
    notesCell.font = { name: 'Arial', size: 9 };
    notesCell.alignment = { vertical: 'middle', horizontal: 'left' };
    notesCell.border = borderAllBlack;
  });

  // 6. Xuất file và tự động tải xuống
  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob(
    [buffer],
    { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
  );

  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `BangChamCong_Thang_${month.toString().padStart(2, '0')}_${year}.xlsx`);

  document.body.appendChild(link);
  link.click();

  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

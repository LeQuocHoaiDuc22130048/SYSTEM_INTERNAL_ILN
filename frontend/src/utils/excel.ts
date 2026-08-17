import ExcelJS from 'exceljs';
import type { EmployeeMonthlyStats, EmployeeHistoryResponse } from '../mockData';


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
  columns.push({ key: 'notes', width: 45 });

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
  const notesColIndex = 2 + daysInMonth + 2; // Cột Ghi chú / Lý do cập nhật

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

  // 4. TẠO HÀNG TIÊU ĐỀ 3: "Thứ" & Các thứ T2..CN & "NGÀY CÔNG" & "Lý do cập nhật / Ghi Chú"
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

  // Gộp cột Lý do cập nhật / Ghi chú ở dòng 2 và dòng 3 lại
  worksheet.mergeCells(2, notesColIndex, 3, notesColIndex);
  const notesTitleCell = row2.getCell(notesColIndex);
  notesTitleCell.value = 'Lý do cập nhật / Ghi chú';
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

      const isWorked = statusChar === 'p' || statusChar === 'l' || statusChar === 'o';

      if (isWorked) {
        if (isSunday) {
          cell.value = 1.5;
          cell.fill = yellowFill;
          cell.font = { name: 'Arial', size: 10, color: { argb: 'FFD66A00' }, bold: true }; // Chữ cam đậm trên nền vàng
        } else {
          if (statusChar === 'o') {
            cell.value = 1.5;
            cell.font = { name: 'Arial', size: 10, bold: true };
          } else {
            cell.value = 1;
            if (statusChar === 'l') {
              cell.fill = redFill;
              cell.font = { name: 'Arial', size: 10, color: { argb: 'FFFFFFFF' } }; // Chữ trắng trên nền đỏ
            }
          }
        }
      } else {
        // Không đi làm (a, v, h)
        if (statusChar === 'f') {
          cell.value = '';
        } else {
          cell.value = 0;
          if (statusChar === 'v') {
            cell.fill = greenFill;
            cell.font = { name: 'Arial', size: 10, color: { argb: 'FF000000' } };
          } else if (statusChar === 'a') {
            cell.fill = redFill;
            cell.font = { name: 'Arial', size: 10, color: { argb: 'FFFFFFFF' } }; // Chữ trắng trên nền đỏ
          } else if (statusChar === 'h') {
            if (isSunday) {
              cell.fill = yellowFill;
            }
          }
        }
      }

      // Thêm ghi chú/comment tại ô ngày tương ứng nếu ngày đó có cập nhật lý do
      if (emp.updateNotes && emp.updateNotes[d]) {
        cell.note = `Ngày ${String(d).padStart(2, '0')}/${String(month).padStart(2, '0')}: ${emp.updateNotes[d]}`;
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

    // Cột AI: Lý do cập nhật & Ghi Chú
    const notesCell = row.getCell(notesColIndex);
    let finalNote = '';
    const noteItems: string[] = [];

    if (emp.name === 'Nguyễn Kim Thy') {
      noteItems.push('Làm việc Online');
    }

    if (emp.updateNotes && Object.keys(emp.updateNotes).length > 0) {
      Object.entries(emp.updateNotes)
        .sort(([d1], [d2]) => Number(d1) - Number(d2))
        .forEach(([d, reason]) => {
          noteItems.push(`Ngày ${String(d).padStart(2, '0')}: ${reason}`);
        });
    } else if (emp.notes && emp.notes.trim()) {
      noteItems.push(emp.notes.trim());
    }

    finalNote = noteItems.join('\n');

    notesCell.value = finalNote;
    notesCell.font = { name: 'Arial', size: 9 };
    notesCell.alignment = { vertical: 'middle', horizontal: 'left', wrapText: true };
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

/**
 * Xuất chi tiết bảng công của một nhân viên cụ thể theo tháng ra file Excel
 */
export async function exportEmployeeHistoryExcel(
  historyData: EmployeeHistoryResponse,
  month: number,
  year: number
): Promise<void> {
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet(`Chấm công ${historyData.employee.name}`);

  worksheet.views = [{ showGridLines: true }];

  // Cấu hình các cột
  worksheet.columns = [
    { header: 'STT', key: 'stt', width: 6 },
    { header: 'Ngày', key: 'date', width: 14 },
    { header: 'Thứ', key: 'dayOfWeek', width: 8 },
    { header: 'Check-in (Vào)', key: 'checkIn', width: 16 },
    { header: 'Check-out (Ra)', key: 'checkOut', width: 16 },
    { header: 'Thực làm (Giờ)', key: 'workHours', width: 16 },
    { header: 'Trạng thái', key: 'status', width: 18 },
    { header: 'Ghi chú', key: 'note', width: 30 }
  ];

  // Định nghĩa các styles
  const thinBorder: ExcelJS.Border = { style: 'thin', color: { argb: 'FF000000' } };
  const borderAllBlack: Partial<ExcelJS.Borders> = {
    top: thinBorder,
    left: thinBorder,
    bottom: thinBorder,
    right: thinBorder
  };

  const sundayFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFFFFFCE' } // Vàng nhạt cho Chủ Nhật
  };

  const lateFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFFFC7CE' } // Đỏ nhạt cho đi muộn/vắng
  };

  const leaveFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FFC6EFCE' } // Xanh lá nhạt cho nghỉ phép
  };

  const headerFill: ExcelJS.Fill = {
    type: 'pattern',
    pattern: 'solid',
    fgColor: { argb: 'FF1F4E78' } // Xanh dương đậm cho header
  };

  // Tạo các hàng trống phía trên để ghi thông tin chung
  worksheet.insertRow(1, []);
  worksheet.insertRow(2, []);
  worksheet.insertRow(3, []);
  worksheet.insertRow(4, []);
  worksheet.insertRow(5, []);
  worksheet.insertRow(6, []);

  // Tiêu đề: Dòng 2
  worksheet.mergeCells('A2:H2');
  const titleCell = worksheet.getCell('A2');
  titleCell.value = `BẢNG CHI TIẾT CHẤM CÔNG THÁNG ${month.toString().padStart(2, '0')}/${year}`;
  titleCell.font = { name: 'Arial', size: 16, bold: true, color: { argb: 'FF1F4E78' } };
  titleCell.alignment = { vertical: 'middle', horizontal: 'center' };

  // Thông tin nhân viên: Dòng 4 & 5
  worksheet.getCell('A4').value = 'Nhân viên:';
  worksheet.getCell('B4').value = historyData.employee.name;
  worksheet.getCell('B4').font = { bold: true };
  
  worksheet.getCell('D4').value = 'Phòng ban:';
  worksheet.getCell('E4').value = historyData.employee.dept;
  worksheet.getCell('E4').font = { bold: true };

  worksheet.getCell('A5').value = 'Ca làm việc:';
  worksheet.getCell('B5').value = `${historyData.employee.shiftName || 'Ca hành chính'} (${historyData.employee.shiftStart || '08:00'} - ${historyData.employee.shiftEnd || '17:00'})`;
  worksheet.getCell('B5').font = { bold: true };

  // Khối thống kê: Cột G & H
  worksheet.getCell('G4').value = 'Số ngày công:';
  worksheet.getCell('H4').value = `${historyData.summary.workDays} ngày`;
  worksheet.getCell('H4').font = { bold: true };

  worksheet.getCell('G5').value = 'Tổng giờ làm:';
  worksheet.getCell('H5').value = `${historyData.summary.totalHours} giờ`;
  worksheet.getCell('H5').font = { bold: true };

  worksheet.getCell('G6').value = 'Vào muộn:';
  worksheet.getCell('H6').value = `${historyData.summary.lateCount} lần`;
  worksheet.getCell('H6').font = { bold: true, color: { argb: 'FFFF0000' } };

  // Định dạng dòng tiêu đề bảng (Dòng 8)
  const headerRow = worksheet.getRow(8);
  headerRow.values = ['STT', 'Ngày', 'Thứ', 'Check-in (Vào)', 'Check-out (Ra)', 'Thực làm (Giờ)', 'Trạng thái', 'Ghi chú'];
  headerRow.height = 25;
  headerRow.eachCell((cell) => {
    cell.font = { name: 'Arial', size: 10, bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = headerFill;
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
    cell.border = borderAllBlack;
  });

  // Điền dữ liệu từ dòng 9 trở đi
  historyData.days.forEach((day, idx) => {
    const rowNum = 9 + idx;
    const row = worksheet.getRow(rowNum);
    row.height = 22;

    const checkInEvent = day.events.find(e => e.type === 'CHECK_IN');
    const checkOutEvent = day.events.find(e => e.type === 'CHECK_OUT');

    // Tính thời gian thực làm
    let hoursVal = 0;
    if (checkInEvent && checkOutEvent) {
      const [ih, im] = checkInEvent.logTime.split(':').map(Number);
      const [oh, om] = checkOutEvent.logTime.split(':').map(Number);
      hoursVal = parseFloat(((oh * 60 + om - (ih * 60 + im)) / 60).toFixed(2));
    }

    // Format ngày sang DD/MM/YYYY
    const dateFormatted = day.date.split('-').reverse().join('/');

    // Ánh xạ trạng thái
    const STATUS_MAP = {
      PRESENT: 'Đúng giờ',
      LATE: 'Đi muộn',
      ABSENT: 'Vắng',
      LEAVE: 'Nghỉ phép',
      HOLIDAY: 'Cuối tuần / Lễ',
      OVERTIME: 'Tăng ca',
      FUTURE: '-'
    };
    const statusLabel = STATUS_MAP[day.status as keyof typeof STATUS_MAP] || day.status;

    // Lấy ghi chú thủ công / lý do cập nhật
    const manualNotes = day.events
      .filter(e => e.source === 'MANUAL' && e.note)
      .map(e => e.note.trim());
    const otherNotes = day.events
      .filter(e => e.source !== 'MANUAL' && e.note && 
        !e.note.includes('Chấm công bằng nhận diện khuôn mặt') && 
        !e.note.includes('Chấm công bằng khuôn mặt'))
      .map(e => e.note.trim());

    let noteText = '';
    if (manualNotes.length > 0) {
      noteText = `Lý do cập nhật: ${Array.from(new Set(manualNotes)).join('; ')}`;
      if (otherNotes.length > 0) {
        noteText += ` (${Array.from(new Set(otherNotes)).join('; ')})`;
      }
    } else if (otherNotes.length > 0) {
      noteText = Array.from(new Set(otherNotes)).join('; ');
    }

    row.getCell(1).value = idx + 1;
    row.getCell(2).value = dateFormatted;
    row.getCell(3).value = day.dayOfWeek;
    row.getCell(4).value = checkInEvent ? checkInEvent.logTime : '--:--';
    row.getCell(5).value = checkOutEvent ? checkOutEvent.logTime : '--:--';
    row.getCell(6).value = hoursVal > 0 ? hoursVal : '';
    row.getCell(7).value = statusLabel;
    row.getCell(8).value = noteText;

    // Định dạng viền và căn chỉnh
    row.eachCell((cell, colIdx) => {
      cell.font = { name: 'Arial', size: 10 };
      cell.border = borderAllBlack;
      cell.alignment = { vertical: 'middle', horizontal: colIdx === 8 ? 'left' : 'center' };

      // Tô màu Chủ Nhật
      if (day.dayOfWeek === 'CN') {
        cell.fill = sundayFill;
      }
    });

    // Tô màu trạng thái đặc biệt
    const statusCell = row.getCell(7);
    if (day.status === 'LATE' || day.status === 'ABSENT') {
      statusCell.fill = lateFill;
      statusCell.font = { name: 'Arial', size: 10, color: { argb: 'FF9C0006' }, bold: true };
    } else if (day.status === 'LEAVE') {
      statusCell.fill = leaveFill;
      statusCell.font = { name: 'Arial', size: 10, color: { argb: 'FF006100' }, bold: true };
    }
  });

  // Xuất file
  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob(
    [buffer],
    { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
  );

  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `BangCong_ChiTiet_${historyData.employee.name.replace(/\s+/g, '')}_Thang_${month.toString().padStart(2, '0')}_${year}.xlsx`);

  document.body.appendChild(link);
  link.click();

  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}


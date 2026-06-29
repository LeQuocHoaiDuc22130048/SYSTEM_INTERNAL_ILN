import type { EmployeeMonthlyStats } from '../mockData';

/**
 * Xuất danh sách chấm công tháng ra file CSV và tự động tải xuống.
 * Tách side-effect DOM manipulation ra khỏi component.
 */
export function exportAttendanceCsv(
  employees: EmployeeMonthlyStats[],
  month: number,
  year: number
): void {
  let csvContent = '\ufeff'; // BOM for UTF-8
  csvContent += 'Mã NV,Họ tên,Phòng ban,Ngày làm chuẩn,Đủ công,Đi muộn,Vắng KP,Tổng giờ,Nghỉ phép\n';

  employees.forEach((emp) => {
    csvContent += `${emp.employeeCode},${emp.name},${emp.dept},22,${emp.workDays},${emp.lateCount},${emp.absentDays},${emp.totalHours},${emp.leavedays}\n`;
  });

  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.setAttribute('href', url);
  link.setAttribute('download', `ChamCong_Thang_${month}_${year}.csv`);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

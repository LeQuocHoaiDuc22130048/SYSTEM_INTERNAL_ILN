export type TimeRangePreset = 'today' | '7days' | 'month' | 'custom';

export interface DashboardDateRange {
  startDateStr: string;
  endDateStr: string;
  start: Date;
  end: Date;
}

/** Chuyển Date sang YYYY-MM-DD theo múi giờ địa phương */
export const toLocalDateStr = (date: Date): string => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

/** Tạo đường cong Bezier SVG mượt mà qua các điểm tọa độ */
export const getCurvedPath = (points: { x: number; y: number }[]): string => {
  if (points.length === 0) return '';
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`;
  let d = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = points[i];
    const p1 = points[i + 1];
    const cx1 = Math.round(p0.x + (p1.x - p0.x) / 3);
    const cy1 = Math.round(p0.y);
    const cx2 = Math.round(p0.x + (2 * (p1.x - p0.x)) / 3);
    const cy2 = Math.round(p1.y);
    d += ` C ${cx1} ${cy1}, ${cx2} ${cy2}, ${p1.x} ${p1.y}`;
  }
  return d;
};

/** Tính toán khoảng ngày bắt đầu và kết thúc từ bộ lọc Dashboard */
export const computeDashboardDateRange = (
  rangeType: TimeRangePreset,
  customStartDate: string,
  customEndDate: string,
  currentYear?: number,
  currentMonth?: number,
  referenceDate: Date = new Date()
): DashboardDateRange => {
  const todayStr = toLocalDateStr(referenceDate);
  let startDateStr = todayStr;
  let endDateStr = todayStr;

  if (rangeType === 'today') {
    startDateStr = todayStr;
    endDateStr = todayStr;
  } else if (rangeType === '7days') {
    const start = new Date(referenceDate);
    start.setDate(referenceDate.getDate() - 6);
    startDateStr = toLocalDateStr(start);
    endDateStr = todayStr;
  } else if (rangeType === 'month') {
    const y = currentYear || referenceDate.getFullYear();
    const m = currentMonth || (referenceDate.getMonth() + 1);
    startDateStr = `${y}-${String(m).padStart(2, '0')}-01`;
    const lastDay = new Date(y, m, 0).getDate();
    endDateStr = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  } else if (rangeType === 'custom') {
    let s = customStartDate || todayStr;
    let e = customEndDate || todayStr;
    if (s > e) {
      const tmp = s;
      s = e;
      e = tmp;
    }
    startDateStr = s;
    endDateStr = e;
  }

  return {
    startDateStr,
    endDateStr,
    start: new Date(startDateStr + 'T00:00:00'),
    end: new Date(endDateStr + 'T23:59:59.999'),
  };
};

/** Nhãn tóm tắt khoảng thời gian đang lọc */
export const formatFilterSummaryText = (
  dateRange: DashboardDateRange,
  rangeType: TimeRangePreset
): string => {
  const formatVi = (s: string) => {
    const parts = s.split('-');
    if (parts.length === 3) return `${parts[2]}/${parts[1]}/${parts[0]}`;
    return s;
  };
  if (rangeType === 'today') {
    return `Hôm nay: ${formatVi(dateRange.startDateStr)}`;
  }
  const diffDays = Math.max(
    1,
    Math.round((dateRange.end.getTime() - dateRange.start.getTime()) / (1000 * 60 * 60 * 24))
  );
  return `${formatVi(dateRange.startDateStr)} - ${formatVi(dateRange.endDateStr)} (${diffDays} ngày)`;
};

/** Tiêu đề và mô tả cho biểu đồ thống kê đơn theo bộ lọc thời gian */
export const getComboChartHeading = (
  rangeType: TimeRangePreset,
  dateRange: Pick<DashboardDateRange, 'startDateStr' | 'endDateStr'>,
  currentYear?: number,
  currentMonth?: number,
  referenceDate: Date = new Date()
): { title: string; subtitle: string } => {
  if (rangeType === 'today') {
    return {
      title: 'Thống kê đơn hôm nay theo khung giờ',
      subtitle: 'Phân bố đơn phát sinh trong các khung giờ làm việc hôm nay',
    };
  }
  if (rangeType === '7days') {
    return {
      title: 'Thống kê đơn 7 ngày qua',
      subtitle: 'Theo dõi tồn đọng, đang xử lý và sản lượng hoàn thành mỗi ngày',
    };
  }
  if (rangeType === 'month') {
    const y = currentYear || referenceDate.getFullYear();
    const m = currentMonth || (referenceDate.getMonth() + 1);
    return {
      title: `Thống kê đơn Tháng ${m}/${y}`,
      subtitle: 'Tiến độ xử lý đơn sửa chữa theo từng ngày trong tháng',
    };
  }
  return {
    title: `Thống kê đơn tùy chỉnh (${dateRange.startDateStr} → ${dateRange.endDateStr})`,
    subtitle: 'Biểu đồ phân tích đơn sửa chữa theo khoảng thời gian đã chọn',
  };
};


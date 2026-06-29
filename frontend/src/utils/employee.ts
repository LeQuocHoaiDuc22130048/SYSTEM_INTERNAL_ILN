import type { EmployeeMonthlyStats, DailyStatusChar } from '../mockData';

/**
 * Lấy 2 chữ cái đầu từ họ tên để hiển thị avatar.
 * Ưu tiên lấy chữ đầu của 2 từ cuối trong tên.
 */
export function getAvatarLetters(name: string): string {
  const parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return (parts[parts.length - 2][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return name.slice(0, 2).toUpperCase();
}

/**
 * Lấy ký tự trạng thái trong ngày từ dailyPattern của nhân viên.
 * dateStr định dạng: "YYYY-MM-DD"
 */
export function getDailyStatusFromPattern(
  emp: EmployeeMonthlyStats,
  dateStr: string
): DailyStatusChar | '' {
  const parts = dateStr.split('-');
  if (parts.length !== 3) return '';
  const day = parseInt(parts[2], 10);
  if (emp.dailyPattern && day >= 1 && day <= emp.dailyPattern.length) {
    return emp.dailyPattern[day - 1] as DailyStatusChar;
  }
  return '';
}

/**
 * Chuẩn hóa response lịch sử: chuyển type 'IN'→'CHECK_IN', 'OUT'→'CHECK_OUT'
 * để thống nhất với enum HistoryEvent['type'].
 */
export function normalizeHistoryResponse(data: any): any {
  if (!data?.days) return data;
  return {
    ...data,
    days: data.days.map((day: any) => ({
      ...day,
      events: day.events.map((evt: any) => ({
        ...evt,
        type: evt.type === 'IN' ? 'CHECK_IN' : evt.type === 'OUT' ? 'CHECK_OUT' : evt.type,
      })),
    })),
  };
}

/** Map ký tự trạng thái ngày → nhãn tiếng Việt hiển thị trong mini-bar */
export const DAILY_STATUS_LABEL_MAP: Record<DailyStatusChar, string> = {
  p: 'Đủ công',
  l: 'Đi muộn',
  a: 'Vắng không phép',
  v: 'Nghỉ phép',
  h: 'Nghỉ lễ / Cuối tuần',
  o: 'Tăng ca',
  f: 'Chưa diễn ra',
};

/** Map ký tự trạng thái ngày → nhãn tiếng Anh hiển thị trong calendar */
export const CALENDAR_STATUS_LABEL_MAP: Record<DailyStatusChar, string> = {
  p: 'PRESENT',
  l: 'LATE',
  a: 'ABSENT',
  v: 'LEAVE',
  h: 'HOLIDAY',
  o: 'OT',
  f: 'FUTURE',
};

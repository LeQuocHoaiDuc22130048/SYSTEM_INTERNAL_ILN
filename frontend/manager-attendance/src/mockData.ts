export interface EmployeeMonthlyStats {
  id: string;
  name: string;
  employeeCode: string;
  dept: string;
  workDays: number;
  lateCount: number;
  absentDays: number;
  totalHours: number;
  overtimeHours: number;
  leavedays: number;
  dailyPattern: string; // p=present, l=late, a=absent, v=leave, h=holiday/weekend
}

export interface EmployeeInfo {
  id: string;
  name: string;
  dept: string;
  shiftName: string;
  shiftStart: string;
  shiftEnd: string;
}

export interface HistorySummary {
  workDays: number;
  totalHours: number;
  lateCount: number;
  absentDays: number;
  overtimeHours: number;
}

export interface HistoryEvent {
  logTime: string;
  type: 'CHECK_IN' | 'CHECK_OUT';
  source: 'FACE' | 'MANUAL' | 'QR';
  confidence: number;
  note: string;
}

export interface DailyHistoryLog {
  date: string;
  dayOfWeek: string;
  status: 'PRESENT' | 'LATE' | 'ABSENT' | 'LEAVE' | 'HOLIDAY' | 'OVERTIME';
  events: HistoryEvent[];
}

export interface EmployeeHistoryResponse {
  employee: EmployeeInfo;
  summary: HistorySummary;
  days: DailyHistoryLog[];
}

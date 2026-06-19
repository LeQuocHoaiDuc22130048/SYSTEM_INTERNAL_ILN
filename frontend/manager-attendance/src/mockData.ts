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
  status: 'PRESENT' | 'LATE' | 'ABSENT' | 'LEAVE' | 'HOLIDAY';
  events: HistoryEvent[];
}

export interface EmployeeHistoryResponse {
  employee: EmployeeInfo;
  summary: HistorySummary;
  days: DailyHistoryLog[];
}

export const mockEmployees: EmployeeMonthlyStats[] = [
  {
    id: "e1",
    name: "Nguyen Van Test",
    employeeCode: "IT-2025-001",
    dept: "IT",
    workDays: 20,
    lateCount: 2,
    absentDays: 1,
    totalHours: 162.5,
    overtimeHours: 4.5,
    leavedays: 1,
    dailyPattern: "hpaaapphpppplvphppppplhpppppvph"
  },
  {
    id: "e2",
    name: "Tran Thi HR",
    employeeCode: "HR-2025-002",
    dept: "HR",
    workDays: 21,
    lateCount: 0,
    absentDays: 0,
    totalHours: 168.0,
    overtimeHours: 0.0,
    leavedays: 1,
    dailyPattern: "hppppplhppplvphppppplhpppppvph"
  },
  {
    id: "e3",
    name: "Le Van Dev",
    employeeCode: "IT-2025-003",
    dept: "IT",
    workDays: 18,
    lateCount: 4,
    absentDays: 3,
    totalHours: 146.2,
    overtimeHours: 8.0,
    leavedays: 1,
    dailyPattern: "hpaaapphppllpvphppllaahpppppvph"
  },
  {
    id: "e4",
    name: "Phan Minh Admin",
    employeeCode: "ADM-2025-004",
    dept: "Administration",
    workDays: 22,
    lateCount: 1,
    absentDays: 0,
    totalHours: 176.5,
    overtimeHours: 2.0,
    leavedays: 0,
    dailyPattern: "hppppplhpppppvphppppplhpppppvph"
  },
  {
    id: "e5",
    name: "Vu Thi Sale",
    employeeCode: "SAL-2025-005",
    dept: "Sales",
    workDays: 19,
    lateCount: 3,
    absentDays: 2,
    totalHours: 152.0,
    overtimeHours: 1.5,
    leavedays: 1,
    dailyPattern: "hpaaapplhpppplvphpplpaahpppppvph"
  }
];

export const generateMockHistory = (employeeId: string, employeeName: string, dept: string): EmployeeHistoryResponse => {
  const daysInMonth = 30;
  const days: DailyHistoryLog[] = [];
  const empPattern = mockEmployees.find(e => e.id === employeeId)?.dailyPattern || "hppppplhpppppvphppppplhpppppvph";

  let workDays = 0;
  let lateCount = 0;
  let absentDays = 0;
  let totalHours = 0;
  let overtimeHours = 0;

  for (let d = 1; d <= daysInMonth; d++) {
    const dayOfWeekVal = new Date(2025, 5, d).getDay(); // June 2025 (month 5 is June in JS Date)
    const dows = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"];
    const dayOfWeek = dows[dayOfWeekVal];
    const dateStr = `2025-06-${d.toString().padStart(2, '0')}`;
    const char = empPattern[d - 1] || 'p';

    let status: DailyHistoryLog['status'] = 'PRESENT';
    const events: HistoryEvent[] = [];

    if (char === 'h') {
      status = 'HOLIDAY';
    } else if (char === 'a') {
      status = 'ABSENT';
      absentDays++;
    } else if (char === 'v') {
      status = 'LEAVE';
    } else {
      workDays++;
      const isLate = char === 'l';
      if (isLate) {
        status = 'LATE';
        lateCount++;
      }

      const checkInHour = isLate ? 8 : 7;
      const checkInMinute = isLate ? (20 + (d % 15)) : (45 + (d % 14));
      const checkOutHour = 17;
      const checkOutMinute = 5 + (d % 30);

      events.push({
        logTime: `${checkInHour.toString().padStart(2, '0')}:${checkInMinute.toString().padStart(2, '0')}`,
        type: 'CHECK_IN',
        source: d % 7 === 0 ? 'MANUAL' : 'FACE',
        confidence: 0.98,
        note: d % 7 === 0 ? 'Quyên quên chấm công' : ''
      });

      events.push({
        logTime: `${checkOutHour.toString().padStart(2, '0')}:${checkOutMinute.toString().padStart(2, '0')}`,
        type: 'CHECK_OUT',
        source: 'FACE',
        confidence: 0.99,
        note: checkOutMinute > 30 ? 'OT được duyệt' : ''
      });

      const workMinutes = (checkOutHour * 60 + checkOutMinute) - (checkInHour * 60 + checkInMinute);
      totalHours += workMinutes / 60;

      if (checkOutMinute > 0) {
        overtimeHours += checkOutMinute / 60;
      }
    }

    days.push({
      date: dateStr,
      dayOfWeek,
      status,
      events
    });
  }

  return {
    employee: {
      id: employeeId,
      name: employeeName,
      dept,
      shiftName: "Ca hành chính",
      shiftStart: "08:00",
      shiftEnd: "17:00"
    },
    summary: {
      workDays,
      totalHours: Math.round(totalHours * 10) / 10,
      lateCount,
      absentDays,
      overtimeHours: Math.round(overtimeHours * 10) / 10
    },
    days
  };
};

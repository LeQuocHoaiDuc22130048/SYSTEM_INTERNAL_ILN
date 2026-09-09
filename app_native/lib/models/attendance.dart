enum AttendanceStatus { onTime, late, absent }

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final String? checkIn;
  final String? checkOut;
  final AttendanceStatus status;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
  });

  String get statusLabel {
    switch (status) {
      case AttendanceStatus.onTime:
        return 'Đúng giờ';
      case AttendanceStatus.late:
        return 'Muộn';
      case AttendanceStatus.absent:
        return 'Vắng';
    }
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final employeeName = json['employeeName']?.toString() ?? '';
    final checkTime = _dateFromJson(json['checkTime']);
    final type = json['type']?.toString();
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeCode']?.toString() ??
          json['employeeId']?.toString() ??
          '',
      employeeName: employeeName.isEmpty ? 'Nhân viên' : employeeName,
      date: checkTime ?? DateTime.now(),
      checkIn: type == 'OUT' ? null : _timeLabel(checkTime),
      checkOut: type == 'OUT' ? _timeLabel(checkTime) : null,
      status: _statusFromJson(json),
    );
  }

  factory AttendanceRecord.fromDailyJson(Map<String, dynamic> json) {
    final records = json['records'];
    Map<String, dynamic>? firstRecord;
    if (records is List && records.isNotEmpty && records.first is Map) {
      firstRecord = Map<String, dynamic>.from(records.first as Map);
    }
    final checkIn = _dateFromJson(json['checkIn']);
    final checkOut = _dateFromJson(json['checkOut']);
    final date = _dateFromJson(json['date']) ?? checkIn ?? DateTime.now();
    return AttendanceRecord(
      id: firstRecord?['id']?.toString() ?? date.toIso8601String(),
      employeeId: firstRecord?['employeeCode']?.toString() ??
          firstRecord?['employeeId']?.toString() ??
          '',
      employeeName: firstRecord?['employeeName']?.toString() ?? 'Nhân viên',
      date: date,
      checkIn: _timeLabel(checkIn),
      checkOut: _timeLabel(checkOut),
      status: json['isLate'] == true
          ? AttendanceStatus.late
          : AttendanceStatus.onTime,
    );
  }

  static AttendanceStatus _statusFromJson(Map<String, dynamic> json) {
    if (json['isValid'] == false) return AttendanceStatus.absent;
    return AttendanceStatus.onTime;
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String? _timeLabel(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class AttendanceSummary {
  final double workDays;
  final int lateCount;
  final int absentDays;
  final double totalHours;
  final double overtimeHours;

  const AttendanceSummary({
    this.workDays = 0.0,
    this.lateCount = 0,
    this.absentDays = 0,
    this.totalHours = 0.0,
    this.overtimeHours = 0.0,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AttendanceSummary();
    return AttendanceSummary(
      workDays: (json['workDays'] as num?)?.toDouble() ?? 0.0,
      lateCount: (json['lateCount'] as num?)?.toInt() ?? 0,
      absentDays: (json['absentDays'] as num?)?.toInt() ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0.0,
      overtimeHours: (json['overtimeHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AttendanceHistoryEvent {
  final String id;
  final String time;
  final String type; // IN, OUT
  final String method; // FACE, MANUAL
  final double confidence;
  final String note;

  const AttendanceHistoryEvent({
    required this.id,
    required this.time,
    required this.type,
    required this.method,
    required this.confidence,
    required this.note,
  });

  factory AttendanceHistoryEvent.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryEvent(
      id: json['id']?.toString() ?? '',
      time: json['time']?.toString() ?? json['logTime']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      method: json['method']?.toString() ?? json['source']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      note: json['note']?.toString() ?? '',
    );
  }
}

class DailyHistoryLog {
  final int day;
  final String date;
  final String dow;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final double totalHours;
  final double overtimeHours;
  final String note;
  final List<AttendanceHistoryEvent> events;

  const DailyHistoryLog({
    required this.day,
    required this.date,
    required this.dow,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.totalHours = 0.0,
    this.overtimeHours = 0.0,
    this.note = '',
    this.events = const [],
  });

  factory DailyHistoryLog.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    final eventsList = <AttendanceHistoryEvent>[];
    if (rawEvents is List) {
      for (final e in rawEvents) {
        if (e is Map<String, dynamic>) {
          eventsList.add(AttendanceHistoryEvent.fromJson(e));
        }
      }
    }

    final rawDate = json['date']?.toString() ?? '';
    final parsedDate = DateTime.tryParse(rawDate);
    final dayVal = (json['day'] as num?)?.toInt() ?? parsedDate?.day ?? 0;

    String? inStr = json['checkIn']?.toString();
    String? outStr = json['checkOut']?.toString();
    if (inStr == null || inStr.isEmpty) {
      final inEvents = eventsList.where((e) => e.type == 'IN' || e.type == 'CHECK_IN');
      if (inEvents.isNotEmpty) {
        inStr = inEvents.first.time;
      }
    }
    if (outStr == null || outStr.isEmpty) {
      final outEvents = eventsList.where((e) => e.type == 'OUT' || e.type == 'CHECK_OUT');
      if (outEvents.isNotEmpty) {
        outStr = outEvents.last.time;
      }
    }

    final totalH = (json['totalHours'] as num?)?.toDouble() ?? 0.0;
    final otH = (json['overtimeHours'] as num?)?.toDouble() ?? 0.0;

    return DailyHistoryLog(
      day: dayVal,
      date: rawDate,
      dow: json['dow']?.toString() ?? json['dayOfWeek']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PRESENT',
      checkIn: inStr,
      checkOut: outStr,
      totalHours: totalH,
      overtimeHours: otH,
      note: json['note']?.toString() ?? '',
      events: eventsList,
    );
  }

  bool get hasCheckIn => checkIn != null && checkIn!.isNotEmpty;
  bool get hasCheckOut => checkOut != null && checkOut!.isNotEmpty;

  String get statusLabel {
    switch (status) {
      case 'OVERTIME':
        return 'Tăng ca';
      case 'HALF_DAY_MORNING':
        return 'Nửa ngày sáng';
      case 'HALF_DAY_AFTERNOON':
        return 'Nửa ngày chiều';
      case 'LATE':
        return 'Vào muộn';
      case 'EARLY_LEAVE':
        return 'Về sớm';
      case 'PRESENT':
        return 'Đủ công';
      case 'LEAVE':
        return 'Nghỉ phép';
      case 'ABSENT':
        return 'Vắng mặt';
      case 'HOLIDAY':
        return 'Nghỉ lễ / CN';
      case 'FUTURE':
        return 'Chưa tới';
      default:
        return status;
    }
  }
}

class EmployeeHistoryData {
  final String employeeId;
  final String employeeName;
  final String department;
  final AttendanceSummary summary;
  final List<DailyHistoryLog> days;

  const EmployeeHistoryData({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.summary,
    required this.days,
  });

  factory EmployeeHistoryData.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final daysList = <DailyHistoryLog>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        if (d is Map<String, dynamic>) {
          daysList.add(DailyHistoryLog.fromJson(d));
        }
      }
    }
    final emp = json['employee'] as Map<String, dynamic>?;
    return EmployeeHistoryData(
      employeeId: emp?['id']?.toString() ?? json['employeeId']?.toString() ?? '',
      employeeName: emp?['name']?.toString() ?? json['employeeName']?.toString() ?? '',
      department: emp?['dept']?.toString() ?? json['department']?.toString() ?? '',
      summary: AttendanceSummary.fromJson(json['summary'] as Map<String, dynamic>?),
      days: daysList,
    );
  }
}

class MyTodayAttendance {
  final DateTime? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int totalMinutes;
  final bool isLate;
  final bool isEarlyLeave;
  final String? shiftStart;
  final String? shiftEnd;

  const MyTodayAttendance({
    this.date,
    this.checkIn,
    this.checkOut,
    this.totalMinutes = 0,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.shiftStart,
    this.shiftEnd,
  });

  factory MyTodayAttendance.fromJson(Map<String, dynamic> json) {
    return MyTodayAttendance(
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      checkIn: DateTime.tryParse(json['checkIn']?.toString() ?? ''),
      checkOut: DateTime.tryParse(json['checkOut']?.toString() ?? ''),
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      isLate: json['isLate'] == true,
      isEarlyLeave: json['isEarlyLeave'] == true,
      shiftStart: json['shiftStart']?.toString(),
      shiftEnd: json['shiftEnd']?.toString(),
    );
  }

  String? get checkInTimeStr {
    if (checkIn == null) return null;
    final local = checkIn!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String? get checkOutTimeStr {
    if (checkOut == null) return null;
    final local = checkOut!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}


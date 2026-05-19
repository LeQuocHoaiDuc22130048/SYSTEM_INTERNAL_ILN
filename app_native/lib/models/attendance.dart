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

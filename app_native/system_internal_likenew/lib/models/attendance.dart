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
}

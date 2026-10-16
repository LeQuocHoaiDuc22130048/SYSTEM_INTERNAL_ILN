class AttendanceAuthorization {
  final Map<String, dynamic> lease;
  final DateTime serverTime;
  final int elapsedMillis;
  final int bootCount;
  const AttendanceAuthorization({
    required this.lease,
    required this.serverTime,
    required this.elapsedMillis,
    required this.bootCount,
  });
  DateTime get expiresAt =>
      DateTime.parse(lease['expiresAt'] as String).toUtc();
  bool canCapture(int elapsed, int boot) =>
      bootCount >= 0 &&
      boot == bootCount &&
      elapsed >= elapsedMillis &&
      serverTime
          .add(Duration(milliseconds: elapsed - elapsedMillis))
          .isBefore(expiresAt);
  DateTime captureTime(int elapsed, int boot) {
    if (!canCapture(elapsed, boot)) {
      throw StateError(
        'Quyền chấm công offline đã hết hạn. Kết nối lại server.',
      );
    }
    return serverTime.add(Duration(milliseconds: elapsed - elapsedMillis));
  }

  Map<String, dynamic> toJson() => {
    'lease': lease,
    'serverTime': serverTime.toIso8601String(),
    'elapsedMillis': elapsedMillis,
    'bootCount': bootCount,
  };
  factory AttendanceAuthorization.fromJson(Map<String, dynamic> value) =>
      AttendanceAuthorization(
        lease: Map<String, dynamic>.from(value['lease'] as Map),
        serverTime: DateTime.parse(value['serverTime'] as String),
        elapsedMillis: value['elapsedMillis'] as int,
        bootCount: value['bootCount'] as int,
      );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/services/attendance_authorization.dart';

void main() {
  test('24 hour boundary, wall clock independence, sleep and reboot', () {
    final start = DateTime.utc(2026, 10, 16);
    final policy = AttendanceAuthorization(
      lease: {
        'id': 'lease',
        'deviceId': 'device',
        'accountId': 'account',
        'issuedAt': start.toIso8601String(),
        'expiresAt': start.add(const Duration(hours: 24)).toIso8601String(),
        'signature': 'signature',
      },
      serverTime: start,
      elapsedMillis: 1000,
      bootCount: 7,
    );
    expect(policy.canCapture(1000 + 86400000 - 1, 7), isTrue);
    expect(policy.canCapture(1000 + 86400000, 7), isFalse);
    expect(policy.canCapture(1000, 8), isFalse);
    expect(policy.canCapture(999, 7), isFalse);
    expect(
      policy.captureTime(1000 + 3600000, 7),
      start.add(const Duration(hours: 1)),
    );
    final restored = AttendanceAuthorization.fromJson(policy.toJson());
    expect(restored.canCapture(1000 + 86400000, 7), isFalse);
  });
  test('unknown boot snapshot always fails closed', () {
    final now = DateTime.utc(2026);
    final p = AttendanceAuthorization(
      lease: {
        'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
      },
      serverTime: now,
      elapsedMillis: 0,
      bootCount: -1,
    );
    expect(p.canCapture(1, -1), isFalse);
  });
}

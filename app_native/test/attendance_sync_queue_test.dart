import 'dart:convert';
import 'package:system_inverter_likenew/services/attendance_queue_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/services/attendance_sync_outcome.dart';

void main() {
  test('legacy and other-account rows cannot starve current tablet queue', () {
    final rows = <Map<String, Object?>>[
      for (var i = 0; i < 25; i++) {'id': i, 'tablet_context': null},
      {
        'id': 30,
        'tablet_context': jsonEncode({'accountId': 'other', 'deviceId': 'd'}),
      },
      {
        'id': 31,
        'tablet_context': jsonEncode({'accountId': 'a', 'deviceId': 'd'}),
      },
    ];
    final eligible = AttendanceQueuePolicy.eligible(
      rows,
      accountId: 'a',
      deviceId: 'd',
    );
    expect(eligible.map((row) => row['id']), [31]);
  });

  test(
    'transient and unknown results preserve evidence and stay retryable',
    () {
      expect(
        AttendanceSyncOutcome.fromResult({'status': 'FAILED'}).terminal,
        isFalse,
      );
      expect(
        AttendanceSyncOutcome.fromResult({
          'status': 'NEW_STATUS',
        }).discardEvidence,
        isFalse,
      );
    },
  );
  test(
    'pending review requires a durable receipt before discarding local evidence',
    () {
      final unsafe = AttendanceSyncOutcome.fromResult({
        'status': 'PENDING_REVIEW',
      });
      expect(unsafe.discardEvidence, isFalse);
      final accepted = AttendanceSyncOutcome.fromResult({
        'status': 'PENDING_REVIEW',
        'reviewId': 'receipt',
      });
      expect(accepted.discardEvidence, isTrue);
      expect(accepted.state, 'PENDING_REVIEW');
      expect(accepted.recorded, isFalse);
    },
  );
  test(
    'nearby duplicate is accepted but is not reported as a new attendance record',
    () {
      final duplicate = AttendanceSyncOutcome.fromResult({
        'status': 'SKIPPED',
        'serverRecordId': 'record',
        'message': 'Duplicate employee timestamp within 2 minutes',
      });
      expect(duplicate.terminal, isTrue);
      expect(duplicate.recorded, isFalse);
    },
  );
}

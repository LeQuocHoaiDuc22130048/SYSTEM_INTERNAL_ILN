import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:system_inverter_likenew/services/attendance_clock.dart';
import 'package:system_inverter_likenew/services/database_service.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';

class ReceiptApi extends ApiClient {
  Map<String, dynamic>? sent;
  @override
  Future<dynamic> post(String path, {Object? body}) async {
    sent = Map<String, dynamic>.from(body as Map);
    final log = (sent!['logs'] as List).first as Map;
    return {
      'results': [
        {
          'localLogId': log['localLogId'],
          'status': 'PENDING_REVIEW',
          'reviewId': 'review-receipt',
        },
      ],
    };
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => [
    {'id': 'review-receipt', 'status': 'SYNCED', 'recordId': 'server-record'},
  ];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android clock includes boot identity and advances monotonically',
    (tester) async {
      final a = await AttendanceClock().snapshot();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final b = await AttendanceClock().snapshot();
      expect(a.boot, greaterThanOrEqualTo(0));
      expect(a.boot, b.boot);
      expect(b.elapsed, greaterThanOrEqualTo(a.elapsed + 20));
    },
  );
  testWidgets(
    'v10 queue migration preserves evidence and uses durable review receipts',
    (tester) async {
      final name = 'tablet-test-${DateTime.now().microsecondsSinceEpoch}.db';
      final path = p.join(await getDatabasesPath(), name);
      final old = await openDatabase(
        path,
        version: 10,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE employees(id TEXT PRIMARY KEY,name TEXT NOT NULL,backend_employee_id TEXT,model_name TEXT,updated_at TEXT)',
          );
          await db.execute(
            'CREATE TABLE attendance_logs(id INTEGER PRIMARY KEY AUTOINCREMENT,employee_id TEXT NOT NULL,employee_name TEXT NOT NULL,confidence REAL NOT NULL,checked_at TEXT NOT NULL,type TEXT NOT NULL,backend_employee_id TEXT,face_embedding TEXT,face_image_base64 TEXT,image_content_type TEXT,synced_at TEXT,sync_error TEXT)',
          );
        },
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await old.insert('attendance_logs', {
        'id': 1,
        'employee_id': 'employee',
        'employee_name': 'Employee',
        'confidence': .99,
        'checked_at': now,
        'type': 'IN',
        'backend_employee_id': 'employee-backend',
        'face_image_base64': 'original-photo',
        'image_content_type': 'image/jpeg',
      });
      await old.close();
      final service = DatabaseService(databaseName: name);
      try {
        var db = await service.database;
        var row = (await db.query('attendance_logs')).single;
        expect(row['id'], 1);
        expect(row['face_image_base64'], 'original-photo');
        expect(row['tablet_context'], isNull);
        expect(await service.transferLegacyForReview('account', 'device'), 1);
        row = (await db.query('attendance_logs')).single;
        final immutableId = row['local_log_id'];
        final context = jsonDecode(row['tablet_context'] as String) as Map;
        expect(context['originalAccountUnknown'], isTrue);
        expect(context.containsKey('leaseId'), isFalse);
        final api = ReceiptApi()
          ..attendanceAccountId = 'account'
          ..attendanceHeaders = () => {'X-Attendance-Device-Id': 'device'};
        expect(await service.syncPendingAttendanceLogs(api: api), 0);
        row = (await db.query('attendance_logs')).single;
        expect(row['sync_state'], 'PENDING_REVIEW');
        expect(row['review_id'], 'review-receipt');
        expect(row['face_image_base64'], isNull);
        expect(
          ((api.sent!['logs'] as List).single as Map)['localLogId'],
          immutableId,
        );
        await service.close();
        db = await service.database;
        expect(
          (await db.query('attendance_logs')).single['sync_state'],
          'PENDING_REVIEW',
        );
        await service.refreshTabletReviews(api: api);
        expect(
          (await db.query('attendance_logs')).single['sync_state'],
          'SYNCED',
        );
      } finally {
        await service.close();
        await deleteDatabase(path);
      }
    },
  );
}

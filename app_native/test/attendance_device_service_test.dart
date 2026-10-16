import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:system_inverter_likenew/services/attendance_device_service.dart';
import 'package:system_inverter_likenew/services/attendance_clock.dart';
import 'package:system_inverter_likenew/services/database_service.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';

class TestClock extends AttendanceClock {
  int elapsed = 1000;
  int boot = 7;
  @override
  Future<({int elapsed, int boot})> snapshot() async =>
      (elapsed: elapsed, boot: boot);
}

class QueueStub extends DatabaseService {
  @override
  Future<(int, int)> tabletQueueCounts(String account, String device) async =>
      (0, 0);
  @override
  Future<int> syncPendingAttendanceLogs({required ApiClient api}) async => 0;
  @override
  Future<void> refreshTabletReviews({required ApiClient api}) async {}
}

class TestApi extends ApiClient {
  late Future<dynamic> Function(String, Object?) handle;
  @override
  Future<dynamic> post(String path, {Object? body}) => handle(path, body);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 16);
  Map<String, dynamic> lease(String account) => {
    'id': 'lease-$account',
    'deviceId': 'device-$account',
    'accountId': account,
    'issuedAt': now.toIso8601String(),
    'expiresAt': now.add(const Duration(hours: 24)).toIso8601String(),
    'signature': 'signature',
  };
  Map<String, dynamic> beat(String account) => {
    'device': {'id': 'device-$account', 'status': 'APPROVED'},
    'serverTime': now.toIso8601String(),
    'lease': lease(account),
  };
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'test',
      version: '1',
      buildNumber: '1',
      buildSignature: 'test',
    );
    FlutterSecureStorage.setMockInitialValues({
      for (final a in ['a', 'b'])
        'tablet_session_$a': jsonEncode({
          'deviceId': 'device-$a',
          'secret': 'secret-$a',
          'device': {'status': 'APPROVED'},
          'authorization': {
            'lease': lease(a),
            'serverTime': now.toIso8601String(),
            'elapsedMillis': 1000,
            'bootCount': 7,
          },
        }),
    });
  });
  test(
    'offline timeout preserves cached lease but expiry and reboot block new capture',
    () async {
      final api = TestApi()
        ..handle = (path, body) async => throw ApiException(0, 'offline');
      final clock = TestClock();
      final service = AttendanceDeviceService(
        api,
        clock: clock,
        database: QueueStub(),
      );
      addTearDown(service.dispose);
      await service.start('a');
      expect(await service.canCapture(), isTrue);
      clock.elapsed += 86400000;
      expect(await service.canCapture(), isFalse);
      clock.elapsed = 1000;
      clock.boot = 8;
      expect(await service.canCapture(), isFalse);
    },
  );
  test(
    'permission rejection clears cached authorization and cannot fall back offline',
    () async {
      final api = TestApi()
        ..handle = (path, body) async => throw ApiException(403, 'blocked');
      final service = AttendanceDeviceService(
        api,
        clock: TestClock(),
        database: QueueStub(),
      );
      addTearDown(service.dispose);
      await service.start('a');
      expect(await service.canCapture(), isFalse);
      service.stop();
      api.handle = (path, body) async => throw ApiException(0, 'offline');
      await service.start('a');
      expect(await service.canCapture(), isFalse);
    },
  );
  test(
    'late old-account response cannot replace current-account authorization',
    () async {
      final delayed = Completer<dynamic>();
      final started = Completer<void>();
      final api = TestApi();
      api.handle = (path, body) {
        if (api.attendanceAccountId == 'a') {
          started.complete();
          return delayed.future;
        }
        return Future.value(beat('b'));
      };
      final service = AttendanceDeviceService(
        api,
        clock: TestClock(),
        database: QueueStub(),
      );
      addTearDown(service.dispose);
      final old = service.start('a');
      await started.future;
      await service.start('b');
      delayed.complete(beat('a'));
      await old;
      expect(service.accountId, 'b');
      expect((await service.captureContext())['accountId'], 'b');
      expect(service.authorization!.lease['accountId'], 'b');
    },
  );
}

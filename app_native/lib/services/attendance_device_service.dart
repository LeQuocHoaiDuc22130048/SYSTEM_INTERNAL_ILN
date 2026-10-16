import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/api_client.dart';
import 'attendance_authorization.dart';
import 'attendance_clock.dart';
import 'attendance_identifier.dart';
import 'database_service.dart';

class AttendanceDeviceService extends ChangeNotifier
    with WidgetsBindingObserver {
  final ApiClient api;
  final DatabaseService _database;
  final FlutterSecureStorage storage;
  final AttendanceClock clock;
  AttendanceDeviceService(
    this.api, {
    this.storage = const FlutterSecureStorage(),
    AttendanceClock? clock,
    DatabaseService? database,
  }) : clock = clock ?? AttendanceClock(),
       _database = database ?? DatabaseService();
  String? accountId, deviceId, _secret;
  Map<String, dynamic>? device;
  AttendanceAuthorization? authorization;
  String message = 'Đang xác nhận thiết bị';
  Timer? _timer;
  Future<void>? _refreshing;
  int _generation = 0;
  bool _observing = false;
  int pendingSync = 0, pendingReview = 0;
  Map<String, String> get headers => deviceId != null && _secret != null
      ? {
          'X-Attendance-Device-Id': deviceId!,
          'X-Attendance-Device-Secret': _secret!,
        }
      : {};
  Future<void> start(String account) async {
    if (accountId == account) return;
    stop();
    accountId = account;
    final generation = _generation;
    String? cached;
    try {
      cached = await storage.read(key: 'tablet_session_$account');
    } catch (_) {
      message = 'Không đọc được thông tin đăng ký thiết bị';
    }
    if (generation != _generation) return;
    if (cached != null) {
      try {
        final v = jsonDecode(cached) as Map<String, dynamic>;
        deviceId = v['deviceId'] as String?;
        _secret = v['secret'] as String?;
        device = v['device'] as Map<String, dynamic>?;
        if (v['authorization'] != null) {
          authorization = AttendanceAuthorization.fromJson(
            v['authorization'] as Map<String, dynamic>,
          );
        }
      } catch (_) {
        authorization = null;
      }
    }
    api.attendanceAccountId = account;
    api.attendanceHeaders = () => headers;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(refresh()),
    );
    await refresh();
  }

  void stop() {
    _generation++;
    _refreshing = null;
    pendingSync = 0;
    pendingReview = 0;
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    accountId = null;
    deviceId = null;
    _secret = null;
    device = null;
    authorization = null;
    api.attendanceAccountId = null;
    api.attendanceHeaders = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(refresh()),
      );
      unawaited(refresh());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() {
    if (accountId == null) return Future.value();
    final generation = _generation;
    return _refreshing ??= _refresh().whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> _refresh() async {
    final account = accountId;
    if (account == null) return;
    final generation = _generation;
    try {
      if (deviceId == null) {
        final key = 'tablet_identity_$account';
        String? encoded = await storage.read(key: key);
        Map<String, dynamic> identity;
        if (encoded == null) {
          identity = {
            'installationId': newAttendanceId(),
            'secret': base64UrlEncode(
              List<int>.generate(32, (_) => Random.secure().nextInt(256)),
            ).replaceAll('=', ''),
          };
          await storage.write(key: key, value: jsonEncode(identity));
        } else {
          identity = jsonDecode(encoded) as Map<String, dynamic>;
        }
        final info = await PackageInfo.fromPlatform();
        final native = await const MethodChannel(
          'attendance/device_clock',
        ).invokeMapMethod<String, dynamic>('snapshot');
        if (generation != _generation) return;
        final response = await api.post(
          '/api/v1/attendance/devices/register',
          body: {
            ...identity,
            'name': 'Tablet chấm công',
            'model': native?['model'] ?? 'Android',
            'osVersion': native?['osVersion'] ?? 'Android',
            'appVersion': info.version,
          },
        );
        if (generation != _generation) return;
        device = Map<String, dynamic>.from(response as Map);
        deviceId = device!['id'] as String;
        _secret = identity['secret'] as String;
        await _save(account);
      }
      if (generation != _generation) return;
      final counts = await _database.tabletQueueCounts(account, deviceId!);
      if (generation != _generation) return;
      pendingSync = counts.$1;
      pendingReview = counts.$2;
      final info = await PackageInfo.fromPlatform();
      // Baseline is sampled before the request: network latency can only shorten the lease.
      final snapshot = await clock.snapshot();
      if (generation != _generation) return;
      final response = await api.post(
        '/api/v1/attendance/devices/heartbeat',
        body: {'pendingCount': pendingSync, 'appVersion': info.version},
      );
      if (generation != _generation) return;
      final data = Map<String, dynamic>.from(response as Map);
      device = Map<String, dynamic>.from(data['device'] as Map);
      final lease = data['lease'];
      authorization = lease is Map
          ? AttendanceAuthorization(
              lease: Map<String, dynamic>.from(lease),
              serverTime: DateTime.parse(data['serverTime'] as String).toUtc(),
              elapsedMillis: snapshot.elapsed,
              bootCount: snapshot.boot,
            )
          : null;
      message = device!['status'] == 'APPROVED'
          ? 'Thiết bị đã được duyệt'
          : device!['status'] == 'BLOCKED'
          ? 'Thiết bị đã bị khóa'
          : 'Chờ admin duyệt thiết bị';
      await _save(account);
      if (generation != _generation) return;
      await _database.syncPendingAttendanceLogs(api: api);
      if (generation != _generation) return;
      await _database.refreshTabletReviews(api: api);
      if (generation != _generation) return;
      final updated = await _database.tabletQueueCounts(account, deviceId!);
      pendingSync = updated.$1;
      pendingReview = updated.$2;
    } on ApiException catch (e) {
      if (generation != _generation) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        authorization = null;
        await _save(account);
      }
      message = e.statusCode == 0
          ? 'Mất kết nối server; sử dụng quyền offline còn hạn'
          : e.message;
    } catch (_) {
      if (generation == _generation) {
        message =
            'Chưa xác nhận được server. Kiểm tra kết nối và quyền offline.';
      }
    }
    if (generation == _generation) notifyListeners();
  }

  Future<void> _save(String account) => storage.write(
    key: 'tablet_session_$account',
    value: jsonEncode({
      'deviceId': deviceId,
      'secret': _secret,
      'device': device,
      'authorization': authorization?.toJson(),
    }),
  );
  Future<Map<String, dynamic>> captureContext() async {
    final auth = authorization;
    final account = accountId;
    final id = deviceId;
    if (auth == null || account == null || id == null) {
      throw StateError(message);
    }
    final snapshot = await clock.snapshot();
    if (accountId != account ||
        deviceId != id ||
        !identical(authorization, auth)) {
      throw StateError('Phiên thiết bị đã thay đổi');
    }
    final captured = auth.captureTime(snapshot.elapsed, snapshot.boot);
    return {
      'accountId': account,
      'deviceId': id,
      'leaseId': auth.lease['id'],
      'leaseSignature': auth.lease['signature'],
      'checkTime': captured.toUtc().toIso8601String(),
    };
  }

  Future<int> transferLegacyForReview() async {
    final account = accountId, id = deviceId;
    if (account == null || id == null) {
      throw StateError('Thiết bị chưa đăng ký');
    }
    final count = await _database.transferLegacyForReview(account, id);
    await refresh();
    return count;
  }

  Future<void> revokeLocalAuthorization() async {
    authorization = null;
    message = 'Quyền thiết bị đã bị từ chối. Kết nối server để xác nhận.';
    final account = accountId;
    if (account != null) await _save(account);
    notifyListeners();
  }

  Future<bool> canCapture() async {
    try {
      await captureContext();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    stop();
    unawaited(_database.close());
    super.dispose();
  }
}

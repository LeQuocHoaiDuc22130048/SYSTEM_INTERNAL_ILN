import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/board.dart';
import '../models/repair_order.dart';
import '../models/user.dart';
import 'api_client.dart';

class BackendDataProvider extends ChangeNotifier {
  final ApiClient api;

  BackendDataProvider({required this.api});

  List<User> employees = [];
  List<User> pendingUsers = [];
  List<RepairOrder> repairOrders = [];
  List<Board> boards = [];
  List<AttendanceRecord> attendanceRecords = [];

  bool isLoading = false;
  String? error;

  Future<void> loadAll() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await Future.wait([
        loadEmployees(notify: false),
        loadPendingUsers(notify: false),
        loadRepairOrders(notify: false),
        loadBoards(notify: false),
        loadAttendance(notify: false),
      ]);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không thể tải dữ liệu từ backend.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEmployees({bool notify = true}) async {
    final data = await api.get(
      '/api/v1/employees',
      queryParameters: {'size': 200},
    );
    employees = _content(data).map(User.fromJson).toList();
    if (notify) notifyListeners();
  }

  Future<void> loadPendingUsers({bool notify = true}) async {
    final data = await api.get(
      '/api/v1/auth/pending',
      queryParameters: {'size': 200},
    );
    pendingUsers = _content(data).map(User.fromJson).toList();
    if (notify) notifyListeners();
  }

  Future<void> loadRepairOrders({bool notify = true}) async {
    final data = await api.get(
      '/api/v1/repair-orders',
      queryParameters: {'size': 200},
    );
    repairOrders = _content(data).map(RepairOrder.fromJson).toList();
    if (notify) notifyListeners();
  }

  Future<RepairOrder> createRepairOrder({
    required String customerName,
    required String customerPhone,
    required String deviceName,
    required String description,
  }) async {
    final data = await api.post(
      '/api/v1/repair-orders',
      body: {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'deviceName': deviceName,
        'description': description,
      },
    );
    return RepairOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<void> uploadRepairMedia(
    String orderId, {
    required Uint8List bytes,
    required String filename,
    required bool isVideo,
  }) async {
    await api.postMultipart(
      '/api/v1/repair-orders/$orderId/media',
      fields: {'type': isVideo ? 'VIDEO' : 'IMAGE'},
      filename: filename,
      bytes: bytes,
    );
  }

  Future<void> assignRepairOrder(
    String orderId, {
    required String technicianId,
    String? note,
    bool reload = true,
  }) async {
    await api.put(
      '/api/v1/repair-orders/$orderId/assign',
      body: {'technicianId': technicianId, 'note': note},
    );
    if (reload) await loadRepairOrders();
  }

  Future<void> updateRepairOrderStatus(
    String orderId, {
    required String status,
    String? note,
    bool reload = true,
  }) async {
    await api.patch(
      '/api/v1/repair-orders/$orderId/status',
      body: {'status': status, 'note': note},
    );
    if (reload) await loadRepairOrders();
  }

  Future<void> loadBoards({bool notify = true}) async {
    final data = await api.get(
      '/api/v1/boards',
      queryParameters: {'size': 200},
    );
    boards = _content(data).map(Board.fromJson).toList();
    if (notify) notifyListeners();
  }

  Future<void> loadAttendance({bool notify = true}) async {
    final data = await api.get('/api/v1/attendance/report');
    if (data is List) {
      attendanceRecords = data
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecord.fromDailyJson)
          .toList();
    } else {
      attendanceRecords = _content(
        data,
      ).map(AttendanceRecord.fromJson).toList();
    }
    if (notify) notifyListeners();
  }

  Future<void> approveUser(User user) async {
    await api.put(
      '/api/v1/auth/pending/${user.id}',
      body: {'action': 'APPROVE', 'note': null},
    );
    await loadPendingUsers();
  }

  Future<void> rejectUser(User user) async {
    await api.put(
      '/api/v1/auth/pending/${user.id}',
      body: {'action': 'REJECT', 'note': 'Từ chối từ ứng dụng'},
    );
    await loadPendingUsers();
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> data) async {
    await api.patch('/api/v1/employees/$id', body: data);
    await loadEmployees();
  }

  Future<void> enrollFace(
    String id, {
    required String faceImageBase64,
    required String imageContentType,
    List<Map<String, String>>? samples,
  }) async {
    await api.post(
      '/api/v1/employees/$id/face',
      body: {
        'faceImageBase64': faceImageBase64,
        'imageContentType': imageContentType,
        if (samples != null && samples.isNotEmpty) 'samples': samples,
      },
    );
    await loadEmployees();
  }

  Future<void> deleteFace(String id) async {
    await api.delete('/api/v1/employees/$id/face');
    await loadEmployees();
  }

  Future<void> deleteBoard(Board board) async {
    await api.delete('/api/v1/boards/${board.id}');
    await loadBoards();
  }

  List<Map<String, dynamic>> _content(dynamic data) {
    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is List) {
        return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return const [];
  }
}

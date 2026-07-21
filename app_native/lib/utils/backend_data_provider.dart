import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/board.dart';
import '../models/repair_device.dart';
import '../models/repair_order.dart';
import '../models/board_history_item.dart';
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

  Future<void> loadAll({bool isManagerOrAbove = false}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final futures = <Future>[
        loadRepairOrders(notify: false),
        loadBoards(notify: false),
      ];

      if (isManagerOrAbove) {
        futures.addAll([
          loadEmployees(notify: false),
          loadPendingUsers(notify: false),
          loadAttendance(notify: false),
        ]);
      }

      await Future.wait(futures);
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
    isLoading = true;
    error = null;
    if (notify) notifyListeners();

    try {
      final data = await api.get(
        '/api/v1/repair-orders',
        queryParameters: {'size': 200},
      );
      repairOrders = _content(data).map(RepairOrder.fromJson).toList();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không thể tải dữ liệu từ backend.';
    } finally {
      isLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<RepairOrder> createRepairOrder({
    required String customerName,
    String? customerPhone,
    required List<RepairDevice> devices,
  }) async {
    final data = await api.post(
      '/api/v1/repair-orders',
      body: {
        'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        'devices': devices.map((d) => d.toRequestJson()).toList(),
      },
    );
    return RepairOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateRepairOrder(
    String orderId, {
    required String customerName,
    String? customerPhone,
    required List<RepairDevice> devices,
    String? note,
    bool reload = true,
  }) async {
    await api.put(
      '/api/v1/repair-orders/$orderId',
      body: {
        'customerName': customerName,
        if (customerPhone != null && customerPhone.isNotEmpty)
          'customerPhone': customerPhone,
        'devices': devices.map((d) => d.toRequestJson()).toList(),
        'note': note,
      },
    );
    if (reload) await loadRepairOrders();
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

  Future<void> deleteRepairMedia(
    String orderId, {
    required String mediaId,
    bool reload = true,
  }) async {
    await api.delete('/api/v1/repair-orders/media/$mediaId');
    if (reload) await loadRepairOrders();
  }

  Future<void> assignRepairOrder(
    String orderId, {
    required List<String> technicianIds,
    String? note,
    bool reload = true,
  }) async {
    await api.put(
      '/api/v1/repair-orders/$orderId/assign',
      body: {
        'technicianIds': technicianIds,
        if (technicianIds.isNotEmpty) 'technicianId': technicianIds.first,
        'note': note,
      },
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

  Future<void> deleteRepairOrder(String orderId) async {
    await api.delete('/api/v1/repair-orders/$orderId');
    await loadRepairOrders();
  }

  Future<void> checkoutBoard(String boardId, {String? repairOrderId, String? note, bool reload = true}) async {
    await api.post(
      '/api/v1/boards/$boardId/checkout',
      body: {
        'repairOrderId': repairOrderId,
        'note': note,
      },
    );
    if (reload) await loadBoards();
  }

  Future<void> returnBoard(String boardId, {String? notes, bool reload = true}) async {
    await api.patch(
      '/api/v1/boards/$boardId/return',
      body: notes != null ? {'notes': notes} : null,
    );
    if (reload) await loadBoards();
  }

  Future<List<BoardHistoryItem>> getBoardHistory(String boardId) async {
    final data = await api.get('/api/v1/boards/$boardId/history');
    return _content(data).map(BoardHistoryItem.fromJson).toList();
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

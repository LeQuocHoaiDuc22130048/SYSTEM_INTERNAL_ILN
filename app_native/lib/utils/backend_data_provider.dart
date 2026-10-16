import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/board.dart';
import '../models/repair_device.dart';
import '../models/repair_order.dart';
import '../models/board_history_item.dart';
import '../models/user.dart';
import '../models/part_checkout.dart';
import '../models/part.dart';
import '../models/store_location.dart';
import '../models/app_banner.dart';
import '../models/customer.dart';
import 'api_client.dart';

class BackendDataProvider extends ChangeNotifier {
  final ApiClient api;
  int fieldWorkRevision = 0;

  BackendDataProvider({required this.api});

  List<User> employees = [];
  List<User> pendingUsers = [];
  List<RepairOrder> repairOrders = [];
  int repairOrdersTotal = 0;
  bool hasMoreRepairOrders = false;
  bool isLoadingMoreRepairOrders = false;
  String? repairOrdersPageError;
  int _repairOrdersPage = 0;
  int _repairOrdersPageSize = 200;
  int _repairOrdersGeneration = 0;
  List<Board> boards = [];
  List<User> repairAssignees = [];
  List<Part> parts = [];
  List<StoreLocation> locations = [];
  List<AttendanceRecord> attendanceRecords = [];
  List<AppBanner> banners = [];
  EmployeeHistoryData? myAttendanceHistory;
  MyTodayAttendance? myTodayAttendance;
  bool isLoadingMyAttendance = false;
  bool isLoadingBanners = false;

  bool isLoading = false;
  String? error;

  void clear() {
    employees = [];
    repairAssignees = [];
    pendingUsers = [];
    repairOrders = [];
    _repairOrdersGeneration++;
    _repairOrdersPageSize = 200;
    repairOrdersTotal = 0;
    hasMoreRepairOrders = false;
    isLoadingMoreRepairOrders = false;
    repairOrdersPageError = null;
    boards = [];
    parts = [];
    locations = [];
    attendanceRecords = [];
    banners = [];
    myAttendanceHistory = null;
    myTodayAttendance = null;
    isLoadingMyAttendance = false;
    isLoadingBanners = false;
    isLoading = false;
    error = null;
    notifyListeners();
  }

  Future<void> loadAll({bool isManagerOrAbove = false}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final futures = <Future>[
        loadRepairOrders(notify: false),
        loadBoards(notify: false),
        loadParts(notify: false),
        loadLocations(notify: false),
        loadBanners(notify: false),
      ];

      if (isManagerOrAbove) {
        futures.addAll([
          loadEmployees(notify: false),
          loadPendingUsers(notify: false),
          loadAttendance(notify: false),
        ]);
      } else {
        futures.add(loadMyAttendance(notify: false));
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

  Future<void> loadRepairAssignees() async {
    final data = await api.get('/api/v1/employees/repair-assignees');
    repairAssignees = _content(data).map(User.fromJson).toList();
    notifyListeners();
  }

  Future<void> loadPendingUsers({bool notify = true}) async {
    final data = await api.get(
      '/api/v1/auth/pending',
      queryParameters: {'size': 200},
    );
    pendingUsers = _content(data).map(User.fromJson).toList();
    if (notify) notifyListeners();
  }

  Future<void> loadRepairOrders({
    bool notify = true,
    int? pageSize,
  }) async {
    final requestedPageSize = pageSize ?? _repairOrdersPageSize;
    final generation = ++_repairOrdersGeneration;
    isLoadingMoreRepairOrders = false;
    repairOrdersPageError = null;
    isLoading = true;
    error = null;
    if (notify) notifyListeners();

    try {
      final data = await api.get(
        '/api/v1/repair-orders',
        queryParameters: {'page': 0, 'size': requestedPageSize},
      );
      if (generation != _repairOrdersGeneration) return;
      repairOrders = _content(data).map(RepairOrder.fromJson).toList();
      _repairOrdersPage = 0;
      _repairOrdersPageSize = requestedPageSize;
      _updateRepairOrdersPage(data);
      error = null;
    } on ApiException catch (e) {
      if (generation != _repairOrdersGeneration) return;
      error = e.message;
    } catch (_) {
      if (generation != _repairOrdersGeneration) return;
      error = 'Không thể tải dữ liệu từ backend.';
    } finally {
      if (generation == _repairOrdersGeneration) {
        isLoading = false;
        if (notify) notifyListeners();
      }
    }
  }

  void _updateRepairOrdersPage(dynamic data) {
    repairOrdersTotal = data is Map && data['totalElements'] is num
        ? (data['totalElements'] as num).toInt()
        : repairOrders.length;
    hasMoreRepairOrders = data is Map && data['last'] is bool
        ? data['last'] == false
        : repairOrders.length < repairOrdersTotal;
  }

  Future<void> loadMoreRepairOrders() async {
    if (isLoading || isLoadingMoreRepairOrders || !hasMoreRepairOrders) return;
    final generation = _repairOrdersGeneration;
    isLoadingMoreRepairOrders = true;
    repairOrdersPageError = null;
    notifyListeners();
    try {
      final data = await api.get(
        '/api/v1/repair-orders',
        queryParameters: {
          'page': _repairOrdersPage + 1,
          'size': _repairOrdersPageSize,
        },
      );
      if (generation != _repairOrdersGeneration) return;
      final incoming = _content(data).map(RepairOrder.fromJson).toList();
      final ids = repairOrders.map((order) => order.id).toSet();
      repairOrders = [
        ...repairOrders,
        ...incoming.where((order) => ids.add(order.id)),
      ];
      _repairOrdersPage++;
      _updateRepairOrdersPage(data);
      if (incoming.isEmpty) hasMoreRepairOrders = false;
    } on ApiException catch (e) {
      if (generation != _repairOrdersGeneration) return;
      repairOrdersPageError = e.message;
    } catch (_) {
      if (generation != _repairOrdersGeneration) return;
      repairOrdersPageError = 'Không thể tải thêm đơn hàng.';
    } finally {
      if (generation == _repairOrdersGeneration) {
        isLoadingMoreRepairOrders = false;
        notifyListeners();
      }
    }
  }

  Future<RepairOrder> createRepairOrder({
    String? customerName,
    String? customerPhone,
    String? customerId,
    required List<RepairDevice> devices,
  }) async {
    final Map<String, dynamic> body = {
      'devices': devices.map((d) => d.toRequestJson()).toList(),
    };
    if (customerId != null && customerId.isNotEmpty) {
      body['customerId'] = customerId;
    } else {
      body['customerName'] = customerName ?? '';
      if (customerPhone != null && customerPhone.isNotEmpty) {
        body['customerPhone'] = customerPhone;
      }
    }
    final data = await api.post(
      '/api/v1/repair-orders',
      body: body,
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

  Future<void> loadMyTodayAttendance({bool notify = true}) async {
    final data = await api.get('/api/v1/attendance/me/today');
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid attendance response');
    }
    myTodayAttendance = MyTodayAttendance.fromJson(data);
    if (notify) notifyListeners();
  }

  Future<void> loadMyAttendance({
    String? employeeId,
    int? year,
    int? month,
    bool notify = true,
  }) async {
    isLoadingMyAttendance = true;
    if (notify) notifyListeners();

    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    try {
      // 1. Tải trạng thái hôm nay của tài khoản cá nhân
      try {
        final todayData = await api.get('/api/v1/attendance/me/today');
        if (todayData is Map<String, dynamic>) {
          myTodayAttendance = MyTodayAttendance.fromJson(todayData);
        }
      } catch (e) {
        debugPrint('loadMyAttendance today error: $e');
      }

      // 2. Tải lịch sử các ngày chấm công trong tháng
      try {
        dynamic logsData;
        try {
          logsData = await api.get(
            '/api/attendance/me/logs',
            queryParameters: {'year': targetYear, 'month': targetMonth},
          );
        } catch (_) {
          if (employeeId != null && employeeId.isNotEmpty) {
            logsData = await api.get(
              '/api/attendance/$employeeId/logs',
              queryParameters: {'year': targetYear, 'month': targetMonth},
            );
          }
        }

        if (logsData is Map<String, dynamic>) {
          myAttendanceHistory = EmployeeHistoryData.fromJson(logsData);
        }
      } catch (e) {
        debugPrint('loadMyAttendance logs error: $e');
      }
    } finally {
      isLoadingMyAttendance = false;
      if (notify) notifyListeners();
    }
  }

  Future<FieldWorkDay> saveFieldWork(DateTime date, String note) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await api.put(
      '/api/attendance/me/field-work/$dateStr',
      body: {'note': note.trim()},
    );
    final data =
        res is Map<String, dynamic> && res['data'] is Map<String, dynamic>
        ? res['data'] as Map<String, dynamic>
        : (res is Map<String, dynamic> ? res : <String, dynamic>{});
    final saved = FieldWorkDay.fromJson(data);
    fieldWorkRevision++;
    await loadMyTodayAttendance(notify: false);
    await loadMyAttendance(year: date.year, month: date.month, notify: true);
    return saved;
  }

  Future<void> removeFieldWork(DateTime date) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await api.delete('/api/attendance/me/field-work/$dateStr');
    fieldWorkRevision++;
    await loadMyTodayAttendance(notify: false);
    await loadMyAttendance(year: date.year, month: date.month, notify: true);
  }

  Future<List<FieldWorkDay>> getFieldWorkDays({
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, dynamic>{};
    if (from != null) {
      params['from'] =
          '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    }
    if (to != null) {
      params['to'] =
          '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    }
    final res = await api.get(
      '/api/attendance/me/field-work',
      queryParameters: params,
    );
    final list = res is Map<String, dynamic> && res['data'] is List
        ? res['data'] as List
        : (res is List ? res : []);
    return list
        .map((e) => FieldWorkDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FieldWorkDay>> getPendingFieldWork() async {
    final res = await api.get('/api/attendance/field-work/pending');
    final list = res is Map<String, dynamic>
        ? res['data'] as List
        : res as List;
    return list
        .map((e) => FieldWorkDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> reviewFieldWork(String id, bool approve, int version) async {
    await api.put(
      '/api/attendance/field-work/$id/review',
      body: {'approve': approve, 'version': version},
    );
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

  Future<RepairOrder> linkRepairOrderCustomer(
    String orderId, {
    required String customerId,
    required String reason,
    bool reload = true,
  }) async {
    final data = await api.put(
      '/api/v1/repair-orders/$orderId/customer',
      body: {
        'customerId': customerId,
        'reason': reason.trim(),
      },
    );
    if (reload) await loadRepairOrders();
    return RepairOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<CustomerPage> searchCustomers({
    String? search,
    String? keyword,
    bool? active,
    CustomerType? type,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'size': size.clamp(1, 50),
    };
    final q = (search ?? keyword)?.trim();
    if (q != null && q.isNotEmpty) {
      query['keyword'] = q;
    }
    if (active != null) {
      query['active'] = active;
    }
    if (type != null) {
      query['type'] = type.backendValue;
    }

    final data = await api.get('/api/v1/customers', queryParameters: query);
    if (data is Map<String, dynamic>) {
      return CustomerPage.fromJson(data);
    }
    return const CustomerPage(
      content: [],
      number: 0,
      size: 20,
      totalElements: 0,
      totalPages: 0,
      last: true,
    );
  }

  Future<Customer> getCustomer(String id) async {
    final data = await api.get('/api/v1/customers/$id');
    return Customer.fromJson(data as Map<String, dynamic>);
  }

  Future<Customer> createCustomer({
    required String name,
    required CustomerType type,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    String? notes,
  }) async {
    final body = {
      'customerName': name.trim(),
      'type': type.backendValue,
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
      'address': (address != null && address.trim().isNotEmpty) ? address.trim() : null,
      'taxCode': (taxCode != null && taxCode.trim().isNotEmpty) ? taxCode.trim() : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    };
    final data = await api.post('/api/v1/customers', body: body);
    return Customer.fromJson(data as Map<String, dynamic>);
  }

  Future<Customer> updateCustomer(
    String id, {
    required String name,
    required CustomerType type,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    String? notes,
  }) async {
    final body = {
      'customerName': name.trim(),
      'type': type.backendValue,
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
      'address': (address != null && address.trim().isNotEmpty) ? address.trim() : null,
      'taxCode': (taxCode != null && taxCode.trim().isNotEmpty) ? taxCode.trim() : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    };
    final data = await api.put('/api/v1/customers/$id', body: body);
    return Customer.fromJson(data as Map<String, dynamic>);
  }

  Future<Customer> updateCustomerStatus(String id, bool active) async {
    final data = await api.patch('/api/v1/customers/$id/status', body: {'active': active});
    return Customer.fromJson(data as Map<String, dynamic>);
  }

  Future<List<RepairOrder>> getRepairOrdersByCustomer(
    String customerId, {
    int page = 0,
    int size = 20,
  }) async {
    final data = await api.get(
      '/api/v1/repair-orders',
      queryParameters: {
        'customerId': customerId,
        'page': page,
        'size': size.clamp(1, 50),
      },
    );
    return _content(data).map(RepairOrder.fromJson).toList();
  }

  Future<void> checkoutBoard(
    String boardId, {
    String? repairOrderId,
    String? note,
    int? quantity,
    String? repairBrand,
    bool reload = true,
  }) async {
    await api.post(
      '/api/v1/boards/$boardId/checkout',
      body: {
        'repairOrderId': repairOrderId,
        'note': note,
        'quantity': ?quantity,
        if (repairBrand != null && repairBrand.isNotEmpty)
          'repairBrand': repairBrand,
      },
    );
    if (reload) await loadBoards();
  }

  Future<void> returnBoard(
    String boardId, {
    String? checkoutId,
    String? notes,
    String returnType = 'FULL',
    int? returnQuantity,
    String? reason,
    bool reload = true,
  }) async {
    final body = <String, dynamic>{'returnType': returnType};
    if (checkoutId != null && checkoutId.isNotEmpty) {
      body['checkoutId'] = checkoutId;
    }
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    if (returnType == 'PARTIAL' && returnQuantity != null) {
      body['returnQuantity'] = returnQuantity;
    }
    await api.patch('/api/v1/boards/$boardId/return', body: body);
    if (reload) await loadBoards();
  }

  Future<List<BoardHistoryItem>> getBoardHistory(String boardId) async {
    final data = await api.get('/api/v1/boards/$boardId/history');
    return _content(data).map(BoardHistoryItem.fromJson).toList();
  }

  Future<void> loadParts({bool notify = true}) async {
    try {
      final data = await api.get(
        '/api/v1/parts',
        queryParameters: {'size': 200},
      );
      parts = _content(data).map(Part.fromJson).toList();
    } catch (e, stack) {
      debugPrint('Error loading parts: $e\n$stack');
    }
    if (notify) notifyListeners();
  }

  Future<void> deletePart(Part part) async {
    await api.delete('/api/v1/parts/${part.id}');
    await loadParts();
  }

  Future<void> adjustPartStock(
    String partId, {
    required String locationCode,
    required double amount,
    String? note,
    bool reload = true,
  }) async {
    await api.post(
      '/api/v1/parts/$partId/adjust-stock',
      body: {
        'storeLocationCode': locationCode,
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (reload) {
      await Future.wait([loadParts(), loadLocations()]);
    }
  }

  Future<Map<String, dynamic>> scanLocationQr(String codeOrQr) async {
    final res = await api.get(
      '/api/v1/parts/locations/scan/${Uri.encodeComponent(codeOrQr.trim())}',
    );
    if (res is Map<String, dynamic>) {
      return res;
    }
    return <String, dynamic>{};
  }

  Future<void> checkoutPart(
    String partId, {
    required String storeLocationId,
    required String partLotId,
    required double quantity,
    String? purpose,
    String? notes,
    String? repairOrderId,
    String? repairBrand,
    bool reload = true,
  }) async {
    final body = <String, dynamic>{
      'storeLocationId': storeLocationId,
      'partLotId': partLotId,
      'quantity': quantity,
      if (purpose != null && purpose.isNotEmpty) 'purpose': purpose,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (repairOrderId != null && repairOrderId.isNotEmpty)
        'repairOrderId': repairOrderId,
      if (repairBrand != null && repairBrand.isNotEmpty)
        'repairBrand': repairBrand,
    };
    await api.post('/api/v1/parts/$partId/checkout', body: body);
    if (reload) await loadParts();
  }

  Future<List<PartCheckout>> getOpenPartCheckouts(String partId) async {
    final checkouts = <PartCheckout>[];
    var page = 0;
    int totalPages;
    do {
      final data = await api.get(
        '/api/v1/parts/checkouts/history',
        queryParameters: {
          'partId': partId,
          'status': 'OPEN',
          'size': 200,
          'page': page,
        },
      );
      checkouts.addAll(_content(data).map(PartCheckout.fromJson));
      totalPages = data is Map<String, dynamic>
          ? (data['totalPages'] as num?)?.toInt() ?? 1
          : 1;
      page++;
    } while (page < totalPages);
    return checkouts
        .where((checkout) => checkout.remainingQuantity > 0)
        .toList();
  }

  Future<void> returnPart(
    String checkoutId, {
    required double quantity,
    required String conditionStatus,
    String? notes,
  }) async {
    await api.post(
      '/api/v1/parts/checkouts/$checkoutId/return',
      body: {
        'returnedQuantity': quantity,
        'conditionStatus': conditionStatus,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    await Future.wait([loadParts(), loadLocations()]);
  }

  Future<void> loadLocations({bool notify = true}) async {
    try {
      final data = await api.get('/api/v1/parts/locations');
      if (data is List) {
        locations = data
            .map((e) => StoreLocation.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        locations = _content(data).map(StoreLocation.fromJson).toList();
      }
      if (notify) notifyListeners();
    } catch (e) {
      debugPrint('Error loading store locations: $e');
    }
  }

  Future<StoreLocation> createStoreLocation({
    required String code,
    required String name,
    String? description,
    String? qrCode,
    bool reload = true,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim(),
      'name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (qrCode != null && qrCode.trim().isNotEmpty) 'qrCode': qrCode.trim(),
    };
    final res = await api.post('/api/v1/parts/locations', body: body);
    final created = StoreLocation.fromJson(
      res is Map<String, dynamic> ? res : <String, dynamic>{},
    );
    if (reload) await loadLocations();
    return created;
  }

  Future<StoreLocation> updateStoreLocation({
    required String id,
    required String code,
    required String name,
    String? description,
    String? qrCode,
    bool reload = true,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim(),
      'name': name.trim(),
      if (description != null) 'description': description.trim(),
      if (qrCode != null) 'qrCode': qrCode.trim(),
    };
    final res = await api.patch('/api/v1/parts/locations/$id', body: body);
    final updated = StoreLocation.fromJson(
      res is Map<String, dynamic> ? res : <String, dynamic>{},
    );
    if (reload) await loadLocations();
    return updated;
  }

  Future<void> deleteStoreLocation(String id, {bool reload = true}) async {
    await api.delete('/api/v1/parts/locations/$id');
    if (reload) await loadLocations();
  }

  Future<void> loadBanners({bool notify = true}) async {
    try {
      isLoadingBanners = true;
      final data = await api.get('/api/v1/banners');
      final list = _content(data);
      final loaded = list
          .map((item) {
            try {
              return AppBanner.fromJson(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<AppBanner>()
          .where((b) => b.isActive)
          .toList();
      if (loaded.isNotEmpty) {
        banners = loaded;
      } else {
        banners = [AppBanner.defaultBanner];
      }
    } catch (_) {
      if (banners.isEmpty) {
        banners = [AppBanner.defaultBanner];
      }
    } finally {
      isLoadingBanners = false;
      if (notify) notifyListeners();
    }
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

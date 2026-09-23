import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:system_internal_likenew/models/attendance.dart';
import 'package:system_internal_likenew/models/board.dart';
import 'package:system_internal_likenew/models/part.dart';
import 'package:system_internal_likenew/models/repair_order.dart';
import 'package:system_internal_likenew/models/store_location.dart';
import 'package:system_internal_likenew/models/user.dart';
import 'package:system_internal_likenew/utils/api_client.dart';
import 'package:system_internal_likenew/utils/backend_data_provider.dart';

void main() {
  group('BackendDataProvider Tests', () {
    test('clear() resets all state and notifies listeners', () {
      final apiClient = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUrl: 'https://test.api.local',
      );
      final provider = BackendDataProvider(api: apiClient);

      // Populate dummy data simulating active session
      provider.employees = [
        User(
          id: '1',
          name: 'Employee 1',
          email: 'emp1@test.com',
          employeeId: 'EMP01',
          role: UserRole.employee,
          status: UserStatus.active,
        ),
      ];
      provider.pendingUsers = [
        User(
          id: '2',
          name: 'Pending User',
          email: 'pending@test.com',
          employeeId: 'EMP02',
          role: UserRole.employee,
          status: UserStatus.pending,
        ),
      ];
      provider.boards = [
        Board(
          id: 'b1',
          name: 'Board 1',
          model: 'M1',
          location: 'L1',
          qrCode: 'QR1',
          status: BoardStatus.available,
          quantity: 5,
        ),
      ];
      provider.parts = [
        Part(
          id: 'p1',
          ipn: 'IPN1',
          name: 'Part 1',
          minAmount: 2,
          totalQuantity: 10,
          lots: [],
        ),
      ];
      provider.locations = [
        StoreLocation(id: 'loc1', code: 'LOC1', name: 'Location 1'),
      ];
      provider.repairOrders = [
        RepairOrder(
          id: 'ro1',
          orderNumber: 'ORD01',
          deviceName: 'Inverter A',
          customerName: 'Customer X',
          status: RepairOrderStatus.pending,
          createdAt: DateTime.now(),
        ),
      ];
      provider.attendanceRecords = [
        AttendanceRecord(
          id: 'att1',
          employeeId: 'EMP01',
          employeeName: 'Employee 1',
          date: DateTime.now(),
          status: AttendanceStatus.onTime,
        ),
      ];
      provider.myAttendanceHistory = const EmployeeHistoryData(
        employeeId: 'EMP01',
        employeeName: 'Employee 1',
        department: 'Tech',
        days: [],
        summary: AttendanceSummary(),
      );
      provider.myTodayAttendance = const MyTodayAttendance();
      provider.error = 'Some previous error';

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      // Execute clear
      provider.clear();

      expect(notified, isTrue);
      expect(provider.employees, isEmpty);
      expect(provider.pendingUsers, isEmpty);
      expect(provider.boards, isEmpty);
      expect(provider.parts, isEmpty);
      expect(provider.locations, isEmpty);
      expect(provider.repairOrders, isEmpty);
      expect(provider.attendanceRecords, isEmpty);
      expect(provider.myAttendanceHistory, isNull);
      expect(provider.myTodayAttendance, isNull);
      expect(provider.error, isNull);
    });
  });
}

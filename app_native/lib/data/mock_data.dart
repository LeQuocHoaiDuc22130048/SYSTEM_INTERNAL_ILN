import '../models/attendance.dart';
import '../models/board.dart';
import '../models/repair_order.dart';
import '../models/user.dart';

final List<User> mockUsers = [
  User(
    id: 'user_001',
    name: 'Nguyễn Văn Minh',
    email: 'minh.nguyen@techfix.com',
    employeeId: 'NV-2024-001',
    role: UserRole.superAdmin,
    status: UserStatus.active,
    avatar: 'M',
    department: 'Quản lý',
    phone: '0901234567',
  ),
  User(
    id: 'user_002',
    name: 'Trần Thị Bình',
    email: 'binh.tran@techfix.com',
    employeeId: 'NV-2024-002',
    role: UserRole.admin,
    status: UserStatus.active,
    avatar: 'B',
    department: 'Quản lý',
    phone: '0901234568',
  ),
  User(
    id: 'user_003',
    name: 'Lê Văn Hùng',
    email: 'hung.le@techfix.com',
    employeeId: 'NV-2024-003',
    role: UserRole.manager,
    status: UserStatus.active,
    avatar: 'H',
    department: 'Kỹ thuật',
    phone: '0901234569',
  ),
  User(
    id: 'user_004',
    name: 'Phạm Thị Dung',
    email: 'dung.pham@techfix.com',
    employeeId: 'NV-2024-004',
    role: UserRole.employee,
    status: UserStatus.active,
    avatar: 'D',
    department: 'Kỹ thuật',
    phone: '0901234570',
  ),
];

final List<RepairOrder> mockRepairOrders = [
  RepairOrder(
    id: 'order_001',
    orderNumber: 'ĐH-2024-0848',
    deviceName: 'Samsung Note 20 Ultra',
    customerName: 'Nguyễn Thị Mai',
    customerPhone: '0912345678',
    status: RepairOrderStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    description: 'Máy không nhận sạc, cần kiểm tra cổng USB-C và bo nguồn.',
  ),
  RepairOrder(
    id: 'order_002',
    orderNumber: 'ĐH-2024-0847',
    deviceName: 'MacBook Pro 14"',
    customerName: 'Hoàng Minh Tuấn',
    customerPhone: '0912345679',
    status: RepairOrderStatus.inProgress,
    assignedToId: 'user_003',
    assignedToName: 'Lê Văn Hùng',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    description: 'Không lên nguồn, đã yêu cầu lấy bo BD-007 từ kệ D.',
  ),
  RepairOrder(
    id: 'order_003',
    orderNumber: 'ĐH-2024-0846',
    deviceName: 'iPhone 15 Pro Max',
    customerName: 'Võ Minh Khoa',
    customerPhone: '0912345680',
    status: RepairOrderStatus.completed,
    assignedToId: 'user_004',
    assignedToName: 'Phạm Thị Dung',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    description: 'Lỗi cảm ứng, đã thay màn hình và kiểm tra lại Face ID.',
  ),
  RepairOrder(
    id: 'order_004',
    orderNumber: 'ĐH-2024-0845',
    deviceName: 'Samsung Galaxy Tab S9',
    customerName: 'Bùi Thị Hoa',
    customerPhone: '0912345681',
    status: RepairOrderStatus.delivered,
    assignedToId: 'user_004',
    assignedToName: 'Phạm Thị Dung',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    description: 'Pin chai, đã thay pin và bàn giao cho khách.',
  ),
];

final List<Board> mockBoards = [
  Board(
    id: 'board_001',
    name: 'Bo mạch iPhone 13',
    qrCode: 'BD-001',
    model: 'A2483',
    location: 'Kệ A1',
    status: BoardStatus.available,
    description: 'Bo mạch chính iPhone 13, đã test hoạt động tốt.',
  ),
  Board(
    id: 'board_002',
    name: 'Bo mạch Samsung S22',
    qrCode: 'BD-002',
    model: 'SM-S901B',
    location: 'Kệ A2',
    status: BoardStatus.checkedOut,
    checkedOutBy: 'Phạm Thị Dung',
    checkedOutAt: DateTime.now().subtract(const Duration(hours: 3)),
    currentRepairOrder: 'ĐH-2024-0846',
    description: 'Bo mạch chính Samsung S22.',
  ),
  Board(
    id: 'board_003',
    name: 'Bo mạch iPad Air',
    qrCode: 'BD-003',
    model: 'A2589',
    location: 'Kệ B1',
    status: BoardStatus.available,
    description: 'Bo mạch iPad Air 5th gen.',
  ),
  Board(
    id: 'board_004',
    name: 'Bo mạch iPhone 12',
    qrCode: 'BD-004',
    model: 'A2403',
    location: 'Kệ A1',
    status: BoardStatus.maintenance,
    description: 'Bo mạch cần kiểm tra lại IC nguồn.',
  ),
  Board(
    id: 'board_005',
    name: 'Bo mạch MacBook Pro',
    qrCode: 'BD-007',
    model: 'A2442',
    location: 'Kệ D',
    status: BoardStatus.available,
    description: 'Bo mạch MacBook Pro 14" M1 Pro.',
  ),
];

final List<AttendanceRecord> mockAttendanceRecords = [
  AttendanceRecord(
    id: 'att_001',
    employeeId: 'user_001',
    employeeName: 'Nguyễn Văn Minh',
    date: DateTime.now(),
    checkIn: '07:45',
    checkOut: null,
    status: AttendanceStatus.onTime,
  ),
  AttendanceRecord(
    id: 'att_002',
    employeeId: 'user_002',
    employeeName: 'Trần Thị Bình',
    date: DateTime.now(),
    checkIn: '08:15',
    checkOut: null,
    status: AttendanceStatus.late,
  ),
  AttendanceRecord(
    id: 'att_003',
    employeeId: 'user_003',
    employeeName: 'Lê Văn Hùng',
    date: DateTime.now(),
    checkIn: '07:52',
    checkOut: null,
    status: AttendanceStatus.onTime,
  ),
  AttendanceRecord(
    id: 'att_004',
    employeeId: 'user_004',
    employeeName: 'Phạm Thị Dung',
    date: DateTime.now(),
    checkIn: '07:50',
    checkOut: null,
    status: AttendanceStatus.onTime,
  ),
];

class StatusStats {
  final int pending;
  final int inProgress;
  final int completed;
  final int delivered;
  final int totalBoards;
  final int availableBoards;
  final int checkedOutBoards;
  final int maintenanceBoards;
  final int totalEmployees;
  final int presentToday;
  final int lateToday;

  StatusStats({
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.delivered,
    required this.totalBoards,
    required this.availableBoards,
    required this.checkedOutBoards,
    required this.maintenanceBoards,
    required this.totalEmployees,
    required this.presentToday,
    required this.lateToday,
  });
}

final statusStats = StatusStats(
  pending: mockRepairOrders
      .where((order) => order.status == RepairOrderStatus.pending)
      .length,
  inProgress: mockRepairOrders
      .where((order) => order.status == RepairOrderStatus.inProgress)
      .length,
  completed: mockRepairOrders
      .where((order) => order.status == RepairOrderStatus.completed)
      .length,
  delivered: mockRepairOrders
      .where((order) => order.status == RepairOrderStatus.delivered)
      .length,
  totalBoards: 10,
  availableBoards: 6,
  checkedOutBoards: 3,
  maintenanceBoards: mockBoards
      .where((board) => board.status == BoardStatus.maintenance)
      .length,
  totalEmployees: 6,
  presentToday: 6,
  lateToday: 1,
);

class WeeklyStats {
  final String day;
  final int pending;
  final int inProgress;
  final int completed;

  WeeklyStats({
    required this.day,
    required this.pending,
    required this.inProgress,
    required this.completed,
  });
}

final List<WeeklyStats> weeklyOrderStats = [
  WeeklyStats(day: 'T2', pending: 3, inProgress: 5, completed: 4),
  WeeklyStats(day: 'T3', pending: 2, inProgress: 6, completed: 5),
  WeeklyStats(day: 'T4', pending: 4, inProgress: 4, completed: 6),
  WeeklyStats(day: 'T5', pending: 5, inProgress: 7, completed: 3),
  WeeklyStats(day: 'T6', pending: 2, inProgress: 5, completed: 8),
  WeeklyStats(day: 'T7', pending: 1, inProgress: 3, completed: 4),
  WeeklyStats(day: 'CN', pending: 0, inProgress: 2, completed: 2),
];

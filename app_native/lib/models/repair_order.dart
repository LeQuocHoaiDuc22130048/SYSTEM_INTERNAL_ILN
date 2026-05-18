enum RepairOrderStatus { pending, inProgress, completed, delivered }

class RepairOrder {
  final String id;
  final String orderNumber;
  final String deviceName;
  final String customerName;
  final String? customerPhone;
  final RepairOrderStatus status;
  final String? assignedToId;
  final String? assignedToName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;
  final String? notes;
  final String? imagePath;

  RepairOrder({
    required this.id,
    required this.orderNumber,
    required this.deviceName,
    required this.customerName,
    this.customerPhone,
    required this.status,
    this.assignedToId,
    this.assignedToName,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.notes,
    this.imagePath,
  });

  String get statusLabel {
    switch (status) {
      case RepairOrderStatus.pending:
        return 'Chờ xử lý';
      case RepairOrderStatus.inProgress:
        return 'Đang sửa';
      case RepairOrderStatus.completed:
        return 'Hoàn thành';
      case RepairOrderStatus.delivered:
        return 'Đã giao';
    }
  }
}

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

  factory RepairOrder.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assignedTo'];
    final images = json['images'];
    return RepairOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderCode']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString(),
      status: _statusFromBackend(json['status']?.toString()),
      assignedToId: assignedTo is Map<String, dynamic>
          ? assignedTo['id']?.toString()
          : null,
      assignedToName: assignedTo is Map<String, dynamic>
          ? assignedTo['fullName']?.toString()
          : null,
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromJson(json['updatedAt']),
      description: json['description']?.toString(),
      notes: json['deviceType']?.toString(),
      imagePath: images is List && images.isNotEmpty && images.first is Map
          ? (images.first as Map)['imageUrl']?.toString()
          : null,
    );
  }

  static RepairOrderStatus _statusFromBackend(String? status) {
    switch (status) {
      case 'RECEIVED':
      case 'PENDING':
        return RepairOrderStatus.pending;
      case 'ASSIGNED':
      case 'IN_PROGRESS':
      case 'CHECKING':
      case 'REPAIRING':
        return RepairOrderStatus.inProgress;
      case 'COMPLETED':
      case 'DONE':
        return RepairOrderStatus.completed;
      case 'DELIVERED':
        return RepairOrderStatus.delivered;
      default:
        return RepairOrderStatus.pending;
    }
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

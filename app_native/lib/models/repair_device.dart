import 'repair_order.dart';

class RepairDevice {
  final String id;
  final String deviceName;
  final String? deviceType;
  final String? serialNumber;
  final bool underWarranty;
  final DateTime? warrantyExpiry;
  final String? description;
  final RepairOrderStatus status;
  final String? assignedToId;
  final String? assignedToName;

  RepairDevice({
    required this.id,
    required this.deviceName,
    this.deviceType,
    this.serialNumber,
    this.underWarranty = false,
    this.warrantyExpiry,
    this.description,
    this.status = RepairOrderStatus.pending,
    this.assignedToId,
    this.assignedToName,
  });

  factory RepairDevice.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assignedTo'];
    return RepairDevice(
      id: json['id']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      deviceType: json['deviceType']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      underWarranty: json['underWarranty'] == true,
      warrantyExpiry: json['warrantyExpiry'] != null ? DateTime.tryParse(json['warrantyExpiry'].toString()) : null,
      description: json['description']?.toString(),
      status: _statusFromString(json['status']?.toString()),
      assignedToId: assignedTo is Map<String, dynamic> ? assignedTo['id']?.toString() : null,
      assignedToName: assignedTo is Map<String, dynamic> ? assignedTo['fullName']?.toString() : null,
    );
  }

  Map<String, dynamic> toRequestJson({String? overrideAssignedToId}) {
    return {
      'deviceName': deviceName,
      if (deviceType != null) 'deviceType': deviceType,
      if (serialNumber != null) 'serialNumber': serialNumber,
      'underWarranty': underWarranty,
      if (underWarranty && warrantyExpiry != null)
        'warrantyExpiry': warrantyExpiry!.toIso8601String().split('T')[0],
      if (description != null) 'description': description,
      'assignedToId': overrideAssignedToId ?? assignedToId,
    };
  }

  RepairDevice copyWith({
    String? deviceName,
    String? deviceType,
    String? serialNumber,
    bool? underWarranty,
    DateTime? Function()? warrantyExpiry,
    String? description,
    RepairOrderStatus? status,
    String? assignedToId,
    String? assignedToName,
  }) {
    return RepairDevice(
      id: id,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      serialNumber: serialNumber ?? this.serialNumber,
      underWarranty: underWarranty ?? this.underWarranty,
      warrantyExpiry: warrantyExpiry != null ? warrantyExpiry() : this.warrantyExpiry,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }

  String get statusLabel {
    switch (status) {
      case RepairOrderStatus.pending:
        return 'Chưa kiểm tra';
      case RepairOrderStatus.waitingForCheck:
        return 'Chờ kiểm tra';
      case RepairOrderStatus.checking:
        return 'Đang kiểm tra';
      case RepairOrderStatus.checked:
        return 'Đã kiểm tra';
      case RepairOrderStatus.inProgress:
        return 'Đang sửa';
      case RepairOrderStatus.completed:
        return 'Hoàn thành';
      case RepairOrderStatus.delivered:
        return 'Đã giao';
      case RepairOrderStatus.cancelled:
        return 'Đã trả';
    }
  }

  static RepairOrderStatus _statusFromString(String? s) {
    switch (s) {
      case 'PENDING':
        return RepairOrderStatus.pending;
      case 'WAITING_FOR_CHECK':
        return RepairOrderStatus.waitingForCheck;
      case 'CHECKING':
        return RepairOrderStatus.checking;
      case 'CHECKED':
        return RepairOrderStatus.checked;
      case 'IN_PROGRESS':
        return RepairOrderStatus.inProgress;
      case 'COMPLETED':
        return RepairOrderStatus.completed;
      case 'DELIVERED':
        return RepairOrderStatus.delivered;
      case 'CANCELLED':
        return RepairOrderStatus.cancelled;
      default:
        return RepairOrderStatus.pending;
    }
  }
}

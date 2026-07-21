import 'repair_device.dart';

enum RepairOrderStatus {
  pending,
  waitingForCheck,
  checking,
  checked,
  inProgress,
  completed,
  delivered,
  cancelled,
}

class RepairMedia {
  final String id;
  final String url;
  final String type;
  final String? caption;

  const RepairMedia({
    required this.id,
    required this.url,
    required this.type,
    this.caption,
  });

  bool get isVideo => type == 'VIDEO';

  factory RepairMedia.fromJson(Map<String, dynamic> json) {
    return RepairMedia(
      id: json['id']?.toString() ?? '',
      url: json['imageUrl']?.toString() ?? '',
      type: json['mediaType']?.toString() ?? 'IMAGE',
      caption: json['caption']?.toString(),
    );
  }
}

class RepairOrder {
  final String id;
  final String orderNumber;
  final String deviceName;
  final String customerName;
  final String? customerPhone;
  final RepairOrderStatus status;
  final String? assignedToId;
  final String? assignedToName;
  final List<String> assigneeIds;
  final List<String> assigneeNames;
  final String? serialNumber;
  final bool underWarranty;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;
  final String? notes;
  final List<RepairMedia> media;
  final List<RepairDevice> devices;

  RepairOrder({
    required this.id,
    required this.orderNumber,
    required this.deviceName,
    required this.customerName,
    this.customerPhone,
    required this.status,
    this.assignedToId,
    this.assignedToName,
    this.assigneeIds = const [],
    this.assigneeNames = const [],
    this.serialNumber,
    this.underWarranty = false,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.notes,
    this.media = const [],
    this.devices = const [],
  });

  String? get imagePath {
    for (final attachment in media) {
      if (!attachment.isVideo) return attachment.url;
    }
    return null;
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

  factory RepairOrder.fromJson(Map<String, dynamic> json) {
    final assignedTo = json['assignedTo'];
    final images = json['images'];

    final assigneesJson = json['assignees'];
    final List<String> assigneeIds = [];
    final List<String> assigneeNames = [];
    if (assigneesJson is List) {
      for (final item in assigneesJson) {
        if (item is Map<String, dynamic>) {
          final id = item['id']?.toString();
          final name = item['fullName']?.toString();
          if (id != null && name != null) {
            assigneeIds.add(id);
            assigneeNames.add(name);
          }
        }
      }
    }

    String? assignedToId = assignedTo is Map<String, dynamic>
        ? assignedTo['id']?.toString()
        : null;
    String? assignedToName = assignedTo is Map<String, dynamic>
        ? assignedTo['fullName']?.toString()
        : null;

    if (assigneeIds.isNotEmpty && assignedToId == null) {
      assignedToId = assigneeIds.first;
      assignedToName = assigneeNames.first;
    }

    return RepairOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderCode']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString(),
      status: _statusFromBackend(json['status']?.toString()),
      assignedToId: assignedToId,
      assignedToName: assignedToName,
      assigneeIds: assigneeIds,
      assigneeNames: assigneeNames,
      serialNumber: json['serialNumber']?.toString(),
      underWarranty: json['underWarranty'] == true,
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromJson(json['updatedAt']),
      description: json['description']?.toString(),
      notes: json['notes']?.toString(),
      media: images is List
          ? images
                .whereType<Map<String, dynamic>>()
                .map(RepairMedia.fromJson)
                .where((attachment) => attachment.url.isNotEmpty)
                .toList()
          : const [],
      devices: (json['devices'] is List)
          ? (json['devices'] as List)
                .whereType<Map<String, dynamic>>()
                .map(RepairDevice.fromJson)
                .toList()
          : const [],
    );
  }

  static RepairOrderStatus _statusFromBackend(String? status) {
    switch (status) {
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

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

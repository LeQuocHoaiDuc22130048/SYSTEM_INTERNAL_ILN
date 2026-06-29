enum RepairOrderStatus { pending, inProgress, completed, delivered, cancelled }

class RepairMedia {
  final String url;
  final String type;
  final String? caption;

  const RepairMedia({required this.url, required this.type, this.caption});

  bool get isVideo => type == 'VIDEO';

  factory RepairMedia.fromJson(Map<String, dynamic> json) {
    return RepairMedia(
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
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;
  final String? notes;
  final List<RepairMedia> media;

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
    this.media = const [],
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
        return 'Chờ xử lý';
      case RepairOrderStatus.inProgress:
        return 'Đang sửa';
      case RepairOrderStatus.completed:
        return 'Hoàn thành';
      case RepairOrderStatus.delivered:
        return 'Đã giao';
      case RepairOrderStatus.cancelled:
        return 'Đã hủy';
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
      media: images is List
          ? images
              .whereType<Map<String, dynamic>>()
              .map(RepairMedia.fromJson)
              .where((attachment) => attachment.url.isNotEmpty)
              .toList()
          : const [],
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

enum BoardStatus {
  available,
  checkedOut,
  inRepair,
  damaged,
  lost,
  archived,
  maintenance,
}

class Board {
  final String id;
  final String name;
  final String qrCode;
  final String model;
  final String location;
  final BoardStatus status;
  final String? checkedOutBy;
  final DateTime? checkedOutAt;
  final String? currentRepairOrder;
  final String? description;
  final String? serialNumber;
  final String? partId;
  final String? partIpn;
  final String? currentLocationId;
  final String? currentLocationCode;

  Board({
    required this.id,
    required this.name,
    required this.qrCode,
    required this.model,
    required this.location,
    required this.status,
    this.checkedOutBy,
    this.checkedOutAt,
    this.currentRepairOrder,
    this.description,
    this.serialNumber,
    this.partId,
    this.partIpn,
    this.currentLocationId,
    this.currentLocationCode,
  });

  String get statusLabel {
    return status.label;
  }

  factory Board.fromJson(Map<String, dynamic> json) {
    final checkout = json['activeCheckoutInfo'];
    return Board(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      model: json['category']?.toString() ?? '',
      location:
          json['currentLocationCode']?.toString() ??
          json['location']?.toString() ??
          '',
      status: _statusFromBackend(json['status']?.toString()),
      checkedOutBy: checkout is Map<String, dynamic>
          ? checkout['takenByName']?.toString()
          : null,
      checkedOutAt: checkout is Map<String, dynamic>
          ? _dateFromJson(checkout['takenAt'])
          : null,
      currentRepairOrder: checkout is Map<String, dynamic>
          ? checkout['orderCode']?.toString()
          : null,
      description: json['description']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      partId: json['partId']?.toString(),
      partIpn: json['partIpn']?.toString(),
      currentLocationId: json['currentLocationId']?.toString(),
      currentLocationCode: json['currentLocationCode']?.toString(),
    );
  }

  static BoardStatus _statusFromBackend(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return BoardStatus.available;
      case 'CHECKED_OUT':
      case 'IN_USE':
        return BoardStatus.checkedOut;
      case 'IN_REPAIR':
        return BoardStatus.inRepair;
      case 'DAMAGED':
        return BoardStatus.damaged;
      case 'LOST':
        return BoardStatus.lost;
      case 'ARCHIVED':
      case 'RETIRED':
        return BoardStatus.archived;
      case 'MAINTENANCE':
        return BoardStatus.maintenance;
      default:
        return BoardStatus.available;
    }
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

extension BoardStatusMetadata on BoardStatus {
  String get label {
    switch (this) {
      case BoardStatus.available:
        return 'Sẵn sàng';
      case BoardStatus.checkedOut:
        return 'Đang dùng';
      case BoardStatus.inRepair:
        return 'Đang sửa';
      case BoardStatus.damaged:
        return 'Hỏng';
      case BoardStatus.lost:
        return 'Mất';
      case BoardStatus.archived:
        return 'Lưu trữ';
      case BoardStatus.maintenance:
        return 'Bảo trì';
    }
  }

  String get backendName {
    switch (this) {
      case BoardStatus.available:
        return 'AVAILABLE';
      case BoardStatus.checkedOut:
        return 'CHECKED_OUT';
      case BoardStatus.inRepair:
        return 'IN_REPAIR';
      case BoardStatus.damaged:
        return 'DAMAGED';
      case BoardStatus.lost:
        return 'LOST';
      case BoardStatus.archived:
        return 'ARCHIVED';
      case BoardStatus.maintenance:
        return 'MAINTENANCE';
    }
  }
}

enum BoardStatus { available, checkedOut, maintenance }

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
  });

  String get statusLabel {
    switch (status) {
      case BoardStatus.available:
        return 'Sẵn sàng';
      case BoardStatus.checkedOut:
        return 'Đang dùng';
      case BoardStatus.maintenance:
        return 'Bảo trì';
    }
  }

  factory Board.fromJson(Map<String, dynamic> json) {
    final checkout = json['activeCheckoutInfo'];
    return Board(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      model: json['category']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
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
    );
  }

  static BoardStatus _statusFromBackend(String? status) {
    switch (status) {
      case 'AVAILABLE':
        return BoardStatus.available;
      case 'CHECKED_OUT':
      case 'IN_USE':
        return BoardStatus.checkedOut;
      case 'MAINTENANCE':
      case 'DAMAGED':
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

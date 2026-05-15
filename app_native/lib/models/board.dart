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
}

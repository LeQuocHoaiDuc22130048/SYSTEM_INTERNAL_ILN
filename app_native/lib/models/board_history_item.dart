class BoardHistoryItem {
  final String id;
  final String boardId;
  final String boardName;
  final String qrCode;
  final String takenBy;
  final String takenByName;
  final DateTime? takenAt;
  final DateTime? returnedAt;
  final String? repairOrderId;
  final String? notes;
  final int quantity;
  final String? repairBrand;

  BoardHistoryItem({
    required this.id,
    required this.boardId,
    required this.boardName,
    required this.qrCode,
    required this.takenBy,
    required this.takenByName,
    this.takenAt,
    this.returnedAt,
    this.repairOrderId,
    this.notes,
    this.quantity = 1,
    this.repairBrand,
  });

  String get checkoutReason {
    if (notes == null || notes!.isEmpty) return 'Không có';
    final parts = notes!.split(' | Sửa chữa: ');
    final reason = parts[0].trim();
    if (reason.startsWith('Sửa chữa: ')) {
      return 'Không có';
    }
    return reason;
  }

  String get returnReason {
    if (notes == null || notes!.isEmpty) return 'Không có';
    final parts = notes!.split(' | Sửa chữa: ');
    if (parts.length > 1) {
      return parts[1].trim();
    }
    if (notes!.startsWith('Sửa chữa: ')) {
      return notes!.substring(10).trim();
    }
    return 'Không có';
  }

  factory BoardHistoryItem.fromJson(Map<String, dynamic> json) {
    return BoardHistoryItem(
      id: json['checkoutId']?.toString() ?? '',
      boardId: json['boardItemId']?.toString() ?? '',
      boardName: json['boardName']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      takenBy: json['takenBy']?.toString() ?? '',
      takenByName: json['takenByName']?.toString() ?? 'Không xác định',
      takenAt: _dateFromJson(json['takenAt']),
      returnedAt: _dateFromJson(json['returnAt']),
      repairOrderId: json['repairOrderId']?.toString(),
      notes: json['note']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      repairBrand: json['repairBrand']?.toString(),
    );
  }

  static DateTime? _dateFromJson(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

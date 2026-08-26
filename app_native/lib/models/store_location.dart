class StoreLocation {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? qrCode;
  final bool isFull;
  final int itemCount;
  final double totalQuantity;

  StoreLocation({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.qrCode,
    this.isFull = false,
    this.itemCount = 0,
    this.totalQuantity = 0.0,
  });

  factory StoreLocation.fromJson(Map<String, dynamic> json) {
    return StoreLocation(
      id: json['id']?.toString() ?? json['locationId']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      qrCode: json['qrCode']?.toString(),
      isFull: json['isFull'] == true,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? (json['totalPartTypes'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['totalQuantity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (description != null) 'description': description,
      if (qrCode != null) 'qrCode': qrCode,
      'isFull': isFull,
      'itemCount': itemCount,
      'totalQuantity': totalQuantity,
    };
  }

  String get displayName {
    if (name.isNotEmpty && code.isNotEmpty && name != code) {
      return '$name ($code)';
    }
    return name.isNotEmpty ? name : code;
  }
}

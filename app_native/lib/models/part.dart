double _parseDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? fallback;
}

class PartLot {
  final String id;
  final String storeLocationId;
  final String storeLocationCode;
  final String storeLocationName;
  final double amount;
  final String? lotCode;

  PartLot({
    required this.id,
    required this.storeLocationId,
    required this.storeLocationCode,
    required this.storeLocationName,
    required this.amount,
    this.lotCode,
  });

  factory PartLot.fromJson(Map<String, dynamic> json) {
    return PartLot(
      id: json['id']?.toString() ?? '',
      storeLocationId: json['storeLocationId']?.toString() ?? '',
      storeLocationCode: json['storeLocationCode']?.toString() ?? '',
      storeLocationName: json['storeLocationName']?.toString() ?? '',
      amount: _parseDouble(json['amount']),
      lotCode: json['lotCode']?.toString(),
    );
  }
}

class Part {
  final String id;
  final String ipn;
  final String name;
  final String? description;
  final double minAmount;
  final double totalQuantity;
  final String? categoryId;
  final String? categoryName;
  final List<PartLot> lots;

  Part({
    required this.id,
    required this.ipn,
    required this.name,
    this.description,
    required this.minAmount,
    required this.totalQuantity,
    this.categoryId,
    this.categoryName,
    required this.lots,
  });

  factory Part.fromJson(Map<String, dynamic> json) {
    final lotsList = json['lots'] as List?;
    final parsedLots = lotsList != null
        ? lotsList
            .whereType<Map<String, dynamic>>()
            .map((l) => PartLot.fromJson(l))
            .toList()
        : <PartLot>[];
    return Part(
      id: json['id']?.toString() ?? '',
      ipn: json['ipn']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      minAmount: _parseDouble(json['minAmount']),
      totalQuantity: _parseDouble(json['totalQuantity']),
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName']?.toString(),
      lots: parsedLots,
    );
  }
}

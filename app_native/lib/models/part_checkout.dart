class PartCheckout {
  const PartCheckout({
    required this.id,
    required this.locationCode,
    required this.takenByName,
    required this.quantity,
    required this.returnedQuantity,
  });

  final String id;
  final String locationCode;
  final String takenByName;
  final double quantity;
  final double returnedQuantity;

  double get remainingQuantity => quantity - returnedQuantity;

  factory PartCheckout.fromJson(Map<String, dynamic> json) => PartCheckout(
    id: json['id'].toString(),
    locationCode: json['locationCode']?.toString() ?? '',
    takenByName: json['takenByName']?.toString() ?? '',
    quantity: (json['quantity'] as num).toDouble(),
    returnedQuantity: (json['returnedQuantity'] as num?)?.toDouble() ?? 0,
  );
}

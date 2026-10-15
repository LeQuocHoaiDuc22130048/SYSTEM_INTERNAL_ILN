enum CustomerType {
  individual,
  company;

  String get backendValue {
    switch (this) {
      case CustomerType.individual:
        return 'INDIVIDUAL';
      case CustomerType.company:
        return 'COMPANY';
    }
  }

  String get label {
    switch (this) {
      case CustomerType.individual:
        return 'Cá nhân';
      case CustomerType.company:
        return 'Doanh nghiệp';
    }
  }

  static CustomerType fromBackend(String? value) {
    if (value?.toUpperCase() == 'COMPANY') {
      return CustomerType.company;
    }
    return CustomerType.individual;
  }
}

class Customer {
  final String id;
  final String customerCode;
  final String customerName;
  final CustomerType type;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxCode;
  final String? notes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.customerCode,
    required this.customerName,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.taxCode,
    this.notes,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  String get name => customerName;
  bool get isCompany => type == CustomerType.company;
  bool get isIndividual => type == CustomerType.individual;
  String get typeLabel => type.label;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      customerCode: json['customerCode']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      type: CustomerType.fromBackend(json['type']?.toString()),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      taxCode: json['taxCode']?.toString(),
      notes: json['notes']?.toString(),
      active: json['active'] == true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'customerName': customerName.trim(),
      'type': type.backendValue,
      'phone': (phone != null && phone!.trim().isNotEmpty) ? phone!.trim() : null,
      'email': (email != null && email!.trim().isNotEmpty) ? email!.trim() : null,
      'address': (address != null && address!.trim().isNotEmpty) ? address!.trim() : null,
      'taxCode': (taxCode != null && taxCode!.trim().isNotEmpty) ? taxCode!.trim() : null,
      'notes': (notes != null && notes!.trim().isNotEmpty) ? notes!.trim() : null,
    };
  }

  Customer copyWith({
    String? id,
    String? customerCode,
    String? customerName,
    CustomerType? type,
    String? phone,
    String? email,
    String? address,
    String? taxCode,
    String? notes,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      customerName: customerName ?? this.customerName,
      type: type ?? this.type,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      taxCode: taxCode ?? this.taxCode,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CustomerPage {
  final List<Customer> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const CustomerPage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory CustomerPage.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final List<Customer> items = [];
    if (rawContent is List) {
      for (final item in rawContent) {
        if (item is Map<String, dynamic>) {
          items.add(Customer.fromJson(item));
        }
      }
    }

    return CustomerPage(
      content: items,
      number: (json['number'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: json['last'] == true,
    );
  }
}

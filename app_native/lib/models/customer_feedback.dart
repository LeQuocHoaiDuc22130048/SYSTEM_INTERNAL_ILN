class CustomerFeedback {
  final String id;
  final String orderCode;
  final String customerName;
  final String? customerPhone;
  final String? customerCode;
  final String? deviceModel;
  final int rating;
  final String type;
  final String typeName;
  final List<String> tags;
  final String content;
  final String status;
  final String statusName;
  final String createdAt;
  final String? reply;
  final String? replyAt;
  final String? repliedBy;
  final bool isUrgent;

  CustomerFeedback({
    required this.id,
    required this.orderCode,
    required this.customerName,
    this.customerPhone,
    this.customerCode,
    this.deviceModel,
    required this.rating,
    required this.type,
    required this.typeName,
    required this.tags,
    required this.content,
    required this.status,
    required this.statusName,
    required this.createdAt,
    this.reply,
    this.replyAt,
    this.repliedBy,
    required this.isUrgent,
  });

  CustomerFeedback copyWith({
    String? status,
    String? statusName,
    String? reply,
    String? replyAt,
    String? repliedBy,
  }) {
    return CustomerFeedback(
      id: id,
      orderCode: orderCode,
      customerName: customerName,
      customerPhone: customerPhone,
      customerCode: customerCode,
      deviceModel: deviceModel,
      rating: rating,
      type: type,
      typeName: typeName,
      tags: tags,
      content: content,
      status: status ?? this.status,
      statusName: statusName ?? this.statusName,
      createdAt: createdAt,
      reply: reply ?? this.reply,
      replyAt: replyAt ?? this.replyAt,
      repliedBy: repliedBy ?? this.repliedBy,
      isUrgent: isUrgent,
    );
  }

  factory CustomerFeedback.fromJson(Map<String, dynamic> json) {
    return CustomerFeedback(
      id: json['id']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString(),
      customerCode: json['customerCode']?.toString(),
      deviceModel: json['deviceModel']?.toString(),
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      type: json['type']?.toString() ?? 'SERVICE_QUALITY',
      typeName: json['typeName']?.toString() ?? 'Đánh giá chất lượng',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      content: json['content']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      statusName: json['statusName']?.toString() ?? 'Chờ tiếp nhận',
      createdAt: json['createdAt']?.toString() ?? '',
      reply: json['reply']?.toString(),
      replyAt: json['replyAt']?.toString(),
      repliedBy: json['repliedBy']?.toString(),
      isUrgent: json['isUrgent'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderCode': orderCode,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerCode': customerCode,
      'deviceModel': deviceModel,
      'rating': rating,
      'type': type,
      'typeName': typeName,
      'tags': tags,
      'content': content,
      'status': status,
      'statusName': statusName,
      'createdAt': createdAt,
      'reply': reply,
      'replyAt': replyAt,
      'repliedBy': repliedBy,
      'isUrgent': isUrgent,
    };
  }
}


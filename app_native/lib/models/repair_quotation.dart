String formatVnd(num amount) {
  final rounded = amount.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromRight = digits.length - i;
    buf.write(digits[i]);
    if (posFromRight > 1 && posFromRight % 3 == 1) {
      buf.write('.');
    }
  }
  return '${negative ? '-' : ''}${buf.toString()} đ';
}

class DiagnosedErrorModel {
  final String label;
  final String severity;

  const DiagnosedErrorModel({required this.label, this.severity = 'MEDIUM'});

  factory DiagnosedErrorModel.fromJson(Map<String, dynamic> json) {
    return DiagnosedErrorModel(
      label: json['label']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'MEDIUM',
    );
  }

  Map<String, dynamic> toJson() => {'label': label, 'severity': severity};
}

class WarrantyOptionModel {
  final String code;
  final String label;
  final String? description;
  final int months;
  final double fee;

  const WarrantyOptionModel({
    required this.code,
    required this.label,
    this.description,
    required this.months,
    required this.fee,
  });

  factory WarrantyOptionModel.fromJson(Map<String, dynamic> json) {
    return WarrantyOptionModel(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString(),
      months: (json['months'] as num?)?.toInt() ?? 0,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        if (description != null) 'description': description,
        'months': months,
        'fee': fee,
      };
}

class QuotationLineItemModel {
  final String id;
  final String description;
  final int quantity;
  final double unitPrice;
  final double amount;
  final int sortOrder;

  const QuotationLineItemModel({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    this.sortOrder = 0,
  });

  factory QuotationLineItemModel.fromJson(Map<String, dynamic> json) {
    return QuotationLineItemModel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuotationItemModel {
  final String id;
  final String repairOrderId;
  final String orderCode;
  final String deviceName;
  final String? deviceType;
  final String? serialNumber;
  final List<DiagnosedErrorModel> diagnosedErrors;
  final List<QuotationLineItemModel> lineItems;
  final double baseCost;
  final List<WarrantyOptionModel> warrantyOptions;
  final String? selectedWarrantyCode;
  final String? selectedWarrantyLabel;
  final double warrantyFee;
  final double finalAmount;
  final String decision; // PENDING | APPROVED | REJECTED
  final String decisionLabel;
  final String? rejectReason;

  const QuotationItemModel({
    required this.id,
    required this.repairOrderId,
    required this.orderCode,
    required this.deviceName,
    this.deviceType,
    this.serialNumber,
    required this.diagnosedErrors,
    required this.lineItems,
    required this.baseCost,
    required this.warrantyOptions,
    this.selectedWarrantyCode,
    this.selectedWarrantyLabel,
    required this.warrantyFee,
    required this.finalAmount,
    required this.decision,
    required this.decisionLabel,
    this.rejectReason,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    final errorsRaw = json['diagnosedErrors'] as List? ?? const [];
    final linesRaw = json['lineItems'] as List? ?? const [];
    final warrantyRaw = json['warrantyOptions'] as List? ?? const [];
    return QuotationItemModel(
      id: json['id']?.toString() ?? '',
      repairOrderId: json['repairOrderId']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      deviceType: json['deviceType']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      diagnosedErrors: errorsRaw
          .whereType<Map<String, dynamic>>()
          .map(DiagnosedErrorModel.fromJson)
          .toList(),
      lineItems: linesRaw
          .whereType<Map<String, dynamic>>()
          .map(QuotationLineItemModel.fromJson)
          .toList(),
      baseCost: (json['baseCost'] as num?)?.toDouble() ?? 0,
      warrantyOptions: warrantyRaw
          .whereType<Map<String, dynamic>>()
          .map(WarrantyOptionModel.fromJson)
          .toList(),
      selectedWarrantyCode: json['selectedWarrantyCode']?.toString(),
      selectedWarrantyLabel: json['selectedWarrantyLabel']?.toString(),
      warrantyFee: (json['warrantyFee'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? 0,
      decision: json['decision']?.toString() ?? 'PENDING',
      decisionLabel: json['decisionLabel']?.toString() ?? '',
      rejectReason: json['rejectReason']?.toString(),
    );
  }
}

class PaymentProofModel {
  final String id;
  final String quotationId;
  final double amount;
  final String transferContent;
  final String proofFileUrl;
  final String? proofFileName;
  final String? note;
  final String status; // PENDING_VERIFY | VERIFIED | REJECTED
  final String statusLabel;
  final String? verifiedBy;
  final String? rejectionReason;
  final String createdAt;

  const PaymentProofModel({
    required this.id,
    required this.quotationId,
    required this.amount,
    required this.transferContent,
    required this.proofFileUrl,
    this.proofFileName,
    this.note,
    required this.status,
    required this.statusLabel,
    this.verifiedBy,
    this.rejectionReason,
    required this.createdAt,
  });

  factory PaymentProofModel.fromJson(Map<String, dynamic> json) {
    return PaymentProofModel(
      id: json['id']?.toString() ?? '',
      quotationId: json['quotationId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      transferContent: json['transferContent']?.toString() ?? '',
      proofFileUrl: json['proofFileUrl']?.toString() ?? '',
      proofFileName: json['proofFileName']?.toString(),
      note: json['note']?.toString(),
      status: json['status']?.toString() ?? 'PENDING_VERIFY',
      statusLabel: json['statusLabel']?.toString() ?? '',
      verifiedBy: json['verifiedBy']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class QuotationBankInfoModel {
  final String bankName;
  final String bankBin;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final String transferContent;
  final double transferAmount;
  final String vietQrPayload;

  const QuotationBankInfoModel({
    required this.bankName,
    required this.bankBin,
    required this.bankAccountNumber,
    required this.bankAccountHolder,
    required this.transferContent,
    required this.transferAmount,
    required this.vietQrPayload,
  });

  factory QuotationBankInfoModel.fromJson(Map<String, dynamic> json) {
    return QuotationBankInfoModel(
      bankName: json['bankName']?.toString() ?? '',
      bankBin: json['bankBin']?.toString() ?? '',
      bankAccountNumber: json['bankAccountNumber']?.toString() ?? '',
      bankAccountHolder: json['bankAccountHolder']?.toString() ?? '',
      transferContent: json['transferContent']?.toString() ?? '',
      transferAmount: (json['transferAmount'] as num?)?.toDouble() ?? 0,
      vietQrPayload: json['vietQrPayload']?.toString() ?? '',
    );
  }
}

class RepairQuotationModel {
  final String id;
  final String quoteCode;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? title;
  final String? note;
  final String status;
  final String statusLabel;
  final double totalEstimatedAmount;
  final double totalApprovedAmount;
  final String? sentAt;
  final String? respondedAt;
  final String? expiresAt;
  final String createdAt;
  final int itemCount;
  final int approvedItemCount;
  final int rejectedItemCount;
  final int pendingItemCount;
  final QuotationBankInfoModel? bankInfo;
  final List<QuotationItemModel> items;
  final List<PaymentProofModel> paymentProofs;

  const RepairQuotationModel({
    required this.id,
    required this.quoteCode,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.title,
    this.note,
    required this.status,
    required this.statusLabel,
    required this.totalEstimatedAmount,
    required this.totalApprovedAmount,
    this.sentAt,
    this.respondedAt,
    this.expiresAt,
    required this.createdAt,
    required this.itemCount,
    required this.approvedItemCount,
    required this.rejectedItemCount,
    required this.pendingItemCount,
    this.bankInfo,
    required this.items,
    required this.paymentProofs,
  });

  bool get hasVerifiedPayment =>
      paymentProofs.any((p) => p.status == 'VERIFIED');

  bool get hasPendingProof =>
      paymentProofs.any((p) => p.status == 'PENDING_VERIFY');

  factory RepairQuotationModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List? ?? const [];
    final proofsRaw = json['paymentProofs'] as List? ?? const [];
    final bankRaw = json['bankInfo'];
    return RepairQuotationModel(
      id: json['id']?.toString() ?? '',
      quoteCode: json['quoteCode']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString(),
      title: json['title']?.toString(),
      note: json['note']?.toString(),
      status: json['status']?.toString() ?? 'DRAFT',
      statusLabel: json['statusLabel']?.toString() ?? '',
      totalEstimatedAmount:
          (json['totalEstimatedAmount'] as num?)?.toDouble() ?? 0,
      totalApprovedAmount:
          (json['totalApprovedAmount'] as num?)?.toDouble() ?? 0,
      sentAt: json['sentAt']?.toString(),
      respondedAt: json['respondedAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
      createdAt: json['createdAt']?.toString() ?? '',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? itemsRaw.length,
      approvedItemCount: (json['approvedItemCount'] as num?)?.toInt() ?? 0,
      rejectedItemCount: (json['rejectedItemCount'] as num?)?.toInt() ?? 0,
      pendingItemCount: (json['pendingItemCount'] as num?)?.toInt() ?? 0,
      bankInfo: bankRaw is Map<String, dynamic>
          ? QuotationBankInfoModel.fromJson(bankRaw)
          : null,
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(QuotationItemModel.fromJson)
          .toList(),
      paymentProofs: proofsRaw
          .whereType<Map<String, dynamic>>()
          .map(PaymentProofModel.fromJson)
          .toList(),
    );
  }
}

class PendingQuotationOrderModel {
  final String id;
  final String orderCode;
  final String deviceName;
  final String? deviceType;
  final String? serialNumber;
  final String status;
  final String statusLabel;
  final String? receivedAt;
  final String? description;

  const PendingQuotationOrderModel({
    required this.id,
    required this.orderCode,
    required this.deviceName,
    this.deviceType,
    this.serialNumber,
    required this.status,
    required this.statusLabel,
    this.receivedAt,
    this.description,
  });

  factory PendingQuotationOrderModel.fromJson(Map<String, dynamic> json) {
    return PendingQuotationOrderModel(
      id: json['id']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? '',
      deviceType: json['deviceType']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      status: json['status']?.toString() ?? '',
      statusLabel: json['statusLabel']?.toString() ?? '',
      receivedAt: json['receivedAt']?.toString(),
      description: json['description']?.toString(),
    );
  }
}


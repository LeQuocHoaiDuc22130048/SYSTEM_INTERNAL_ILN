import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:system_inverter_likenew/models/repair_quotation.dart';
import 'package:system_inverter_likenew/utils/api_client.dart';
import 'package:system_inverter_likenew/utils/auth_provider.dart';
import 'package:system_inverter_likenew/widgets/customer_quotation_sheet.dart';

RepairQuotationModel _buildSampleQuotation({int itemCount = 2}) {
  final item1 = QuotationItemModel(
    id: 'qi-1',
    repairOrderId: 'ro-1',
    orderCode: 'RO-20261113-001',
    deviceName: 'Huawei 110KTL-M0',
    serialNumber: '6T1989871495',
    diagnosedErrors: const [
      DiagnosedErrorModel(label: 'Hỏng công suất IGBT', severity: 'CRITICAL'),
      DiagnosedErrorModel(label: 'Cháy relay đóng ngắt', severity: 'MEDIUM'),
    ],
    lineItems: const [
      QuotationLineItemModel(
        id: 'li-1',
        description: 'Thay thế Module IGBT',
        quantity: 1,
        unitPrice: 3200000,
        amount: 3200000,
      ),
    ],
    baseCost: 3200000,
    warrantyOptions: const [
      WarrantyOptionModel(
        code: '6M',
        label: 'Bảo hành 6 tháng',
        description: 'Gói tiêu chuẩn',
        months: 6,
        fee: 0,
      ),
      WarrantyOptionModel(
        code: '12M',
        label: 'Bảo hành 1 năm',
        description: 'Bảo vệ toàn diện linh kiện',
        months: 12,
        fee: 500000,
      ),
    ],
    warrantyFee: 0,
    finalAmount: 3200000,
    decision: 'PENDING',
    decisionLabel: 'Chờ khách duyệt',
  );

  final item2 = QuotationItemModel(
    id: 'qi-2',
    repairOrderId: 'ro-2',
    orderCode: 'RO-20261113-002',
    deviceName: 'Sungrow SG110CX',
    serialNumber: 'SG20260099',
    diagnosedErrors: const [
      DiagnosedErrorModel(label: 'Lỗi bo nguồn AC/DC', severity: 'HIGH'),
    ],
    lineItems: const [
      QuotationLineItemModel(
        id: 'li-2',
        description: 'Phục hồi mạch nguồn DC',
        quantity: 1,
        unitPrice: 1800000,
        amount: 1800000,
      ),
    ],
    baseCost: 1800000,
    warrantyOptions: const [
      WarrantyOptionModel(
        code: '6M',
        label: 'Bảo hành 6 tháng',
        description: 'Gói tiêu chuẩn',
        months: 6,
        fee: 0,
      ),
      WarrantyOptionModel(
        code: '12M',
        label: 'Bảo hành 1 năm',
        description: 'Bảo vệ toàn diện linh kiện',
        months: 12,
        fee: 500000,
      ),
    ],
    warrantyFee: 0,
    finalAmount: 1800000,
    decision: 'PENDING',
    decisionLabel: 'Chờ khách duyệt',
  );

  final items = itemCount >= 2 ? [item1, item2] : [item1];

  return RepairQuotationModel(
    id: 'q-1',
    quoteCode: 'QT-20261113-001',
    customerId: 'cust-1',
    customerName: 'Công ty Điện Mặt Trời',
    status: 'SENT',
    statusLabel: 'Đã gửi khách',
    totalEstimatedAmount: itemCount >= 2 ? 5000000 : 3200000,
    totalApprovedAmount: 0,
    createdAt: '2026-11-13T07:00:00Z',
    itemCount: items.length,
    approvedItemCount: 0,
    rejectedItemCount: 0,
    pendingItemCount: items.length,
    bankInfo: const QuotationBankInfoModel(
      bankName: 'MB Bank (Quân Đội)',
      bankBin: '970422',
      bankAccountNumber: '9964266771',
      bankAccountHolder: 'CONG TY TNHH KY THUAT CONG NGHE',
      transferContent: 'QT-20261113-001',
      transferAmount: 3200000,
      vietQrPayload: '00020101021238570010A000000727012700069704220113996426677153037045802VN6304ABCD',
    ),
    items: items,
    paymentProofs: const [],
  );
}

void main() {
  testWidgets('CustomerQuotationSheet single-device mode hides pill tabs and updates warranty total',
      (tester) async {
    final auth = AuthProvider(apiClient: ApiClient(baseUrl: 'https://test.api'));
    final quotation = _buildSampleQuotation(itemCount: 1);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: CustomerQuotationSheet(
              quotation: quotation,
              hotlineNumber: '0964 266 771',
              onUpdated: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Huawei 110KTL-M0'), findsOneWidget);
    expect(find.text('RO-20261113-001'), findsOneWidget);
    expect(find.text('THIẾT BỊ TRONG BÁO GIÁ'), findsNothing);
    expect(find.text('3.200.000 đ'), findsWidgets);
    expect(find.text('Đồng ý & Bắt đầu sửa'), findsOneWidget);

    final w12 = find.text('Bảo hành 1 năm');
    await tester.ensureVisible(w12);
    await tester.tap(w12);
    await tester.pumpAndSettle();

    expect(find.text('3.700.000 đ'), findsOneWidget);
  });

  testWidgets('CustomerQuotationSheet multi-device mode supports independent tabs, warranty & reject',
      (tester) async {
    final auth = AuthProvider(apiClient: ApiClient(baseUrl: 'https://test.api'));
    final quotation = _buildSampleQuotation(itemCount: 2);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: CustomerQuotationSheet(
              quotation: quotation,
              hotlineNumber: '0964 266 771',
              onUpdated: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('THIẾT BỊ TRONG BÁO GIÁ'), findsOneWidget);
    expect(find.text('Đồng ý 2/2 máy'), findsOneWidget);
    expect(find.text('5.000.000 đ'), findsOneWidget);

    // Switch to Device 2 and reject it
    await tester.tap(find.text('Máy 2: Sungrow SG110CX'));
    await tester.pumpAndSettle();

    expect(find.text('RO-20261113-002'), findsOneWidget);
    final rejectBtn = find.text('Từ chối sửa');
    await tester.ensureVisible(rejectBtn);
    await tester.tap(rejectBtn);
    await tester.pumpAndSettle();

    expect(find.text('Đồng ý 1/2 máy'), findsOneWidget);
    expect(find.text('3.200.000 đ'), findsOneWidget);
    expect(find.text('Xác nhận phương án (1 máy đồng ý)'), findsOneWidget);
  });

  testWidgets('CustomerQuotationSheet renders Screen 2 VietQR and optional skip when already approved',
      (tester) async {
    final auth = AuthProvider(apiClient: ApiClient(baseUrl: 'https://test.api'));
    final base = _buildSampleQuotation(itemCount: 1);
    final approved = RepairQuotationModel(
      id: base.id,
      quoteCode: base.quoteCode,
      customerId: base.customerId,
      customerName: base.customerName,
      status: 'APPROVED',
      statusLabel: 'Đã duyệt',
      totalEstimatedAmount: 3200000,
      totalApprovedAmount: 3200000,
      createdAt: base.createdAt,
      itemCount: 1,
      approvedItemCount: 1,
      rejectedItemCount: 0,
      pendingItemCount: 0,
      bankInfo: base.bankInfo,
      items: base.items,
      paymentProofs: const [],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Scaffold(
            body: CustomerQuotationSheet(
              quotation: approved,
              hotlineNumber: '0964 266 771',
              onUpdated: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QT-20261113-001'), findsOneWidget);
    expect(find.text('Thanh toán sau / Đóng'), findsOneWidget);
  });
}

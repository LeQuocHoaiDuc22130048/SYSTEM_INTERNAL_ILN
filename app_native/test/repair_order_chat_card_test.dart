import 'package:flutter_test/flutter_test.dart';
import 'package:system_inverter_likenew/models/repair_order.dart';
import 'package:system_inverter_likenew/models/chat_repair_order_card.dart';

void main() {
  test('shared order keeps readable text and decodes card reference', () {
    final order = RepairOrder(
      id: '12345678-1234-1234-1234-123456789abc',
      orderNumber: 'RO-001',
      deviceName: 'Biến tần\nSiemens',
      customerName: 'Nguyễn Văn An',
      customerPhone: '0901234567',
      status: RepairOrderStatus.inProgress,
      createdAt: DateTime(2026),
    );
    final text = ChatRepairOrderCard.fromOrder(order).toContent();
    expect(text, contains('Đơn sửa chữa: RO-001'));
    expect(text, contains('Khách hàng: Nguyễn Văn An'));
    expect(text, contains('Điện thoại: 0901234567'));
    final decoded = ChatRepairOrderCard.tryParse(text)!;
    expect(decoded.orderId, '12345678-1234-1234-1234-123456789abc');
    expect(decoded.deviceName, 'Biến tần Siemens');
    expect(decoded.statusLabel, 'Đang sửa');
    expect(decoded.toContent(), contains('Khách hàng: Nguyễn Văn An'));
    expect(decoded.toContent(), contains('Điện thoại: 0901234567'));
  });

  test('shared card uses first photo rather than first video attachment', () {
    final order = RepairOrder(
      id: '12345678-1234-1234-1234-123456789abc',
      orderNumber: 'RO-002',
      deviceName: 'Máy',
      customerName: 'Khách hàng',
      status: RepairOrderStatus.pending,
      createdAt: DateTime(2026),
      media: const [
        RepairMedia(
          id: 'video',
          url: '/api/v1/repair-media/video.mp4',
          type: 'VIDEO',
        ),
        RepairMedia(
          id: 'first',
          url: '/api/v1/repair-media/first.jpg',
          type: 'IMAGE',
        ),
        RepairMedia(
          id: 'second',
          url: '/api/v1/repair-media/second.jpg',
          type: 'IMAGE',
        ),
      ],
    );
    final content = ChatRepairOrderCard.fromOrder(order).toContent();
    expect(content, contains('Ảnh: /api/v1/repair-media/first.jpg'));
    expect(content, isNot(contains('second.jpg')));
    expect(content, isNot(contains('video.mp4')));
    expect(
      ChatRepairOrderCard.tryParse(content)!.toContent(),
      contains('Ảnh: /api/v1/repair-media/first.jpg'),
    );
  });

  test('legacy four-line order card still parses', () {
    final card = ChatRepairOrderCard.tryParse(
      'Đơn sửa chữa: RO-001\nThiết bị: Máy\nTrạng thái: Đang sửa\nsystem-inverter://repair-orders/12345678-1234-1234-1234-123456789abc',
    );
    expect(card, isNotNull);
    expect(card!.orderNumber, 'RO-001');
  });

  test('arbitrary links and malformed cards remain normal text', () {
    expect(ChatRepairOrderCard.tryParse('hello'), isNull);
    expect(
      ChatRepairOrderCard.tryParse(
        'Đơn sửa chữa: RO\nThiết bị: Máy\nTrạng thái: Đang sửa\nhttps://evil.test/repair-orders/123',
      ),
      isNull,
    );
    expect(
      ChatRepairOrderCard.tryParse(
        'Đơn sửa chữa: RO\nThiết bị: Máy\nTrạng thái: Đang sửa\nsystem-inverter://repair-orders/../../bad',
      ),
      isNull,
    );
  });
}

import 'repair_order.dart';

/// Readable TEXT payload keeps older mobile/web clients compatible.
class ChatRepairOrderCard {
  const ChatRepairOrderCard({
    required this.orderId,
    required this.orderNumber,
    required this.deviceName,
    required this.statusLabel,
    this.customerName,
    this.customerPhone,
    this.imagePath,
  });
  final String orderId;
  final String orderNumber;
  final String deviceName;
  final String statusLabel;
  final String? customerName;
  final String? customerPhone;
  final String? imagePath;

  factory ChatRepairOrderCard.fromOrder(RepairOrder order) =>
      ChatRepairOrderCard(
        orderId: order.id,
        orderNumber: order.orderNumber,
        deviceName: order.deviceName,
        statusLabel: order.statusLabel,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        imagePath: order.imagePath,
      );

  String toContent() {
    String singleLine(String value) =>
        value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    return [
      'Đơn sửa chữa: ${singleLine(orderNumber)}',
      'Thiết bị: ${singleLine(deviceName)}',
      'Trạng thái: ${singleLine(statusLabel)}',
      'Khách hàng: ${singleLine(customerName ?? '')}',
      'Điện thoại: ${singleLine(customerPhone ?? '')}',
      'Ảnh: ${singleLine(imagePath ?? '')}',
      'system-inverter://repair-orders/$orderId',
    ].join('\n');
  }

  static ChatRepairOrderCard? tryParse(String content) {
    final lines = content.split('\n');
    if ((lines.length != 4 && lines.length != 7) ||
        !lines[0].startsWith('Đơn sửa chữa: ') ||
        !lines[1].startsWith('Thiết bị: ') ||
        !lines[2].startsWith('Trạng thái: ')) {
      return null;
    }
    final hasDetails = lines.length == 7;
    if (hasDetails &&
        (!lines[3].startsWith('Khách hàng: ') ||
            !lines[4].startsWith('Điện thoại: ') ||
            !lines[5].startsWith('Ảnh: '))) {
      return null;
    }
    final uri = Uri.tryParse(lines.last);
    if (uri == null ||
        uri.scheme != 'system-inverter' ||
        uri.host != 'repair-orders' ||
        uri.pathSegments.length != 1 ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final id = uri.pathSegments.single;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      return null;
    }
    final number = lines[0].substring('Đơn sửa chữa: '.length).trim();
    final device = lines[1].substring('Thiết bị: '.length).trim();
    final status = lines[2].substring('Trạng thái: '.length).trim();
    if (number.isEmpty || device.isEmpty || status.isEmpty) return null;
    return ChatRepairOrderCard(
      orderId: id,
      orderNumber: number,
      deviceName: device,
      statusLabel: status,
      customerName: hasDetails
          ? lines[3].substring('Khách hàng: '.length).trim()
          : null,
      customerPhone: hasDetails
          ? lines[4].substring('Điện thoại: '.length).trim()
          : null,
      imagePath: hasDetails ? lines[5].substring('Ảnh: '.length).trim() : null,
    );
  }
}

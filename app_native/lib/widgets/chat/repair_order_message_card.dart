import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_repair_order_card.dart';
import '../../screens/repair_orders_page.dart';
import '../../utils/auth_provider.dart';
import '../../utils/media_auth_headers.dart';

class RepairOrderMessageCard extends StatefulWidget {
  const RepairOrderMessageCard({
    super.key,
    required this.card,
    required this.color,
  });
  final ChatRepairOrderCard card;
  final Color color;
  @override
  State<RepairOrderMessageCard> createState() => _RepairOrderMessageCardState();
}

class _RepairOrderMessageCardState extends State<RepairOrderMessageCard> {
  bool _opening = false;
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await showRepairOrderDetails(context, widget.card.orderId);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: _opening ? null : _open,
    child: Semantics(
      button: true,
      label: 'Mở đơn sửa chữa ${widget.card.orderNumber}',
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(aspectRatio: 16 / 9, child: _photo(context)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.build_circle_outlined,
                  color: widget.color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đơn sửa chữa',
                    style: TextStyle(color: widget.color, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.card.orderNumber,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.card.deviceName,
              style: TextStyle(color: widget.color, fontSize: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              widget.card.statusLabel,
              style: TextStyle(color: widget.color, fontSize: 13),
            ),
            Divider(height: 24, color: widget.color.withValues(alpha: 0.2)),
            Text(
              'Khách hàng',
              style: TextStyle(
                color: widget.color.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            _customerDetail(
              Icons.person_outline,
              widget.card.customerName?.trim().isNotEmpty == true
                  ? widget.card.customerName!.trim()
                  : 'Chưa có thông tin khách hàng',
            ),
            if (widget.card.customerPhone?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _customerDetail(
                Icons.phone_outlined,
                widget.card.customerPhone!.trim(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _opening ? 'Đang mở...' : 'Xem chi tiết ›',
              style: TextStyle(
                color: widget.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _customerDetail(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: widget.color, size: 18),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: widget.color, fontSize: 14),
        ),
      ),
    ],
  );

  Widget _photo(BuildContext context) {
    final imagePath = widget.card.imagePath?.trim();
    if (imagePath == null || imagePath.isEmpty) return _defaultPhoto(context);
    final api = context.read<AuthProvider?>()?.api;
    String url;
    try {
      url = api?.resolveUrl(imagePath) ?? imagePath;
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          !uri.hasAuthority) {
        return _defaultPhoto(context);
      }
    } catch (_) {
      return _defaultPhoto(context);
    }
    return Image.network(
      url,
      headers: mediaAuthHeaders(context, url),
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorBuilder: (context, error, stackTrace) => _defaultPhoto(context),
    );
  }

  Widget _defaultPhoto(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có ảnh',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

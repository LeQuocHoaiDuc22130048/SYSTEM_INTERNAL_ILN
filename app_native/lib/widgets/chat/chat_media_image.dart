import 'package:flutter/material.dart';
import '../image_preview_dialog.dart';
import '../../utils/media_auth_headers.dart';

class ChatMediaImage extends StatelessWidget {
  final String imageUrl;
  final String? caption;
  final bool isSticker;

  const ChatMediaImage({
    super.key,
    required this.imageUrl,
    this.caption,
    this.isSticker = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isSticker ? 'Xem nhãn dán' : 'Xem hình ảnh',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              ImagePreviewDialog(imageUrl: imageUrl, caption: caption),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: isSticker ? 150 : 220,
            height: isSticker ? 150 : 180,
            child: Image.network(
              imageUrl,
              headers: mediaAuthHeaders(context, imageUrl),
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Không thể tải ảnh',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

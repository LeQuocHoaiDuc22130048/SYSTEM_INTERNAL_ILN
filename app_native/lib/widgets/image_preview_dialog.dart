import 'package:flutter/material.dart';
import '../utils/media_auth_headers.dart';

class ImagePreviewDialog extends StatefulWidget {
  final String imageUrl;
  final String? caption;

  const ImagePreviewDialog({super.key, required this.imageUrl, this.caption});

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  final _transformation = TransformationController();
  double _downwardDistance = 0;
  bool _canDismiss = false;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerCancel: (_) {
                  _canDismiss = false;
                  _downwardDistance = 0;
                },
                child: InteractiveViewer(
                  transformationController: _transformation,
                  minScale: 1,
                  maxScale: 4,
                  onInteractionStart: (details) {
                    _downwardDistance = 0;
                    _canDismiss =
                        details.pointerCount == 1 &&
                        _transformation.value.getMaxScaleOnAxis() <= 1.01;
                  },
                  onInteractionUpdate: (details) {
                    if (details.pointerCount != 1 ||
                        _transformation.value.getMaxScaleOnAxis() > 1.01) {
                      _canDismiss = false;
                    }
                    _downwardDistance += details.focalPointDelta.dy;
                  },
                  onInteractionEnd: (_) {
                    if (_canDismiss && _downwardDistance > 100) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Center(
                    child: Image.network(
                      widget.imageUrl,
                      headers: mediaAuthHeaders(context, widget.imageUrl),
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white70,
                              ),
                            ),
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Không thể hiển thị hình ảnh này.',
                                  style: TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
            if (widget.caption?.trim().isNotEmpty == true)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

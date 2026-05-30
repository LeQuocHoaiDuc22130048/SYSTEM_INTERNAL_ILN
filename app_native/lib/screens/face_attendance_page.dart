import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as image_lib;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

enum FaceCapturePurpose { attendance, enrollment }

class FaceCaptureResult {
  final String faceImageBase64;
  final String imageContentType;

  const FaceCaptureResult({
    required this.faceImageBase64,
    required this.imageContentType,
  });
}

class FaceAttendancePage extends StatefulWidget {
  final FaceCapturePurpose purpose;

  const FaceAttendancePage({
    super.key,
    this.purpose = FaceCapturePurpose.attendance,
  });

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.2,
    ),
  );

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  FaceCaptureResult? _captureResult;
  String _status = 'Đưa khuôn mặt vào giữa khung hình';
  bool _isScanning = true;
  bool _isDisposed = false;

  bool get _isEnrollment => widget.purpose == FaceCapturePurpose.enrollment;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Không tìm thấy camera.');
      }
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      _initializeControllerFuture = controller.initialize();
      await _initializeControllerFuture;
      if (!mounted) return;
      setState(() {});
      unawaited(_scanUntilCaptured());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _status = 'Không thể mở camera: $error';
      });
    }
  }

  Future<void> _scanUntilCaptured() async {
    while (mounted && !_isDisposed && _captureResult == null) {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      try {
        final image = await controller.takePicture();
        final faces = await _faceDetector.processImage(
          InputImage.fromFilePath(image.path),
        );
        if (!mounted || _isDisposed) return;
        final result = await _resultFromFaces(image.path, faces);
        if (result != null) {
          setState(() {
            _captureResult = result;
            _isScanning = false;
            _status = _isEnrollment
                ? 'Đã thu mẫu khuôn mặt'
                : 'Đã phát hiện khuôn mặt';
          });
          return;
        }
      } catch (error) {
        if (!mounted || _isDisposed) return;
        setState(() => _status = 'Đang thử lại khung hình camera...');
      }
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  Future<FaceCaptureResult?> _resultFromFaces(
    String imagePath,
    List<Face> faces,
  ) async {
    if (faces.length != 1) {
      setState(() {
        _status = faces.isEmpty
            ? 'Chưa thấy khuôn mặt'
            : 'Chỉ để một khuôn mặt trong khung hình';
      });
      return null;
    }
    final face = faces.single;
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    if (yaw > 12 || roll > 12) {
      setState(() => _status = 'Vui lòng nhìn thẳng vào camera');
      return null;
    }

    final bounds = face.boundingBox;
    if (bounds.width <= 0 || bounds.height <= 0) return null;
    return _cropFaceImage(imagePath, bounds);
  }

  Future<FaceCaptureResult?> _cropFaceImage(
    String imagePath,
    Rect faceBounds,
  ) async {
    final originalBytes = await File(imagePath).readAsBytes();
    var source = image_lib.decodeImage(originalBytes);
    if (source == null) {
      setState(() => _status = 'Không thể đọc ảnh camera');
      return null;
    }
    source = image_lib.bakeOrientation(source);

    const paddingRatio = 0.18;
    final paddingX = faceBounds.width * paddingRatio;
    final paddingY = faceBounds.height * paddingRatio;
    final left = (faceBounds.left - paddingX)
        .floor()
        .clamp(0, source.width - 1)
        .toInt();
    final top = (faceBounds.top - paddingY)
        .floor()
        .clamp(0, source.height - 1)
        .toInt();
    final right = (faceBounds.right + paddingX)
        .ceil()
        .clamp(left + 1, source.width)
        .toInt();
    final bottom = (faceBounds.bottom + paddingY)
        .ceil()
        .clamp(top + 1, source.height)
        .toInt();

    final cropped = image_lib.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    final jpegBytes = image_lib.encodeJpg(cropped, quality: 88);
    return FaceCaptureResult(
      faceImageBase64: base64Encode(jpegBytes),
      imageContentType: 'image/jpeg',
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _captureResult;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null) {
                  return CameraPreview(_controller!);
                }
                return Center(
                  child: Icon(
                    LucideIcons.user,
                    size: 240,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  _isEnrollment ? 'ĐĂNG KÝ KHUÔN MẶT' : 'NHẬN DIỆN KHUÔN MẶT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildScannerFrame(result != null),
                const Spacer(),
                Text(
                  result != null ? _status : 'Đang quét...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    result != null
                        ? 'Ảnh khuôn mặt đã crop sẵn sàng để AI xác minh.'
                        : _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(
                              alpha: 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Hủy bỏ'),
                        ),
                      ),
                      if (result != null) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, result),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Xác nhận'),
                          ).animate().fadeIn().scale(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerFrame(bool succeeded) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isScanning)
          Container(
                width: 280,
                height: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(140),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 1.seconds,
              ),
        Container(
          width: 260,
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(130),
            border: Border.all(
              color: succeeded
                  ? AppColors.success
                  : Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: succeeded
              ? Center(
                  child: const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 80,
                  ).animate().scale(duration: 400.ms),
                )
              : null,
        ),
      ],
    );
  }
}

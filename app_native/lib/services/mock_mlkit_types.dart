import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum FaceLandmarkType {
  bottomMouth,
  leftCheek,
  leftEar,
  leftEye,
  leftMouth,
  noseBase,
  rightCheek,
  rightEar,
  rightEye,
  rightMouth,
}

enum FaceContourType {
  face,
  leftEye,
  leftEyebrowBottom,
  leftEyebrowTop,
  lowerLipBottom,
  lowerLipTop,
  noseBottom,
  noseBridge,
  rightEye,
  rightEyebrowBottom,
  rightEyebrowTop,
  upperLipBottom,
  upperLipTop,
}

enum FaceDetectorMode { fast, accurate }

class FaceLandmark {
  final FaceLandmarkType type;
  final Point<int> position;

  const FaceLandmark({required this.type, required this.position});
}

class FaceContour {
  final FaceContourType type;
  final List<Point<int>> points;

  const FaceContour({required this.type, required this.points});
}

class Face {
  final Rect boundingBox;
  final double? headEulerAngleX;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? smilingProbability;
  final int? trackingId;
  final Map<FaceLandmarkType, FaceLandmark?> landmarks;
  final Map<FaceContourType, FaceContour?> contours;

  Face({
    required this.boundingBox,
    this.headEulerAngleX = 0,
    this.headEulerAngleY = 0,
    this.headEulerAngleZ = 0,
    this.leftEyeOpenProbability = 0.95,
    this.rightEyeOpenProbability = 0.95,
    this.smilingProbability = 0.5,
    this.trackingId,
    Map<FaceLandmarkType, FaceLandmark?>? landmarks,
    Map<FaceContourType, FaceContour?>? contours,
  })  : landmarks = landmarks ?? _defaultLandmarks(boundingBox),
        contours = contours ?? const {};

  static Map<FaceLandmarkType, FaceLandmark?> _defaultLandmarks(Rect box) {
    final cx = box.center.dx.round();
    final cy = box.center.dy.round();
    final halfW = (box.width / 4).round();
    final halfH = (box.height / 4).round();

    return {
      FaceLandmarkType.leftEye: FaceLandmark(
        type: FaceLandmarkType.leftEye,
        position: Point(cx - halfW, cy - halfH),
      ),
      FaceLandmarkType.rightEye: FaceLandmark(
        type: FaceLandmarkType.rightEye,
        position: Point(cx + halfW, cy - halfH),
      ),
      FaceLandmarkType.noseBase: FaceLandmark(
        type: FaceLandmarkType.noseBase,
        position: Point(cx, cy),
      ),
      FaceLandmarkType.leftMouth: FaceLandmark(
        type: FaceLandmarkType.leftMouth,
        position: Point(cx - halfW ~/ 2, cy + halfH),
      ),
      FaceLandmarkType.rightMouth: FaceLandmark(
        type: FaceLandmarkType.rightMouth,
        position: Point(cx + halfW ~/ 2, cy + halfH),
      ),
      FaceLandmarkType.bottomMouth: FaceLandmark(
        type: FaceLandmarkType.bottomMouth,
        position: Point(cx, cy + halfH + 10),
      ),
    };
  }
}

class FaceDetectorOptions {
  final bool enableClassification;
  final bool enableLandmarks;
  final bool enableTracking;
  final double minFaceSize;
  final FaceDetectorMode performanceMode;

  const FaceDetectorOptions({
    this.enableClassification = false,
    this.enableLandmarks = false,
    this.enableTracking = false,
    this.minFaceSize = 0.1,
    this.performanceMode = FaceDetectorMode.fast,
  });
}

enum InputImageFormat {
  nv21,
  yv12,
  yuv_420_888,
  yuv420,
  bgra8888,
  nv12,
}

class InputImageFormatValue {
  static InputImageFormat? fromRawValue(int rawValue) {
    return InputImageFormat.bgra8888;
  }
}

enum InputImageRotation {
  rotation0deg,
  rotation90deg,
  rotation180deg,
  rotation270deg,
}

class InputImageRotationValue {
  static InputImageRotation? fromRawValue(int rawValue) {
    return switch (rawValue) {
      90 => InputImageRotation.rotation90deg,
      180 => InputImageRotation.rotation180deg,
      270 => InputImageRotation.rotation270deg,
      _ => InputImageRotation.rotation0deg,
    };
  }
}

class InputImageMetadata {
  final Size size;
  final InputImageRotation rotation;
  final InputImageFormat format;
  final int bytesPerRow;

  const InputImageMetadata({
    required this.size,
    required this.rotation,
    required this.format,
    required this.bytesPerRow,
  });
}

class InputImage {
  final String? filePath;
  final Uint8List? bytes;
  final InputImageMetadata? metadata;

  InputImage.fromFilePath(this.filePath)
      : bytes = null,
        metadata = null;

  InputImage.fromBytes({required this.bytes, required this.metadata})
      : filePath = null;
}

class FaceDetector {
  final FaceDetectorOptions options;

  FaceDetector({required this.options});

  Future<List<Face>> processImage(InputImage inputImage) async {
    // Generate a default center face for simulator testing
    final width = inputImage.metadata?.size.width ?? 480.0;
    final height = inputImage.metadata?.size.height ?? 640.0;
    final faceWidth = width * 0.5;
    final faceHeight = height * 0.5;
    final left = (width - faceWidth) / 2;
    final top = (height - faceHeight) / 2;

    return [
      Face(
        boundingBox: Rect.fromLTWH(left, top, faceWidth, faceHeight),
        headEulerAngleY: 0,
        headEulerAngleZ: 0,
        leftEyeOpenProbability: 0.95,
        rightEyeOpenProbability: 0.95,
      ),
    ];
  }

  Future<void> close() async {}
}

class Barcode {
  final String? rawValue;
  const Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;
  const BarcodeCapture({this.barcodes = const []});
}

class MobileScannerController {
  bool torchEnabled = false;
  void toggleTorch() {
    torchEnabled = !torchEnabled;
  }
  void dispose() {}
}

class MobileScanner extends StatelessWidget {
  final MobileScannerController? controller;
  final void Function(BarcodeCapture)? onDetect;

  const MobileScanner({super.key, this.controller, this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 72, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Giả lập quét mã QR',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                onDetect?.call(
                  const BarcodeCapture(
                    barcodes: [Barcode(rawValue: 'DEMO-QR-TEST-123')],
                  ),
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Nhấn để quét mã mẫu'),
            ),
          ],
        ),
      ),
    );
  }
}


import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'mock_mlkit_types.dart';
import 'package:image/image.dart' as img;

class DetectedFace {
  final Face face;
  final img.Image frame;

  const DetectedFace({required this.face, required this.frame});
}

class FaceQualityMetrics {
  const FaceQualityMetrics({
    required this.yaw,
    required this.roll,
    required this.brightness,
    required this.blurVariance,
    required this.faceWidth,
    required this.faceHeight,
  });

  final double yaw;
  final double roll;
  final double brightness;
  final double blurVariance;
  final double faceWidth;
  final double faceHeight;
}

class FaceDetectionQualityResult {
  const FaceDetectionQualityResult._({
    this.detectedFace,
    this.metrics,
    this.message,
  });

  final DetectedFace? detectedFace;
  final FaceQualityMetrics? metrics;
  final String? message;

  bool get isAccepted => detectedFace != null;

  factory FaceDetectionQualityResult.accepted(
    DetectedFace detectedFace,
    FaceQualityMetrics metrics,
  ) {
    return FaceDetectionQualityResult._(
      detectedFace: detectedFace,
      metrics: metrics,
    );
  }

  factory FaceDetectionQualityResult.rejected(String message) {
    return FaceDetectionQualityResult._(message: message);
  }
}

class FaceDetectorService {
  FaceDetectorService()
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: false,
          minFaceSize: 0.18,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

  final FaceDetector _detector;

  static const _maxYawDegrees = 12.0;
  static const _maxRollDegrees = 12.0;
  static const _minFacePixels = 96.0;
  static const _minBrightness = 55.0;
  static const _maxBrightness = 230.0;
  static const _minBlurVariance = 35.0;

  Future<DetectedFace?> detectPrimaryFace(
    CameraImage image,
    CameraDescription camera,
  ) async {
    final inputImage = _toInputImage(image, camera);
    if (inputImage == null) return null;

    final faces = await _detector.processImage(inputImage);
    if (faces.length != 1) return null;

    final face = faces.single;
    if (!_isGoodFrontalFace(face)) return null;

    final frame = _cameraImageToImage(image);
    if (frame == null) return null;

    final uprightFrame = _rotateToInputImage(frame, inputImage.metadata);
    return DetectedFace(face: face, frame: uprightFrame);
  }

  Future<DetectedFace?> detectPrimaryFaceFromFile(
    String imagePath, {
    bool requireOpenEyes = true,
    bool requireBothEyesLandmarks = true,
    double maxYawDegrees = _maxYawDegrees,
    double maxRollDegrees = _maxRollDegrees,
  }) async {
    final result = await detectPrimaryFaceFromFileWithQuality(
      imagePath,
      requireOpenEyes: requireOpenEyes,
      requireBothEyesLandmarks: requireBothEyesLandmarks,
      maxYawDegrees: maxYawDegrees,
      maxRollDegrees: maxRollDegrees,
    );
    return result.detectedFace;
  }

  Future<FaceDetectionQualityResult> detectPrimaryFaceFromFileWithQuality(
    String imagePath, {
    bool requireOpenEyes = true,
    bool requireBothEyesLandmarks = true,
    double maxYawDegrees = _maxYawDegrees,
    double maxRollDegrees = _maxRollDegrees,
  }) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    if (faces.isEmpty) {
      return FaceDetectionQualityResult.rejected(
        'Không thấy khuôn mặt. Đưa mặt vào giữa khung hình.',
      );
    }
    if (faces.length > 1) {
      return FaceDetectionQualityResult.rejected(
        'Chỉ được có 1 khuôn mặt trong khung hình.',
      );
    }

    final face = faces.single;

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return FaceDetectionQualityResult.rejected(
        'Không đọc được ảnh camera. Vui lòng thử lại.',
      );
    }
    final frame = img.bakeOrientation(decoded);
    final quality = _qualityMetrics(frame, face);
    final qualityMessage = _qualityFailureMessage(
      frame,
      face,
      metrics: quality,
      requireOpenEyes: requireOpenEyes,
      requireBothEyesLandmarks: requireBothEyesLandmarks,
      maxYawDegrees: maxYawDegrees,
      maxRollDegrees: maxRollDegrees,
    );
    if (qualityMessage != null) {
      return FaceDetectionQualityResult.rejected(qualityMessage);
    }

    return FaceDetectionQualityResult.accepted(
      DetectedFace(face: face, frame: frame),
      quality,
    );
  }

  bool _isGoodFrontalFace(Face face, {bool requireOpenEyes = true}) {
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    final leftEye = face.leftEyeOpenProbability ?? 1;
    final rightEye = face.rightEyeOpenProbability ?? 1;
    final hasEyes =
        face.landmarks[FaceLandmarkType.leftEye] != null &&
        face.landmarks[FaceLandmarkType.rightEye] != null;

    return yaw <= _maxYawDegrees &&
        roll <= _maxRollDegrees &&
        (!requireOpenEyes || (leftEye >= 0.45 && rightEye >= 0.45)) &&
        hasEyes &&
        face.boundingBox.width >= _minFacePixels &&
        face.boundingBox.height >= _minFacePixels;
  }

  String? _qualityFailureMessage(
    img.Image frame,
    Face face, {
    required FaceQualityMetrics metrics,
    required bool requireOpenEyes,
    required bool requireBothEyesLandmarks,
    required double maxYawDegrees,
    required double maxRollDegrees,
  }) {
    if (metrics.yaw.abs() > maxYawDegrees ||
        metrics.roll.abs() > maxRollDegrees) {
      if (maxYawDegrees > _maxYawDegrees) {
        return 'Quay nhẹ hơn và giữ mặt nằm trong khung hình.';
      }
      return 'Nhìn thẳng vào camera, không nghiêng hoặc quay mặt.';
    }

    if (metrics.faceWidth < _minFacePixels ||
        metrics.faceHeight < _minFacePixels) {
      return 'Khuôn mặt quá nhỏ. Đưa mặt lại gần camera hơn.';
    }

    final hasEyes =
        face.landmarks[FaceLandmarkType.leftEye] != null &&
        face.landmarks[FaceLandmarkType.rightEye] != null;
    if (requireBothEyesLandmarks && !hasEyes) {
      return 'Camera chưa thấy rõ hai mắt. Điều chỉnh lại khuôn mặt.';
    }

    if (requireOpenEyes) {
      final leftEye = face.leftEyeOpenProbability ?? 1;
      final rightEye = face.rightEyeOpenProbability ?? 1;
      if (leftEye < 0.45 || rightEye < 0.45) {
        return 'Vui lòng mở mắt và nhìn thẳng vào camera.';
      }
    }

    final crop = _safeFaceCrop(frame, face.boundingBox);
    if (crop == null) {
      return 'Khuôn mặt nằm ngoài khung hình. Căn lại khuôn mặt.';
    }

    if (metrics.brightness < _minBrightness) {
      return 'Ánh sáng quá tối. Vui lòng chụp ở nơi sáng hơn.';
    }
    if (metrics.brightness > _maxBrightness) {
      return 'Ảnh bị quá sáng. Giảm ánh sáng trực tiếp vào mặt.';
    }

    if (metrics.blurVariance < _minBlurVariance) {
      return 'Ảnh bị mờ. Giữ điện thoại ổn định và chụp lại.';
    }

    return null;
  }

  FaceQualityMetrics _qualityMetrics(img.Image frame, Face face) {
    final crop = _safeFaceCrop(frame, face.boundingBox);
    return FaceQualityMetrics(
      yaw: face.headEulerAngleY ?? 0,
      roll: face.headEulerAngleZ ?? 0,
      brightness: crop == null ? 0 : _averageBrightness(crop),
      blurVariance: crop == null ? 0 : _laplacianVariance(crop),
      faceWidth: face.boundingBox.width,
      faceHeight: face.boundingBox.height,
    );
  }

  img.Image? _safeFaceCrop(img.Image frame, Rect boundingBox) {
    final x = boundingBox.left.floor().clamp(0, frame.width - 1);
    final y = boundingBox.top.floor().clamp(0, frame.height - 1);
    final right = boundingBox.right.ceil().clamp(0, frame.width);
    final bottom = boundingBox.bottom.ceil().clamp(0, frame.height);
    final width = right - x;
    final height = bottom - y;
    if (width < 8 || height < 8) return null;
    return img.copyCrop(frame, x: x, y: y, width: width, height: height);
  }

  double _averageBrightness(img.Image image) {
    var total = 0.0;
    var count = 0;
    final step = math.max(1, math.min(image.width, image.height) ~/ 64);
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        total += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        count++;
      }
    }
    return count == 0 ? 0 : total / count;
  }

  double _laplacianVariance(img.Image image) {
    final gray = img.grayscale(
      image.width > 160 || image.height > 160
          ? img.copyResize(
              image,
              width: 160,
              height: (image.height * 160 / image.width).round(),
              interpolation: img.Interpolation.linear,
            )
          : image,
    );
    final values = <double>[];
    for (var y = 1; y < gray.height - 1; y += 2) {
      for (var x = 1; x < gray.width - 1; x += 2) {
        final center = gray.getPixel(x, y).r.toDouble();
        final laplacian =
            gray.getPixel(x - 1, y).r +
            gray.getPixel(x + 1, y).r +
            gray.getPixel(x, y - 1).r +
            gray.getPixel(x, y + 1).r -
            4 * center;
        values.add(_toDouble(laplacian));
      }
    }
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.fold<double>(
          0,
          (sum, value) => sum + math.pow(value - mean, 2),
        ) /
        values.length;
    return variance;
  }

  double _toDouble(num value) => value.toDouble();

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final rotation = _inputImageRotation(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final bytes = _concatenatePlanes(image.planes);
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  InputImageRotation _inputImageRotation(int sensorOrientation) {
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;
    }

    // Front camera frames from the camera plugin are usually mirrored by preview,
    // but ML Kit only needs the sensor rotation for detection coordinates.
    return InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  img.Image? _cameraImageToImage(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        return img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes.first.bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      case ImageFormatGroup.nv21:
        return _nv21ToImage(image);
      case ImageFormatGroup.yuv420:
        return _yuv420ToImage(image);
      default:
        return null;
    }
  }

  img.Image _rotateToInputImage(img.Image image, InputImageMetadata? metadata) {
    final rotation = metadata?.rotation ?? InputImageRotation.rotation0deg;
    return switch (rotation) {
      InputImageRotation.rotation90deg => img.copyRotate(image, angle: 90),
      InputImageRotation.rotation180deg => img.copyRotate(image, angle: 180),
      InputImageRotation.rotation270deg => img.copyRotate(image, angle: 270),
      InputImageRotation.rotation0deg => image,
    };
  }

  img.Image _yuv420ToImage(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = img.Image(width: image.width, height: image.height);

    for (var y = 0; y < image.height; y++) {
      final uvRow = (y / 2).floor();
      for (var x = 0; x < image.width; x++) {
        final uvCol = (x / 2).floor();
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex =
            uvRow * uPlane.bytesPerRow + uvCol * uPlane.bytesPerPixel!;

        final yp = yPlane.bytes[yIndex];
        final up = uPlane.bytes[uvIndex] - 128;
        final vp = vPlane.bytes[uvIndex] - 128;

        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  img.Image _nv21ToImage(CameraImage image) {
    final bytes = image.planes.first.bytes;
    final frameSize = image.width * image.height;
    final out = img.Image(width: image.width, height: image.height);

    for (var y = 0; y < image.height; y++) {
      var uvIndex = frameSize + (y >> 1) * image.width;
      for (var x = 0; x < image.width; x++) {
        final yp = bytes[y * image.width + x];
        final vp = bytes[uvIndex + (x & ~1)] - 128;
        final up = bytes[uvIndex + (x & ~1) + 1] - 128;

        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  Future<void> dispose() => _detector.close();
}

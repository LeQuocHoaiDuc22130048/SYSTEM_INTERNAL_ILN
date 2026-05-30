import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class DetectedFace {
  final Face face;
  final img.Image frame;

  const DetectedFace({required this.face, required this.frame});
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

  Future<DetectedFace?> detectPrimaryFaceFromFile(String imagePath) async {
    final faces = await _detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    if (faces.length != 1) return null;

    final face = faces.single;
    if (!_isGoodFrontalFace(face)) return null;

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    return DetectedFace(face: face, frame: img.bakeOrientation(decoded));
  }

  bool _isGoodFrontalFace(Face face) {
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    final leftEye = face.leftEyeOpenProbability ?? 1;
    final rightEye = face.rightEyeOpenProbability ?? 1;
    final hasEyes =
        face.landmarks[FaceLandmarkType.leftEye] != null &&
        face.landmarks[FaceLandmarkType.rightEye] != null;

    return yaw <= 12 &&
        roll <= 12 &&
        leftEye >= 0.45 &&
        rightEye >= 0.45 &&
        hasEyes &&
        face.boundingBox.width > 72 &&
        face.boundingBox.height > 72;
  }

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

import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'mock_mlkit_types.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum FaceEmbeddingLayout { nhwc, nchw }

enum FaceEmbeddingNormalization { minusOneToOne, zeroToOne, zeroTo255 }

enum FaceEmbeddingChannelOrder { rgb, bgr }

class MissingFaceModelException implements Exception {
  const MissingFaceModelException(this.primaryPath, this.fallbackPath);

  final String primaryPath;
  final String fallbackPath;

  @override
  String toString() {
    return 'Chưa có model nhận diện khuôn mặt. Đặt face_embedding.tflite vào '
        '$primaryPath hoặc $fallbackPath rồi rebuild app.';
  }
}

class EmbeddingService {
  EmbeddingService({
    this.modelName = 'face-embedding',
    this.modelAssetPath = 'assets/models/face_embedding.tflite',
    this.fallbackModelAssetPath = 'assets/model/face_embedding.tflite',
    this.inputSize = 112,
    this.normalization = FaceEmbeddingNormalization.minusOneToOne,
    this.channelOrder = FaceEmbeddingChannelOrder.rgb,
  });

  final String modelName;
  final String modelAssetPath;
  final String fallbackModelAssetPath;
  final int inputSize;
  final FaceEmbeddingNormalization normalization;
  final FaceEmbeddingChannelOrder channelOrder;

  Interpreter? _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;

  Future<void> init() async {
    if (_interpreter != null) return;

    final options = InterpreterOptions()..threads = 2;
    final interpreter = await _loadInterpreter(options);
    _interpreter = interpreter;
    _inputShape = interpreter.getInputTensor(0).shape;
    _outputShape = interpreter.getOutputTensor(0).shape;
  }

  Future<Interpreter> _loadInterpreter(InterpreterOptions options) async {
    try {
      return await Interpreter.fromAsset(modelAssetPath, options: options);
    } on FlutterError {
      try {
        return await Interpreter.fromAsset(
          fallbackModelAssetPath,
          options: options,
        );
      } on FlutterError {
        throw MissingFaceModelException(modelAssetPath, fallbackModelAssetPath);
      }
    }
  }

  Future<List<double>> extractEmbedding({
    required img.Image frame,
    required Face face,
  }) async {
    final alignedFace = alignFace(frame: frame, face: face);
    return extractEmbeddingFromAligned(alignedFace);
  }

  Future<List<double>> extractEmbeddingFromAligned(
    img.Image alignedFace,
  ) async {
    await init();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('TFLite interpreter is not initialized.');
    }

    final input = _preprocessAligned(alignedFace);
    final outputLength = _outputShape.fold<int>(1, (a, b) => a * b);
    final output = List<double>.filled(outputLength, 0).reshape(_outputShape);

    interpreter.run(input, output);
    return _l2Normalize(_flatten(output));
  }

  img.Image alignFace({
    required img.Image frame,
    required Face face,
    int? outputWidth,
    int? outputHeight,
  }) {
    final width = outputWidth ?? inputSize;
    final height = outputHeight ?? inputSize;
    final source = _landmarkPoints(face);
    if (source == null) {
      return _cropByBounds(frame, face.boundingBox, width, height);
    }

    final destination = _fivePointFaceTemplate(width, height);
    final transform = _estimateSimilarityTransform(source, destination);
    if (transform == null) {
      return _cropByBounds(frame, face.boundingBox, width, height);
    }

    return _warpSimilarity(frame, width, height, transform);
  }

  Object _preprocessAligned(img.Image alignedFace) {
    final layout = _layoutFromShape(_inputShape);
    final width = _modelWidth(layout);
    final height = _modelHeight(layout);
    final aligned = alignedFace.width == width && alignedFace.height == height
        ? alignedFace
        : img.copyResize(
            alignedFace,
            width: width,
            height: height,
            interpolation: img.Interpolation.linear,
          );

    return switch (layout) {
      FaceEmbeddingLayout.nhwc => _toNhwc(aligned, width, height),
      FaceEmbeddingLayout.nchw => _toNchw(aligned, width, height),
    };
  }

  img.Image _cropByBounds(img.Image frame, Rect bounds, int width, int height) {
    const paddingRatio = 0.20;
    final padX = bounds.width * paddingRatio;
    final padY = bounds.height * paddingRatio;

    final left = (bounds.left - padX).floor().clamp(0, frame.width - 1);
    final top = (bounds.top - padY).floor().clamp(0, frame.height - 1);
    final right = (bounds.right + padX).ceil().clamp(left + 1, frame.width);
    final bottom = (bounds.bottom + padY).ceil().clamp(top + 1, frame.height);

    final cropped = img.copyCrop(
      frame,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
    final resized = img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    return resized;
  }

  List<Point<double>>? _landmarkPoints(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (leftEye == null ||
        rightEye == null ||
        nose == null ||
        leftMouth == null ||
        rightMouth == null) {
      return null;
    }

    return [
      Point(leftEye.x.toDouble(), leftEye.y.toDouble()),
      Point(rightEye.x.toDouble(), rightEye.y.toDouble()),
      Point(nose.x.toDouble(), nose.y.toDouble()),
      Point(leftMouth.x.toDouble(), leftMouth.y.toDouble()),
      Point(rightMouth.x.toDouble(), rightMouth.y.toDouble()),
    ];
  }

  List<Point<double>> _fivePointFaceTemplate(int width, int height) {
    const base = [
      Point(38.2946, 51.6963),
      Point(73.5318, 51.5014),
      Point(56.0252, 71.7366),
      Point(41.5493, 92.3655),
      Point(70.7299, 92.2041),
    ];
    final scaleX = width / 112.0;
    final scaleY = height / 112.0;
    return base.map((p) => Point(p.x * scaleX, p.y * scaleY)).toList();
  }

  _SimilarityTransform? _estimateSimilarityTransform(
    List<Point<double>> source,
    List<Point<double>> destination,
  ) {
    if (source.length != destination.length || source.length < 2) return null;

    final srcMean = _meanPoint(source);
    final dstMean = _meanPoint(destination);
    var numeratorA = 0.0;
    var numeratorB = 0.0;
    var denominator = 0.0;

    for (var i = 0; i < source.length; i++) {
      final sx = source[i].x - srcMean.x;
      final sy = source[i].y - srcMean.y;
      final dx = destination[i].x - dstMean.x;
      final dy = destination[i].y - dstMean.y;
      numeratorA += sx * dx + sy * dy;
      numeratorB += sx * dy - sy * dx;
      denominator += sx * sx + sy * sy;
    }
    if (denominator == 0) return null;

    final a = numeratorA / denominator;
    final b = numeratorB / denominator;
    final tx = dstMean.x - a * srcMean.x + b * srcMean.y;
    final ty = dstMean.y - b * srcMean.x - a * srcMean.y;
    final determinant = a * a + b * b;
    if (determinant == 0) return null;

    return _SimilarityTransform(a: a, b: b, tx: tx, ty: ty);
  }

  Point<double> _meanPoint(List<Point<double>> points) {
    var x = 0.0;
    var y = 0.0;
    for (final point in points) {
      x += point.x;
      y += point.y;
    }
    return Point(x / points.length, y / points.length);
  }

  img.Image _warpSimilarity(
    img.Image source,
    int width,
    int height,
    _SimilarityTransform transform,
  ) {
    final output = img.Image(width: width, height: height);
    final determinant = transform.a * transform.a + transform.b * transform.b;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final dx = x - transform.tx;
        final dy = y - transform.ty;
        final srcX = (transform.a * dx + transform.b * dy) / determinant;
        final srcY = (-transform.b * dx + transform.a * dy) / determinant;
        output.setPixel(x, y, _sampleBilinear(source, srcX, srcY));
      }
    }
    return output;
  }

  img.Color _sampleBilinear(img.Image source, double x, double y) {
    if (x < 0 || y < 0 || x >= source.width - 1 || y >= source.height - 1) {
      return img.ColorRgb8(0, 0, 0);
    }

    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final wx = x - x0;
    final wy = y - y0;

    final p00 = source.getPixel(x0, y0);
    final p10 = source.getPixel(x1, y0);
    final p01 = source.getPixel(x0, y1);
    final p11 = source.getPixel(x1, y1);

    int channel(num c00, num c10, num c01, num c11) {
      final top = c00 * (1 - wx) + c10 * wx;
      final bottom = c01 * (1 - wx) + c11 * wx;
      return (top * (1 - wy) + bottom * wy).round().clamp(0, 255);
    }

    return img.ColorRgb8(
      channel(p00.r, p10.r, p01.r, p11.r),
      channel(p00.g, p10.g, p01.g, p11.g),
      channel(p00.b, p10.b, p01.b, p11.b),
    );
  }

  FaceEmbeddingLayout _layoutFromShape(List<int> shape) {
    if (shape.length == 4 && shape[1] == 3) return FaceEmbeddingLayout.nchw;
    return FaceEmbeddingLayout.nhwc;
  }

  int _modelWidth(FaceEmbeddingLayout layout) {
    if (_inputShape.length != 4) return inputSize;
    return layout == FaceEmbeddingLayout.nchw ? _inputShape[3] : _inputShape[2];
  }

  int _modelHeight(FaceEmbeddingLayout layout) {
    if (_inputShape.length != 4) return inputSize;
    return layout == FaceEmbeddingLayout.nchw ? _inputShape[2] : _inputShape[1];
  }

  List<List<List<List<double>>>> _toNhwc(
    img.Image image,
    int width,
    int height,
  ) {
    return [
      List.generate(height, (y) {
        return List.generate(
          width,
          (x) => _pixelChannels(image.getPixel(x, y)),
        );
      }),
    ];
  }

  List<List<List<List<double>>>> _toNchw(
    img.Image image,
    int width,
    int height,
  ) {
    return [
      List.generate(3, (channel) {
        return List.generate(height, (y) {
          return List.generate(width, (x) {
            return _pixelChannels(image.getPixel(x, y))[channel];
          });
        });
      }),
    ];
  }

  List<double> _pixelChannels(img.Pixel pixel) {
    final r = _normalize(pixel.r.toDouble());
    final g = _normalize(pixel.g.toDouble());
    final b = _normalize(pixel.b.toDouble());

    return switch (channelOrder) {
      FaceEmbeddingChannelOrder.rgb => [r, g, b],
      FaceEmbeddingChannelOrder.bgr => [b, g, r],
    };
  }

  double _normalize(double value) {
    return switch (normalization) {
      FaceEmbeddingNormalization.minusOneToOne => (value - 127.5) / 128.0,
      FaceEmbeddingNormalization.zeroToOne => value / 255.0,
      FaceEmbeddingNormalization.zeroTo255 => value,
    };
  }

  List<double> _flatten(Object value) {
    final result = <double>[];
    void walk(Object node) {
      if (node is List) {
        for (final item in node) {
          walk(item as Object);
        }
      } else if (node is num) {
        result.add(node.toDouble());
      }
    }

    walk(value);
    return result;
  }

  List<double> _l2Normalize(List<double> vector) {
    final norm = sqrt(vector.fold<double>(0, (sum, x) => sum + x * x));
    if (norm == 0) return vector;
    return vector.map((x) => x / norm).toList(growable: false);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

class _SimilarityTransform {
  const _SimilarityTransform({
    required this.a,
    required this.b,
    required this.tx,
    required this.ty,
  });

  final double a;
  final double b;
  final double tx;
  final double ty;
}

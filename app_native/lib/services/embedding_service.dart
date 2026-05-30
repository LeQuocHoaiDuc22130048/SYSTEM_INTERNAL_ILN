import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
    return 'Chưa có model nhận diện khuôn mặt. Đặt arcface.tflite vào '
        '$primaryPath hoặc $fallbackPath rồi rebuild app.';
  }
}

class EmbeddingService {
  EmbeddingService({
    this.modelName = 'arcface',
    this.modelAssetPath = 'assets/models/arcface.tflite',
    this.fallbackModelAssetPath = 'assets/model/arcface.tflite',
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
    await init();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('TFLite interpreter is not initialized.');
    }

    final input = _preprocess(frame, face.boundingBox);
    final outputLength = _outputShape.fold<int>(1, (a, b) => a * b);
    final output = List<double>.filled(outputLength, 0).reshape(_outputShape);

    interpreter.run(input, output);
    return _l2Normalize(_flatten(output));
  }

  Object _preprocess(img.Image frame, Rect bounds) {
    final layout = _layoutFromShape(_inputShape);
    final width = _modelWidth(layout);
    final height = _modelHeight(layout);
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

    return switch (layout) {
      FaceEmbeddingLayout.nhwc => _toNhwc(resized, width, height),
      FaceEmbeddingLayout.nchw => _toNchw(resized, width, height),
    };
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

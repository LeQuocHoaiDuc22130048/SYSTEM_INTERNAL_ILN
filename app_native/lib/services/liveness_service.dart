import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'embedding_service.dart';

class MissingLivenessModelException implements Exception {
  const MissingLivenessModelException(this.primaryPath, this.fallbackPath);

  final String primaryPath;
  final String fallbackPath;

  @override
  String toString() {
    return 'Chua co model MiniFASNet. Dat minifasnet.tflite vao '
        '$primaryPath hoac $fallbackPath roi rebuild app.';
  }
}

class LivenessContractException implements Exception {
  const LivenessContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LivenessResult {
  const LivenessResult({
    required this.isLive,
    required this.score,
    required this.threshold,
    required this.rawScores,
  });

  final bool isLive;
  final double score;
  final double threshold;
  final List<double> rawScores;
}

class LivenessService {
  LivenessService({
    this.modelAssetPath = 'assets/models/minifasnet.tflite',
    this.fallbackModelAssetPath = 'assets/model/minifasnet.tflite',
    this.contractAssetPath = 'assets/models/minifasnet_contract.json',
    this.fallbackContractAssetPath = 'assets/model/minifasnet_contract.json',
    this.threshold = 0.80,
    this.realClassIndex = 1,
    this.normalization = FaceEmbeddingNormalization.zeroTo255,
    this.channelOrder = FaceEmbeddingChannelOrder.bgr,
  });

  final String modelAssetPath;
  final String fallbackModelAssetPath;
  final String contractAssetPath;
  final String fallbackContractAssetPath;
  final double threshold;
  final int realClassIndex;
  final FaceEmbeddingNormalization normalization;
  final FaceEmbeddingChannelOrder channelOrder;

  Interpreter? _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;
  late int _contractRealClassIndex;
  late double _contractThreshold;
  bool _missingModel = false;

  bool get isAvailable => _interpreter != null;
  bool get isMissingModel => _missingModel;

  Future<void> init({bool allowMissing = false}) async {
    if (_interpreter != null) return;
    if (_missingModel) {
      if (!allowMissing) {
        throw MissingLivenessModelException(
          modelAssetPath,
          fallbackModelAssetPath,
        );
      }
      return;
    }
    final options = InterpreterOptions()..threads = 2;
    try {
      _interpreter = await _loadInterpreter(options);
      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;
      final contract = await _loadAndValidateContract();
      _contractRealClassIndex = contract.realClassIndex;
      _contractThreshold = contract.threshold;
    } on MissingLivenessModelException {
      _missingModel = true;
      if (!allowMissing) rethrow;
    }
  }

  Future<_LivenessContract> _loadAndValidateContract() async {
    final contract = await _loadContractJson();
    final outputLength = _outputShape.fold<int>(1, (a, b) => a * b);
    final contractOutputLength = (contract['outputLength'] as num?)?.toInt();
    final contractRealClassIndex =
        (contract['realClassIndex'] as num?)?.toInt() ?? realClassIndex;
    final contractThreshold =
        (contract['threshold'] as num?)?.toDouble() ?? threshold;
    final classOrder = contract['classOrder'];

    if (outputLength <= 0) {
      throw const LivenessContractException(
        'MiniFASNet output tensor is empty.',
      );
    }
    if (contractOutputLength != null && contractOutputLength != outputLength) {
      throw LivenessContractException(
        'MiniFASNet contract outputLength=$contractOutputLength '
        'khong khop model outputLength=$outputLength.',
      );
    }
    if (contractRealClassIndex < 0 || contractRealClassIndex >= outputLength) {
      throw LivenessContractException(
        'MiniFASNet realClassIndex=$contractRealClassIndex nam ngoai '
        'outputLength=$outputLength.',
      );
    }
    if (classOrder is List && classOrder.length == outputLength) {
      final label = classOrder[contractRealClassIndex].toString().toLowerCase();
      if (label != 'real' && label != 'live') {
        throw LivenessContractException(
          'MiniFASNet contract bi dao lop: classOrder[$contractRealClassIndex]=$label, '
          'khong phai real/live.',
        );
      }
    }
    return _LivenessContract(
      realClassIndex: contractRealClassIndex,
      threshold: contractThreshold.clamp(0.01, 0.99),
    );
  }

  Future<Map<String, dynamic>> _loadContractJson() async {
    try {
      return jsonDecode(await rootBundle.loadString(contractAssetPath))
          as Map<String, dynamic>;
    } on FlutterError {
      try {
        return jsonDecode(
              await rootBundle.loadString(fallbackContractAssetPath),
            )
            as Map<String, dynamic>;
      } on FlutterError {
        throw LivenessContractException(
          'Thieu MiniFASNet contract. Dat minifasnet_contract.json vao '
          '$contractAssetPath hoac $fallbackContractAssetPath.',
        );
      }
    }
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
        throw MissingLivenessModelException(
          modelAssetPath,
          fallbackModelAssetPath,
        );
      }
    }
  }

  Future<LivenessResult> verify(img.Image alignedFace) async {
    return _verifyImage(alignedFace);
  }

  Future<LivenessResult> verifyFaceCrop({
    required img.Image frame,
    required Rect boundingBox,
  }) async {
    return _verifyImage(_cropForLiveness(frame, boundingBox));
  }

  Future<LivenessResult> _verifyImage(img.Image face) async {
    await init();
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Liveness interpreter is not initialized.');
    }

    final input = _preprocess(face);
    final outputLength = _outputShape.fold<int>(1, (a, b) => a * b);
    final output = List<double>.filled(outputLength, 0).reshape(_outputShape);
    interpreter.run(input, output);

    final values = _flatten(output);
    final score = _realScore(values);
    return LivenessResult(
      isLive: score >= _contractThreshold,
      score: score,
      threshold: _contractThreshold,
      rawScores: values,
    );
  }

  img.Image _cropForLiveness(img.Image frame, Rect bounds) {
    const paddingRatio = 0.35;
    final padX = bounds.width * paddingRatio;
    final padY = bounds.height * paddingRatio;

    final left = (bounds.left - padX).floor().clamp(0, frame.width - 1);
    final top = (bounds.top - padY).floor().clamp(0, frame.height - 1);
    final right = (bounds.right + padX).ceil().clamp(left + 1, frame.width);
    final bottom = (bounds.bottom + padY).ceil().clamp(top + 1, frame.height);

    return img.copyCrop(
      frame,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  Object _preprocess(img.Image face) {
    final layout = _layoutFromShape(_inputShape);
    final width = _modelWidth(layout);
    final height = _modelHeight(layout);
    final resized = img.copyResize(
      face,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    return switch (layout) {
      FaceEmbeddingLayout.nhwc => [
        List.generate(height, (y) {
          return List.generate(
            width,
            (x) => _pixelChannels(resized.getPixel(x, y)),
          );
        }),
      ],
      FaceEmbeddingLayout.nchw => [
        List.generate(3, (channel) {
          return List.generate(height, (y) {
            return List.generate(width, (x) {
              return _pixelChannels(resized.getPixel(x, y))[channel];
            });
          });
        }),
      ],
    };
  }

  FaceEmbeddingLayout _layoutFromShape(List<int> shape) {
    if (shape.length == 4 && shape[1] == 3) return FaceEmbeddingLayout.nchw;
    return FaceEmbeddingLayout.nhwc;
  }

  int _modelWidth(FaceEmbeddingLayout layout) {
    if (_inputShape.length != 4) return 80;
    return layout == FaceEmbeddingLayout.nchw ? _inputShape[3] : _inputShape[2];
  }

  int _modelHeight(FaceEmbeddingLayout layout) {
    if (_inputShape.length != 4) return 80;
    return layout == FaceEmbeddingLayout.nchw ? _inputShape[2] : _inputShape[1];
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

  double _realScore(List<double> values) {
    if (values.isEmpty) return 0;
    if (values.length == 1) return 1 / (1 + exp(-values.single));
    if (_looksLikeProbabilities(values)) {
      final index = _contractRealClassIndex.clamp(0, values.length - 1);
      return values[index].clamp(0, 1);
    }

    final maxValue = values.reduce(max);
    final expValues = values.map((x) => exp(x - maxValue)).toList();
    final sumExp = expValues.fold<double>(0, (sum, x) => sum + x);
    final index = _contractRealClassIndex.clamp(0, values.length - 1);
    return expValues[index] / sumExp;
  }

  bool _looksLikeProbabilities(List<double> values) {
    final allInRange = values.every((x) => x >= 0 && x <= 1);
    if (!allInRange) return false;
    final sum = values.fold<double>(0, (total, x) => total + x);
    return (sum - 1).abs() <= 0.05;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

class _LivenessContract {
  const _LivenessContract({
    required this.realClassIndex,
    required this.threshold,
  });

  final int realClassIndex;
  final double threshold;
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/embedding_service.dart';
import '../services/face_detector_service.dart';
import '../services/liveness_service.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/network_provider.dart';

enum AttendanceMode { enrollment, verification }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    this.initialMode = AttendanceMode.verification,
    this.initialEmployeeId,
    this.initialEmployeeName,
    this.initialBackendEmployeeId,
    this.popOnEnrollmentSuccess = false,
    this.popOnVerificationSuccess = false,
  });

  final AttendanceMode initialMode;
  final String? initialEmployeeId;
  final String? initialEmployeeName;
  final String? initialBackendEmployeeId;
  final bool popOnEnrollmentSuccess;
  final bool popOnVerificationSuccess;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

enum EnrollmentVariationSlot {
  straight,
  slightLeft,
  slightRight,
  baselineLight,
  alternateLight,
}

class EnrollmentSample {
  const EnrollmentSample({
    required this.embedding,
    required this.metrics,
    required this.slot,
  });

  final List<double> embedding;
  final FaceQualityMetrics metrics;
  final EnrollmentVariationSlot slot;
}

class EnrollmentImageSample {
  const EnrollmentImageSample({
    required this.faceImageBase64,
    required this.metrics,
    required this.slot,
  });

  final String faceImageBase64;
  final FaceQualityMetrics metrics;
  final EnrollmentVariationSlot slot;
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _faceDetector = FaceDetectorService();
  final _embeddingService = EmbeddingService();
  final _livenessService = LivenessService();
  final _databaseService = DatabaseService();
  final _employeeIdController = TextEditingController();
  final _employeeNameController = TextEditingController();

  CameraController? _cameraController;
  AttendanceMode _mode = AttendanceMode.verification;
  String _status = 'Đưa khuôn mặt vào giữa khung hình';
  bool _isProcessingFrame = false;
  bool _isSaving = false;
  bool _isCameraReady = false;
  bool _isDisposed = false;
  bool _isSyncing = false;
  bool _isVerifyingFace = false;
  bool _isPendingServerConfirmation = false;
  bool _showEnrollmentSampleSuccess = false;
  bool _isEnrollmentCompleted = false;
  bool _offlineBlinkClosedSeen = false;
  bool _offlineBlinkConfirmed = false;
  String? _resolvedEnrollmentBackendEmployeeId;
  NetworkProvider? _network;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<EnrollmentSample> _enrollmentSamples = [];
  final List<EnrollmentImageSample> _serverEnrollmentSamples = [];

  static const _frameInterval = Duration(milliseconds: 750);
  static const _enrollmentSamplePause = Duration(milliseconds: 1800);
  static const _duplicateThreshold = 0.78;
  static const _requiredEnrollmentSamples = 5;
  static const _maxEnrollmentSampleCosine = 0.997;
  static const _straightYawMax = 4.0;
  static const _sideYawMin = 5.0;
  static const _sideYawMax = 24.0;
  static const _enrollmentMaxYawDegrees = 28.0;
  static const _enrollmentMaxRollDegrees = 14.0;
  static const _blinkClosedThreshold = 0.25;
  static const _blinkOpenThreshold = 0.65;
  static const _maxAttemptsPerMinute = 5;
  static const _maxConsecutiveLivenessFailures = 3;
  static const _serverFaceDeviceId = 'flutter-tablet-face';

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _employeeIdController.text = widget.initialEmployeeId ?? '';
    _employeeNameController.text = widget.initialEmployeeName ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _network = context.read<NetworkProvider>()
        ..addListener(_handleNetworkChanged);
    });
    unawaited(_initialize());
  }

  void _handleNetworkChanged() {
    final network = _network;
    if (network != null && network.isOnline && !_isSyncing) {
      unawaited(_syncPendingIfOnline(showStatus: true));
    }
  }

  Future<void> _initialize() async {
    try {
      _setInitialStatus('Đang mở camera...');
      await _openCamera();
      unawaited(_scanPreviewFrames());
      unawaited(_prepareAttendanceServices());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyInitializationError(error);
      });
    }
  }

  Future<void> _openCamera() async {
    final cameras = await availableCameras().timeout(
      const Duration(seconds: 8),
    );
    if (cameras.isEmpty) {
      throw StateError('Không tìm thấy camera trên thiết bị.');
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
    await controller.initialize().timeout(const Duration(seconds: 12));

    if (!mounted || _isDisposed) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _isCameraReady = true;
      _status = 'Camera sẵn sàng. Đưa khuôn mặt vào giữa khung hình';
    });
  }

  Future<void> _prepareAttendanceServices() async {
    try {
      await Future.wait([
        _livenessService.init(allowMissing: true),
        _databaseService.database,
      ]).timeout(const Duration(seconds: 20));
    } catch (error) {
      if (mounted) {
        _setStatus(_friendlyInitializationError(error));
      }
      return;
    }

    unawaited(_syncReferenceDataIfOnline());
    unawaited(_syncPendingIfOnline(showStatus: false));
  }

  void _setInitialStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  String _friendlyInitializationError(Object error) {
    if (error is TimeoutException) {
      return 'Camera hoặc dữ liệu chấm công phản hồi quá lâu. Đóng màn hình rồi mở lại, hoặc kiểm tra quyền camera.';
    }
    if (error is CameraException) {
      if (error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted') {
        return 'Ứng dụng chưa có quyền camera. Vào Cài đặt ứng dụng và bật quyền Camera.';
      }
      return 'Không thể mở camera (${error.code}). Đóng ứng dụng rồi mở lại hoặc kiểm tra quyền camera.';
    }
    if (error is MissingFaceModelException) {
      return 'Chưa có model AI offline. Thêm face_embedding.tflite vào assets/models rồi rebuild app.';
    }
    if (error is MissingLivenessModelException) {
      return 'Chưa có model chống giả mạo offline. Thêm minifasnet.tflite vào assets/models rồi rebuild app.';
    }
    if (error is LivenessContractException) {
      return 'Contract MiniFASNet không hợp lệ. Kiểm tra realClassIndex/classOrder trước khi chấm công.';
    }
    return 'Không thể khởi tạo chấm công khuôn mặt. Kiểm tra quyền camera và kết nối backend.';
  }

  Future<void> _scanPreviewFrames() async {
    while (mounted && !_isDisposed) {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return;

      final now = DateTime.now();
      if (!_isProcessingFrame &&
          !_isSaving &&
          now.difference(_lastProcessedAt) >= _frameInterval) {
        _lastProcessedAt = now;
        _isProcessingFrame = true;
        try {
          final offline = _network?.isOffline ?? false;
          if (_mode == AttendanceMode.verification &&
              offline &&
              await _databaseService.isEmbeddingSyncExpired()) {
            _setStatus(
              'Dữ liệu khuôn mặt offline đã quá 7 ngày. Vui lòng kết nối mạng để đồng bộ trước khi chấm công.',
            );
            continue;
          }
          final file = await controller.takePicture();
          final isEnrollment = _mode == AttendanceMode.enrollment;
          if (!isEnrollment) {
            _logFaceAuth('frame_captured', {
              'online': !offline,
              'blink_confirmed': _offlineBlinkConfirmed,
            });
          }
          final faceResult = await _faceDetector
              .detectPrimaryFaceFromFileWithQuality(
                file.path,
                requireOpenEyes:
                    !isEnrollment &&
                    !(offline &&
                        _mode == AttendanceMode.verification &&
                        !_offlineBlinkConfirmed),
                requireBothEyesLandmarks: !isEnrollment,
                maxYawDegrees: isEnrollment ? _enrollmentMaxYawDegrees : 12.0,
                maxRollDegrees: isEnrollment ? _enrollmentMaxRollDegrees : 12.0,
              );
          final detected = faceResult.detectedFace;
          if (detected == null) {
            final enrollmentMessage =
                isEnrollment && _isWaitingForSideEnrollmentSample()
                ? 'Quay nhẹ mặt 10-20 độ, vẫn nhìn thấy rõ khuôn mặt trong khung hình.'
                : null;
            if (enrollmentMessage != null) {
              _setStatus(enrollmentMessage);
            } else {
              _setStatus(
                faceResult.message ?? 'Cần 1 khuôn mặt chính diện, mắt mở',
              );
            }
            if (_mode == AttendanceMode.verification) {
              _logFaceAuth('quality_rejected', {
                'reason': faceResult.message,
                'online': !offline,
              });
              await _databaseService.recordAttendanceSecurityEvent(
                reason: 'QUALITY_REJECTED',
                detail: faceResult.message,
              );
            }
          } else {
            if (offline &&
                _mode == AttendanceMode.verification &&
                !_offlineBlinkConfirmed) {
              _trackOfflineBlink(detected.face);
              _logFaceAuth('offline_blink_required', {
                'closed_seen': _offlineBlinkClosedSeen,
              });
              _setStatus(
                _offlineBlinkClosedSeen
                    ? 'Mở mắt để hoàn tất kiểm tra chống giả mạo'
                    : 'Đang offline. Vui lòng nhấp mắt để xác minh',
              );
              continue;
            }
            if (_mode == AttendanceMode.verification &&
                !await _allowAttendanceAttempt()) {
              continue;
            }
            if (!_isVerifyingFace) {
              _isVerifyingFace = true;
              _setStatus('Đang xác minh khuôn mặt...');
              await Future<void>.delayed(const Duration(milliseconds: 1400));
              _isVerifyingFace = false;
            }
            final livenessPassed = await _verifyLiveness(detected);
            if (!livenessPassed) {
              _resetOfflineBlink();
              continue;
            }
            final alignedFaceImageBase64 = _encodeAlignedFace(detected);
            final serverFaceImageBase64 = _encodeServerFaceImage(file.path);
            final useServerInference = !offline;
            if (_mode == AttendanceMode.enrollment) {
              if (useServerInference) {
                await _handleServerEnrollment(
                  faceImageBase64: serverFaceImageBase64,
                  metrics: faceResult.metrics,
                );
              } else {
                final alignedFace = _embeddingService.alignFace(
                  frame: detected.frame,
                  face: detected.face,
                );
                final embedding = await _embeddingService
                    .extractEmbeddingFromAligned(alignedFace);
                await _handleEnrollmentEmbedding(
                  embedding,
                  metrics: faceResult.metrics,
                );
              }
            } else {
              if (useServerInference) {
                await _handleServerVerification(
                  faceImageBase64: serverFaceImageBase64,
                );
              } else {
                final alignedFace = _embeddingService.alignFace(
                  frame: detected.frame,
                  face: detected.face,
                );
                final embedding = await _embeddingService
                    .extractEmbeddingFromAligned(alignedFace);
                await _handleVerificationEmbedding(
                  embedding,
                  faceImageBase64: alignedFaceImageBase64,
                );
              }
              _resetOfflineBlink();
            }
          }
        } catch (error, stackTrace) {
          _isVerifyingFace = false;
          _handleFrameProcessingError(error, stackTrace);
        } finally {
          _isProcessingFrame = false;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  void _handleFrameProcessingError(Object error, StackTrace stackTrace) {
    _logFaceAuth('frame_processing_error', {
      'error': error.toString(),
      'stack': stackTrace.toString().split('\n').take(3).join(' | '),
    });
    final message = error.toString();
    if (message.contains('attendance_logs') ||
        message.contains('attendance_security_events') ||
        message.contains('no such table')) {
      _setStatus('Đang chuẩn bị dữ liệu chấm công trên thiết bị...');
      unawaited(_databaseService.database);
      return;
    }
    _setStatus('Đang thử lại khung hình camera...');
  }

  Future<bool> _verifyLiveness(DetectedFace detected) async {
    if (!_livenessService.isAvailable) {
      _logFaceAuth('liveness_skipped', {'reason': 'model_unavailable'});
      await _databaseService.recordAttendanceSecurityEvent(
        reason: 'LIVENESS_SKIPPED',
        detail: 'MiniFASNet model unavailable on tablet',
      );
      return true;
    }

    final liveness = await _livenessService.verifyFaceCrop(
      frame: detected.frame,
      boundingBox: detected.face.boundingBox,
    );
    if (!liveness.isLive) {
      _logFaceAuth('liveness_failed', {
        'score': _roundScore(liveness.score),
        'threshold': _roundScore(liveness.threshold),
        'raw_scores': liveness.rawScores.map(_roundScore).toList(),
      });
      final locked = await _handleLivenessFailure(liveness);
      if (!locked) {
        _setStatus('Phát hiện dấu hiệu giả mạo khuôn mặt');
      }
      return false;
    }

    if (_mode == AttendanceMode.verification) {
      _logFaceAuth('liveness_passed', {
        'score': _roundScore(liveness.score),
        'threshold': _roundScore(liveness.threshold),
        'raw_scores': liveness.rawScores.map(_roundScore).toList(),
      });
      await _databaseService.recordAttendanceSecurityEvent(
        reason: 'LIVENESS_PASSED',
        detail:
            'score=${liveness.score.toStringAsFixed(4)}, threshold=${liveness.threshold.toStringAsFixed(4)}',
      );
    }
    return true;
  }

  String _encodeAlignedFace(DetectedFace detected) {
    final alignedFace = _embeddingService.alignFace(
      frame: detected.frame,
      face: detected.face,
    );
    return base64Encode(img.encodeJpg(alignedFace, quality: 88));
  }

  String _encodeServerFaceImage(String imagePath) {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return base64Encode(bytes);
    }

    var image = img.bakeOrientation(decoded);
    const maxSide = 960;
    final largestSide = math.max(image.width, image.height);
    if (largestSide > maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxSide : null,
        height: image.height > image.width ? maxSide : null,
      );
    }
    return base64Encode(img.encodeJpg(image, quality: 86));
  }

  void _trackOfflineBlink(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if (leftEye == null || rightEye == null) return;

    final bothClosed =
        leftEye <= _blinkClosedThreshold && rightEye <= _blinkClosedThreshold;
    final bothOpen =
        leftEye >= _blinkOpenThreshold && rightEye >= _blinkOpenThreshold;

    if (bothClosed) {
      _offlineBlinkClosedSeen = true;
      return;
    }
    if (_offlineBlinkClosedSeen && bothOpen) {
      _offlineBlinkConfirmed = true;
    }
  }

  void _resetOfflineBlink() {
    _offlineBlinkClosedSeen = false;
    _offlineBlinkConfirmed = false;
  }

  Future<bool> _allowAttendanceAttempt() async {
    final lockedUntil = await _databaseService.getLivenessLockedUntil();
    if (lockedUntil != null) {
      _setStatus(
        'Thiết bị đang tạm khóa chống giả mạo. Thử lại sau ${_remainingLockText(lockedUntil)}.',
      );
      await _databaseService.recordAttendanceSecurityEvent(
        reason: 'RATE_LIMITED',
        detail: 'Liveness lock active until ${lockedUntil.toIso8601String()}',
      );
      return false;
    }

    final attempts = await _databaseService.countRecentAttendanceAttempts();
    if (attempts >= _maxAttemptsPerMinute) {
      _setStatus('Thử quá nhiều lần. Vui lòng chờ 1 phút rồi thử lại.');
      await _databaseService.recordAttendanceSecurityEvent(
        reason: 'RATE_LIMITED',
        detail: 'attempts_per_minute=$attempts',
      );
      return false;
    }

    await _databaseService.recordAttendanceSecurityEvent(
      reason: 'ATTENDANCE_ATTEMPT',
      detail: 'mode=${_mode.name}',
    );
    return true;
  }

  Future<bool> _handleLivenessFailure(LivenessResult liveness) async {
    await _databaseService.recordAttendanceSecurityEvent(
      reason: 'LIVENESS_FAILED',
      detail:
          'score=${liveness.score.toStringAsFixed(4)}, threshold=${liveness.threshold.toStringAsFixed(4)}',
    );
    final failures = await _databaseService.countConsecutiveLivenessFailures();
    if (failures >= _maxConsecutiveLivenessFailures) {
      final lockedUntil = await _databaseService.lockLiveness();
      _setStatus(
        'Liveness thất bại liên tục. Thiết bị bị khóa 5 phút, thử lại sau ${_remainingLockText(lockedUntil)}.',
      );
      return true;
    }
    return false;
  }

  String _remainingLockText(DateTime lockedUntil) {
    final remaining = lockedUntil.toUtc().difference(DateTime.now().toUtc());
    if (remaining.isNegative) return 'ít phút';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes <= 0) return '$seconds giây';
    return '$minutes phút ${seconds.toString().padLeft(2, '0')} giây';
  }

  EnrollmentVariationSlot? _nextEnrollmentSlot(FaceQualityMetrics metrics) {
    final collectedSlots = _collectedEnrollmentSlots();
    final yaw = metrics.yaw;

    if (!collectedSlots.contains(EnrollmentVariationSlot.straight) &&
        yaw.abs() <= _straightYawMax) {
      return EnrollmentVariationSlot.straight;
    }

    final isSideYaw = yaw.abs() >= _sideYawMin && yaw.abs() <= _sideYawMax;
    if (isSideYaw) {
      final sideSlot = yaw < 0
          ? EnrollmentVariationSlot.slightRight
          : EnrollmentVariationSlot.slightLeft;

      if (!collectedSlots.contains(sideSlot)) {
        return sideSlot;
      }
      return null;
    }

    final hasLeft = collectedSlots.contains(EnrollmentVariationSlot.slightLeft);
    final hasRight = collectedSlots.contains(
      EnrollmentVariationSlot.slightRight,
    );
    if (!hasLeft || !hasRight) {
      return null;
    }

    if (!collectedSlots.contains(EnrollmentVariationSlot.baselineLight) &&
        yaw.abs() <= _straightYawMax) {
      return EnrollmentVariationSlot.baselineLight;
    }
    if (!collectedSlots.contains(EnrollmentVariationSlot.alternateLight) &&
        yaw.abs() <= _straightYawMax) {
      return EnrollmentVariationSlot.alternateLight;
    }
    return null;
  }

  bool _isWaitingForSideEnrollmentSample() {
    final collectedSlots = _collectedEnrollmentSlots();
    return collectedSlots.contains(EnrollmentVariationSlot.straight) &&
        (!collectedSlots.contains(EnrollmentVariationSlot.slightLeft) ||
            !collectedSlots.contains(EnrollmentVariationSlot.slightRight));
  }

  String _nextEnrollmentInstruction() {
    final collectedSlots = _collectedEnrollmentSlots();
    if (!collectedSlots.contains(EnrollmentVariationSlot.straight)) {
      return 'Nhìn thẳng vào camera.';
    }
    final hasLeft = collectedSlots.contains(EnrollmentVariationSlot.slightLeft);
    final hasRight = collectedSlots.contains(
      EnrollmentVariationSlot.slightRight,
    );
    if (!hasLeft && !hasRight) {
      return 'Quay nhẹ mặt sang một bên 10-20 độ, vẫn giữ mặt trong khung.';
    }
    if (!hasLeft || !hasRight) {
      return 'Quay nhẹ mặt sang bên còn lại 10-20 độ, vẫn giữ mặt trong khung.';
    }
    if (!collectedSlots.contains(EnrollmentVariationSlot.baselineLight)) {
      return 'Nhìn thẳng lại và giữ mặt ổn định để lấy mẫu bổ sung.';
    }
    if (!collectedSlots.contains(EnrollmentVariationSlot.alternateLight)) {
      return 'Giữ mặt ổn định trong cùng ánh sáng để lấy mẫu cuối.';
    }
    return 'Giữ khuôn mặt trong khung hình.';
  }

  String _enrollmentGuidanceForMetrics(FaceQualityMetrics metrics) {
    final collectedSlots = _collectedEnrollmentSlots();
    if (metrics.yaw.abs() > _sideYawMax) {
      return 'Quay nhẹ hơn, khoảng 10-20 độ và vẫn giữ mặt trong khung hình.';
    }
    if (metrics.roll.abs() > _enrollmentMaxRollDegrees) {
      return 'Giữ điện thoại và đầu thẳng hơn, không nghiêng mặt.';
    }
    if (!collectedSlots.contains(EnrollmentVariationSlot.straight)) {
      return 'Mẫu này chưa đủ thẳng. Nhìn thẳng vào camera để lấy mẫu đầu tiên.';
    }
    final isSideYaw =
        metrics.yaw.abs() >= _sideYawMin && metrics.yaw.abs() <= _sideYawMax;
    if (isSideYaw) {
      final sideSlot = metrics.yaw < 0
          ? EnrollmentVariationSlot.slightRight
          : EnrollmentVariationSlot.slightLeft;
      if (collectedSlots.contains(sideSlot)) {
        return 'Mẫu góc này đã có. Quay nhẹ sang bên còn lại để lấy mẫu khác.';
      }
    }
    final hasLeft = collectedSlots.contains(EnrollmentVariationSlot.slightLeft);
    final hasRight = collectedSlots.contains(
      EnrollmentVariationSlot.slightRight,
    );
    if (!hasLeft || !hasRight) {
      return 'Cần mẫu góc nghiêng còn lại. Quay nhẹ sang bên khác 10-20 độ.';
    }
    if (metrics.yaw.abs() > _straightYawMax) {
      return 'Hai mẫu góc nghiêng đã có. Nhìn thẳng lại để lấy mẫu bổ sung.';
    }
    return _nextEnrollmentInstruction();
  }

  Set<EnrollmentVariationSlot> _collectedEnrollmentSlots() {
    return {
      ..._enrollmentSamples.map((sample) => sample.slot),
      ..._serverEnrollmentSamples.map((sample) => sample.slot),
    };
  }

  int get _enrollmentSampleCount =>
      _enrollmentSamples.length + _serverEnrollmentSamples.length;

  List<EnrollmentVariationSlot> get _enrollmentSlotOrder => const [
    EnrollmentVariationSlot.straight,
    EnrollmentVariationSlot.slightLeft,
    EnrollmentVariationSlot.slightRight,
    EnrollmentVariationSlot.baselineLight,
    EnrollmentVariationSlot.alternateLight,
  ];

  String _enrollmentSlotTitle(EnrollmentVariationSlot slot) {
    return switch (slot) {
      EnrollmentVariationSlot.straight => 'Nhìn thẳng',
      EnrollmentVariationSlot.slightLeft => 'Quay nhẹ sang trái',
      EnrollmentVariationSlot.slightRight => 'Quay nhẹ sang phải',
      EnrollmentVariationSlot.baselineLight => 'Nhìn thẳng, giữ yên',
      EnrollmentVariationSlot.alternateLight => 'Mẫu bổ sung ánh sáng',
    };
  }

  String _enrollmentSlotHint(EnrollmentVariationSlot slot) {
    return switch (slot) {
      EnrollmentVariationSlot.straight => 'Mặt ở giữa khung, mở mắt rõ.',
      EnrollmentVariationSlot.slightLeft =>
        'Quay khoảng 10-20 độ, không nghiêng đầu.',
      EnrollmentVariationSlot.slightRight => 'Quay sang bên còn lại 10-20 độ.',
      EnrollmentVariationSlot.baselineLight =>
        'Nhìn thẳng lại, giữ máy ổn định.',
      EnrollmentVariationSlot.alternateLight =>
        'Đổi nhẹ khoảng cách hoặc ánh sáng.',
    };
  }

  Future<void> _handleServerEnrollment({
    required String faceImageBase64,
    required FaceQualityMetrics? metrics,
  }) async {
    final employeeId = _employeeIdController.text.trim();
    final employeeName = _employeeNameController.text.trim();
    if (_isEnrollmentCompleted) {
      _setStatus('Đăng ký đã hoàn tất. Chuyển sang chấm công hoặc quay lại.');
      return;
    }
    if (employeeId.isEmpty || employeeName.isEmpty) {
      _setStatus('Nhập mã và tên nhân viên trước khi đăng ký');
      return;
    }
    final backendEmployeeId = await _resolveEnrollmentBackendEmployeeId(
      employeeCodeOrId: employeeId,
      employeeName: employeeName,
    );
    if (backendEmployeeId == null || backendEmployeeId.isEmpty) {
      _setStatus(
        'Không tìm thấy nhân viên trên server. Vào Quản lý nhân viên, chọn đúng nhân viên rồi đăng ký khuôn mặt.',
        showSnackBar: true,
        snackColor: AppColors.error,
      );
      return;
    }
    if (metrics == null) {
      _setStatus('Chưa đủ thông tin chất lượng ảnh. Vui lòng thử lại.');
      return;
    }
    if (metrics.roll.abs() > _enrollmentMaxRollDegrees) {
      _setStatus('Nhìn thẳng vào camera để lấy mẫu đăng ký chính.');
      return;
    }

    _isSaving = true;
    try {
      final slot = _nextEnrollmentSlot(metrics);
      if (slot == null) {
        _setStatus(_enrollmentGuidanceForMetrics(metrics));
        await Future<void>.delayed(_enrollmentSamplePause);
        return;
      }

      _serverEnrollmentSamples.add(
        EnrollmentImageSample(
          faceImageBase64: faceImageBase64,
          metrics: metrics,
          slot: slot,
        ),
      );

      if (_serverEnrollmentSamples.length < _requiredEnrollmentSamples) {
        await _showEnrollmentSampleAccepted(
          acceptedMessage:
              'Da thu ${_serverEnrollmentSamples.length}/$_requiredEnrollmentSamples mau',
          nextInstruction: _nextEnrollmentInstruction(),
        );
        return;
      }

      final backend = context.read<BackendDataProvider>();
      final auth = context.read<AuthProvider>();
      await _showEnrollmentSampleAccepted(
        acceptedMessage:
            'Da thu $_requiredEnrollmentSamples/$_requiredEnrollmentSamples mau',
        nextInstruction: 'Dang gui mau khuon mat len server...',
      );
      _setStatus('Đang gửi mẫu khuôn mặt lên server...');
      await backend.enrollFace(
        backendEmployeeId,
        faceImageBase64: _serverEnrollmentSamples.first.faceImageBase64,
        imageContentType: 'image/jpeg',
        samples: _serverEnrollmentSamples
            .map(
              (sample) => {
                'faceImageBase64': sample.faceImageBase64,
                'imageContentType': 'image/jpeg',
              },
            )
            .toList(growable: false),
      );
      try {
        await _databaseService.syncEmployeeEmbeddingsFromServer(api: auth.api);
      } catch (_) {
        // Offline reference cache is best-effort; server enrollment already succeeded.
      }
      _isEnrollmentCompleted = true;
      _setStatus(
        'Đăng ký khuôn mặt thành công: $employeeName',
        showSnackBar: true,
        snackColor: AppColors.success,
      );
      if (widget.popOnEnrollmentSuccess && mounted) {
        Navigator.pop(context, true);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    } catch (error) {
      _setStatus(
        'Đăng ký khuôn mặt thất bại: $error',
        showSnackBar: true,
        snackColor: AppColors.error,
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<String?> _resolveEnrollmentBackendEmployeeId({
    required String employeeCodeOrId,
    required String employeeName,
  }) async {
    final initialBackendEmployeeId = widget.initialBackendEmployeeId;
    if (initialBackendEmployeeId != null && initialBackendEmployeeId.isNotEmpty) {
      return initialBackendEmployeeId;
    }
    final cached = _resolvedEnrollmentBackendEmployeeId;
    if (cached != null && cached.isNotEmpty) return cached;

    final backend = context.read<BackendDataProvider>();
    if (backend.employees.isEmpty) {
      try {
        await backend.loadEmployees(notify: false);
      } catch (_) {
        return null;
      }
    }

    final lookupCode = employeeCodeOrId.trim().toLowerCase();
    final lookupName = employeeName.trim().toLowerCase();
    for (final employee in backend.employees) {
      if (employee.id.toLowerCase() == lookupCode ||
          employee.employeeId.toLowerCase() == lookupCode ||
          employee.username.toLowerCase() == lookupCode) {
        _resolvedEnrollmentBackendEmployeeId = employee.id;
        return employee.id;
      }
    }
    for (final employee in backend.employees) {
      if (employee.name.trim().toLowerCase() == lookupName) {
        _resolvedEnrollmentBackendEmployeeId = employee.id;
        return employee.id;
      }
    }
    return null;
  }

  Future<void> _handleEnrollmentEmbedding(
    List<double> embedding, {
    required FaceQualityMetrics? metrics,
  }) async {
    final employeeId = _employeeIdController.text.trim();
    final employeeName = _employeeNameController.text.trim();
    if (_isEnrollmentCompleted) {
      _setStatus('Đăng ký đã hoàn tất. Chuyển sang chấm công hoặc quay lại.');
      return;
    }
    if (employeeId.isEmpty || employeeName.isEmpty) {
      _setStatus('Nhập mã và tên nhân viên trước khi đăng ký');
      return;
    }
    if (metrics == null) {
      _setStatus('Chưa đủ thông tin chất lượng ảnh. Vui lòng thử lại.');
      return;
    }

    _isSaving = true;
    try {
      final duplicate = await _databaseService.findDuplicateEnrollment(
        embedding,
        employeeId: employeeId,
        modelName: _embeddingService.modelName,
        backendEmployeeId: widget.initialBackendEmployeeId,
        threshold: _duplicateThreshold,
      );
      if (duplicate != null) {
        _setStatus(
          'Khuôn mặt này đã được đăng ký cho nhân viên khác. Vui lòng kiểm tra lại.',
        );
        return;
      }

      final slot = _nextEnrollmentSlot(metrics);
      if (slot == null) {
        _setStatus(_enrollmentGuidanceForMetrics(metrics));
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }

      final tooSimilarToExistingSample = _enrollmentSamples.any(
        (sample) =>
            _cosineSimilarity(sample.embedding, embedding) >
            _maxEnrollmentSampleCosine,
      );
      if (tooSimilarToExistingSample) {
        _setStatus(
          'Mẫu này quá giống mẫu đã thu. Giữ đúng hướng dẫn hiện tại và đổi nhẹ góc mặt.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }

      _enrollmentSamples.add(
        EnrollmentSample(embedding: embedding, metrics: metrics, slot: slot),
      );

      if (_enrollmentSamples.length < _requiredEnrollmentSamples) {
        await _showEnrollmentSampleAccepted(
          acceptedMessage:
              'Đã thu ${_enrollmentSamples.length}/$_requiredEnrollmentSamples mẫu',
          nextInstruction: _nextEnrollmentInstruction(),
        );
        return;
      }

      await _showEnrollmentSampleAccepted(
        acceptedMessage:
            'Đã thu $_requiredEnrollmentSamples/$_requiredEnrollmentSamples mẫu',
        nextInstruction: 'Đang lưu dữ liệu đăng ký...',
      );

      await _databaseService.replaceEmployeeFaceSamples(
        employee: EnrolledEmployee(
          id: employeeId,
          name: employeeName,
          backendEmployeeId: widget.initialBackendEmployeeId,
          modelName: _embeddingService.modelName,
        ),
        embeddings: _enrollmentSamples
            .map((sample) => sample.embedding)
            .toList(growable: false),
      );
      _isEnrollmentCompleted = true;
      _setStatus('Đăng ký thành công: $employeeName');
      if (widget.popOnEnrollmentSuccess && mounted) {
        Navigator.pop(context, true);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _showEnrollmentSampleAccepted({
    required String acceptedMessage,
    required String nextInstruction,
  }) async {
    if (!mounted) return;
    setState(() {
      _showEnrollmentSampleSuccess = true;
      _status = acceptedMessage;
    });
    await Future<void>.delayed(_enrollmentSamplePause);
    if (!mounted) return;
    setState(() {
      _showEnrollmentSampleSuccess = false;
      _status = nextInstruction;
    });
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return -1;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denominator = normA == 0 || normB == 0
        ? 0.0
        : math.sqrt(normA) * math.sqrt(normB);
    if (denominator == 0) return -1;
    return dot / denominator;
  }

  double? _roundScore(double? value) {
    if (value == null) return null;
    return double.parse(value.toStringAsFixed(4));
  }

  String _serverFaceFailureMessage(Object error) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
      if (error.statusCode == 0) {
        return 'Không kết nối được server chấm công. Kiểm tra WiFi, IP backend và cổng 8080.';
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Quét khuôn mặt thất bại: khuôn mặt chưa được đăng ký, chưa đủ độ khớp, hoặc tài khoản không có quyền chấm công.';
      }
      if (error.statusCode == 409) {
        return 'Khuôn mặt này đã được đăng ký cho nhân viên khác. Vui lòng kiểm tra lại hồ sơ nhân viên.';
      }
      if (error.statusCode >= 500) {
        return 'Server chấm công đang lỗi. Vui lòng thử lại sau hoặc báo quản lý kiểm tra backend.';
      }
    }
    return 'Quét khuôn mặt thất bại. Vui lòng đưa mặt rõ hơn vào khung hình và thử lại.';
  }

  void _logFaceAuth(String event, Map<String, Object?> fields) {
    if (!kDebugMode) return;
    final payload = <String, Object?>{
      'event': event,
      'mode': _mode.name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
    debugPrint('[FACE_AUTH] ${jsonEncode(payload)}');
  }

  Future<void> _handleServerVerification({
    required String faceImageBase64,
  }) async {
    final stopwatch = Stopwatch()..start();
    _isSaving = true;
    try {
      _setStatus('Đang gửi ảnh lên server để xác minh...');
      final auth = context.read<AuthProvider>();
      final response = await auth.api.post(
        '/api/v1/attendance/face-identify',
        body: {
          'faceImageBase64': faceImageBase64,
          'imageContentType': 'image/jpeg',
          'deviceId': _serverFaceDeviceId,
        },
      );
      _isPendingServerConfirmation = false;
      if (mounted) {
        await context.read<BackendDataProvider>().loadAttendance();
      }

      final data = response is Map<String, dynamic> ? response : null;
      final employeeName = data?['employeeName']?.toString();
      final attendanceType = data?['type']?.toString();
      _logFaceAuth('server_verification_matched', {
        'employee_name': employeeName,
        'attendance_type': attendanceType,
        'latency_ms': stopwatch.elapsedMilliseconds,
      });
      _setStatus(
        employeeName == null || employeeName.isEmpty
            ? 'Chấm công thành công'
            : 'Chấm công thành công: $employeeName',
        showSnackBar: true,
        snackColor: AppColors.success,
      );
      if (widget.popOnVerificationSuccess && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context, true);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    } catch (error) {
      final failureMessage = _serverFaceFailureMessage(error);
      _logFaceAuth('server_verification_rejected', {
        'error': error.toString(),
        'message': failureMessage,
        'latency_ms': stopwatch.elapsedMilliseconds,
      });
      await _databaseService.recordAttendanceSecurityEvent(
        reason: 'SERVER_FACE_REJECTED',
        detail: failureMessage,
        deviceId: _serverFaceDeviceId,
      );
      _setStatus(
        failureMessage,
        showSnackBar: true,
        snackColor: AppColors.error,
      );
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _handleVerificationEmbedding(
    List<double> embedding, {
    required String faceImageBase64,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logFaceAuth('verification_started', {
      'model': _embeddingService.modelName,
      'embedding_dim': embedding.length,
    });
    final localSampleCount = await _databaseService.countFaceSamples(
      modelName: _embeddingService.modelName,
    );
    var thresholdSource = 'server_calibrated';
    var matchThreshold = await _databaseService.getFaceMatchThreshold();
    if (matchThreshold == null) {
      if (localSampleCount > 0) {
        matchThreshold =
            FaceMatchThresholdCalibration.provisionalLocalThreshold;
        thresholdSource = 'local_provisional';
        _logFaceAuth('threshold_fallback_used', {
          'threshold': _roundScore(matchThreshold),
          'sample_count': localSampleCount,
        });
      } else {
        _logFaceAuth('verification_blocked', {
          'reason': 'missing_calibrated_threshold',
          'sample_count': localSampleCount,
          'latency_ms': stopwatch.elapsedMilliseconds,
        });
        _setStatus(
          'Chưa có dữ liệu khuôn mặt hoặc ngưỡng nhận diện. Vui lòng đăng ký lại hoặc đồng bộ dữ liệu.',
        );
        return;
      }
    }
    final candidate = await _databaseService.findBestCandidate(
      embedding,
      modelName: _embeddingService.modelName,
    );
    final match =
        candidate != null && candidate.cosineSimilarity >= matchThreshold
        ? candidate
        : null;
    _logFaceAuth('match_scored', {
      'outcome': match == null ? 'REJECTED' : 'MATCHED',
      'candidate_emp_id': candidate?.employee.id,
      'candidate_backend_emp_id': candidate?.employee.backendEmployeeId,
      'score': _roundScore(candidate?.cosineSimilarity),
      'threshold': _roundScore(matchThreshold),
      'threshold_source': thresholdSource,
      'sample_count': localSampleCount,
      'latency_ms': stopwatch.elapsedMilliseconds,
    });
    await _databaseService.recordFaceRecognitionAttempt(
      modelName: _embeddingService.modelName,
      outcome: match == null ? 'REJECTED' : 'MATCHED',
      similarityScore: candidate?.cosineSimilarity,
      threshold: matchThreshold,
      candidate: candidate,
    );
    if (match == null) {
      _logFaceAuth('verification_rejected', {
        'score': _roundScore(candidate?.cosineSimilarity),
        'threshold': _roundScore(matchThreshold),
        'threshold_source': thresholdSource,
        'sample_count': localSampleCount,
        'latency_ms': stopwatch.elapsedMilliseconds,
      });
      _setStatus('Không tìm thấy nhân viên phù hợp');
      return;
    }

    _isSaving = true;
    try {
      await _databaseService.insertAttendanceLog(
        match,
        faceEmbedding: embedding,
        faceImageBase64: faceImageBase64,
        imageContentType: 'image/jpeg',
      );
      final synced = await _syncPendingIfOnline(showStatus: false);
      final nearbyDuplicate =
          synced == 0 && _databaseService.lastSyncHadNearbyDuplicate;
      final serverRejection = synced == 0
          ? await _databaseService.getLatestPendingServerRejection()
          : null;
      _isPendingServerConfirmation =
          synced == 0 && serverRejection == null && !nearbyDuplicate;
      _logFaceAuth('attendance_log_created', {
        'emp_id': match.employee.id,
        'backend_emp_id': match.employee.backendEmployeeId,
        'score': _roundScore(match.cosineSimilarity),
        'threshold': _roundScore(matchThreshold),
        'threshold_source': thresholdSource,
        'sample_count': localSampleCount,
        'synced_count': synced,
        'nearby_duplicate': nearbyDuplicate,
        'server_rejected': serverRejection != null,
        'pending_server_confirmation': _isPendingServerConfirmation,
        'latency_ms': stopwatch.elapsedMilliseconds,
      });
      final displayStatusText = synced > 0
          ? 'Chấm công thành công: ${match.employee.name}'
          : nearbyDuplicate
          ? 'Đã có bản ghi gần thời điểm này'
          : serverRejection != null
          ? 'Server từ chối chấm công. Vui lòng chấm lại.'
          : 'Chấm công tạm - chờ xác nhận: ${match.employee.name}';
      _setStatus(
        displayStatusText,
        showSnackBar: true,
        snackColor: synced > 0
            ? AppColors.success
            : nearbyDuplicate
            ? AppColors.warning
            : serverRejection != null
            ? AppColors.error
            : AppColors.warning,
      );
      if (widget.popOnVerificationSuccess && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) Navigator.pop(context, true);
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    } finally {
      _isSaving = false;
    }
  }

  Future<int> _syncPendingIfOnline({required bool showStatus}) async {
    if (!mounted || _isSyncing) return 0;
    _isSyncing = true;
    final network = context.read<NetworkProvider>();
    try {
      final online = await network.checkNow();
      if (!mounted || !online) return 0;

      final auth = context.read<AuthProvider>();
      try {
        await _databaseService.syncPendingFaceRecognitionAttempts(
          api: auth.api,
        );
      } catch (_) {
        // Recognition monitoring should not block attendance sync.
      }
      final synced = await _databaseService.syncPendingAttendanceLogs(
        api: auth.api,
      );
      if (synced > 0 && mounted) {
        _isPendingServerConfirmation = false;
        await context.read<BackendDataProvider>().loadAttendance();
        if (showStatus) {
          _setStatus('Dữ liệu chấm công đã được cập nhật');
        }
      } else if (_databaseService.lastSyncHadNearbyDuplicate && mounted) {
        _isPendingServerConfirmation = false;
        if (showStatus) {
          _setStatus(
            'Đã có bản ghi gần thời điểm này',
            showSnackBar: true,
            snackColor: AppColors.warning,
          );
        }
      } else if (showStatus && mounted) {
        final serverRejection = await _databaseService
            .getLatestPendingServerRejection();
        if (serverRejection != null) {
          _isPendingServerConfirmation = false;
          _setStatus(
            'Server từ chối chấm công. Vui lòng chấm lại.',
            showSnackBar: true,
            snackColor: AppColors.error,
          );
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncReferenceDataIfOnline() async {
    if (!mounted) return;
    final network = context.read<NetworkProvider>();
    final online = await network.checkNow();
    if (!mounted || !online) return;

    final auth = context.read<AuthProvider>();
    try {
      await _databaseService.syncEmployeeEmbeddingsFromServer(api: auth.api);
    } catch (_) {
      // Keep the local embedding DB usable when reference sync is unavailable.
    }
  }

  void _setStatus(
    String value, {
    bool showSnackBar = false,
    Color? snackColor,
  }) {
    if (!mounted || _status == value) return;
    setState(() => _status = value);
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: snackColor ?? AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _switchMode(AttendanceMode mode) async {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _enrollmentSamples.clear();
      _serverEnrollmentSamples.clear();
      _resolvedEnrollmentBackendEmployeeId = null;
      _isEnrollmentCompleted = false;
      _showEnrollmentSampleSuccess = false;
      _status = mode == AttendanceMode.enrollment
          ? 'Nhập thông tin rồi nhìn thẳng camera'
          : 'Đưa khuôn mặt vào giữa khung hình';
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _network?.removeListener(_handleNetworkChanged);
    _cameraController?.dispose();
    _faceDetector.dispose();
    _embeddingService.dispose();
    _livenessService.dispose();
    _databaseService.close();
    _employeeIdController.dispose();
    _employeeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final isEnrollment = _mode == AttendanceMode.enrollment;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildCameraLayer(controller)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                Flexible(child: Center(child: _buildFaceFrame())),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildBottomPanel(isEnrollment),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer(CameraController? controller) {
    if (controller == null || !controller.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SegmentedButton<AttendanceMode>(
              segments: const [
                ButtonSegment(
                  value: AttendanceMode.verification,
                  icon: Icon(LucideIcons.scanFace),
                  label: Text('Chấm công'),
                ),
                ButtonSegment(
                  value: AttendanceMode.enrollment,
                  icon: Icon(LucideIcons.userPlus),
                  label: Text('Đăng ký'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => _switchMode(selection.first),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.black
                      : Colors.white,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceFrame() {
    final size = MediaQuery.sizeOf(context);
    final frameHeight = (size.height * 0.38).clamp(220.0, 340.0);
    final frameWidth = (frameHeight * 0.76).clamp(170.0, 260.0);

    return Container(
      width: frameWidth,
      height: frameHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(frameWidth / 2),
        border: Border.all(
          color: _showEnrollmentSampleSuccess
              ? AppColors.success
              : _isPendingServerConfirmation
              ? AppColors.warning
              : _isSaving
              ? AppColors.success
              : Colors.white70,
          width: _showEnrollmentSampleSuccess ? 4 : 2,
        ),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: _showEnrollmentSampleSuccess
              ? Container(
                  key: const ValueKey('enrollment-sample-success'),
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.38),
                        blurRadius: 28,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    color: Colors.white,
                    size: 68,
                  ),
                )
              : Icon(
                  key: const ValueKey('face-frame-placeholder'),
                  _mode == AttendanceMode.enrollment
                      ? LucideIcons.userPlus
                      : LucideIcons.scanFace,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 52,
                ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isEnrollment) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 430),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEnrollment) _buildEnrollmentForm(),
            if (isEnrollment) ...[
              const SizedBox(height: 12),
              _buildEnrollmentGuidance(),
            ],
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isCameraReady
                  ? DateFormat('HH:mm:ss dd/MM/yyyy').format(DateTime.now())
                  : 'Đang chuẩn bị camera...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentGuidance() {
    final collectedSlots = _collectedEnrollmentSlots();
    final activeIndex = _enrollmentSlotOrder.indexWhere(
      (slot) => !collectedSlots.contains(slot),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.checklist, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thu $_enrollmentSampleCount/$_requiredEnrollmentSamples mẫu - nghỉ 1.8 giây sau mỗi mẫu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _enrollmentSlotOrder.length; i++)
                _buildEnrollmentStepRow(
                  slot: _enrollmentSlotOrder[i],
                  isDone: collectedSlots.contains(_enrollmentSlotOrder[i]),
                  isActive: i == activeIndex,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnrollmentStepRow({
    required EnrollmentVariationSlot slot,
    required bool isDone,
    required bool isActive,
  }) {
    final color = isDone
        ? AppColors.success
        : isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.48);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_enrollmentSlotTitle(slot)} - ${_enrollmentSlotHint(slot)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                height: 1.25,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        children: [
          TextField(
            controller: _employeeIdController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Mã nhân viên', LucideIcons.badge),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _employeeNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Tên nhân viên', LucideIcons.user),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.35),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }
}

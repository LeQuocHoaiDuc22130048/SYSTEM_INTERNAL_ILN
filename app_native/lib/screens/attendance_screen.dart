import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../services/embedding_service.dart';
import '../services/face_detector_service.dart';
import '../theme/app_colors.dart';
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

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _faceDetector = FaceDetectorService();
  final _embeddingService = EmbeddingService();
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
  NetworkProvider? _network;
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<List<double>> _enrollmentSamples = [];

  static const _frameInterval = Duration(milliseconds: 750);
  static const _matchThreshold = 0.60;
  static const _duplicateThreshold = 0.78;
  static const _requiredEnrollmentSamples = 5;

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
      _setInitialStatus('Đang nạp model offline...');
      await Future.wait([_embeddingService.init(), _databaseService.database]);
      await _syncPendingIfOnline(showStatus: false);
      _setInitialStatus('Đang mở camera...');

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _status = 'Camera sẵn sàng. Đưa khuôn mặt vào giữa khung hình';
      });

      unawaited(_scanPreviewFrames());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyInitializationError(error);
      });
    }
  }

  void _setInitialStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  String _friendlyInitializationError(Object error) {
    if (error is MissingFaceModelException) {
      return 'Chưa có model AI offline. Thêm arcface.tflite vào assets/models rồi rebuild app.';
    }
    return 'Không thể khởi tạo AI offline. Kiểm tra quyền camera và model TFLite.';
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
          final file = await controller.takePicture();
          final detected = await _faceDetector.detectPrimaryFaceFromFile(
            file.path,
          );
          if (detected == null) {
            _setStatus('Cần 1 khuôn mặt chính diện, mắt mở');
          } else {
            final embedding = await _embeddingService.extractEmbedding(
              frame: detected.frame,
              face: detected.face,
            );
            if (!_isVerifyingFace) {
              _isVerifyingFace = true;
              _setStatus('Đang xác minh khuôn mặt...');
              await Future<void>.delayed(const Duration(milliseconds: 1400));
              _isVerifyingFace = false;
            }
            if (_mode == AttendanceMode.enrollment) {
              await _handleEnrollmentEmbedding(embedding);
            } else {
              await _handleVerificationEmbedding(embedding);
            }
          }
        } catch (_) {
          _isVerifyingFace = false;
          _setStatus('Đang thử lại khung hình camera...');
        } finally {
          _isProcessingFrame = false;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _handleEnrollmentEmbedding(List<double> embedding) async {
    final employeeId = _employeeIdController.text.trim();
    final employeeName = _employeeNameController.text.trim();
    if (employeeId.isEmpty || employeeName.isEmpty) {
      _setStatus('Nhập mã và tên nhân viên trước khi đăng ký');
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

      final tooSimilarToExistingSample = _enrollmentSamples.any(
        (sample) => _cosineSimilarity(sample, embedding) > 0.995,
      );
      if (!tooSimilarToExistingSample) {
        _enrollmentSamples.add(embedding);
      }

      if (_enrollmentSamples.length < _requiredEnrollmentSamples) {
        _setStatus(
          'Đã thu ${_enrollmentSamples.length}/$_requiredEnrollmentSamples mẫu. Vui lòng đổi nhẹ góc mặt hoặc biểu cảm.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }

      await _databaseService.replaceEmployeeFaceSamples(
        employee: EnrolledEmployee(
          id: employeeId,
          name: employeeName,
          backendEmployeeId: widget.initialBackendEmployeeId,
          modelName: _embeddingService.modelName,
        ),
        embeddings: _enrollmentSamples,
      );
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

  Future<void> _handleVerificationEmbedding(List<double> embedding) async {
    final match = await _databaseService.findBestMatch(
      embedding,
      modelName: _embeddingService.modelName,
      threshold: _matchThreshold,
    );
    if (match == null) {
      _setStatus('Không tìm thấy nhân viên phù hợp');
      return;
    }

    _isSaving = true;
    try {
      await _databaseService.insertAttendanceLog(match);
      final synced = await _syncPendingIfOnline(showStatus: false);
      final statusText = synced > 0
          ? 'Chấm công thành công: ${match.employee.name}'
          : 'Đã ghi nhận chấm công: ${match.employee.name}. Dữ liệu sẽ tự cập nhật khi có mạng.';
      _setStatus(statusText, showSnackBar: true);
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
      final synced = await _databaseService.syncPendingAttendanceLogs(
        api: auth.api,
        currentUserId: auth.currentUser?.id,
      );
      if (synced > 0 && mounted) {
        await context.read<BackendDataProvider>().loadAttendance();
        if (showStatus) {
          _setStatus('Dữ liệu chấm công đã được cập nhật');
        }
      }
      return synced;
    } finally {
      _isSyncing = false;
    }
  }

  void _setStatus(String value, {bool showSnackBar = false}) {
    if (!mounted || _status == value) return;
    setState(() => _status = value);
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: AppColors.success,
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
          color: _isSaving ? AppColors.success : Colors.white70,
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          _mode == AttendanceMode.enrollment
              ? LucideIcons.userPlus
              : LucideIcons.scanFace,
          color: Colors.white.withValues(alpha: 0.55),
          size: 52,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(bool isEnrollment) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEnrollment) _buildEnrollmentForm(),
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

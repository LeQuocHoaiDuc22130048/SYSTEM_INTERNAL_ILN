import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import 'package:camera/camera.dart';

class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  bool _isScanning = true;
  bool _isSuccess = false;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _startSimulatedScan();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startSimulatedScan() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isScanning = false;
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.black,
      body: Stack(
        children: [
          // Background - Real Camera Preview
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && _controller != null) {
                  return Center(
                    child: CameraPreview(_controller!),
                  );
                } else {
                  return Center(
                    child: Icon(
                      LucideIcons.user,
                      size: 280,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  );
                }
              },
            ),
          ),

          // Dark overlay for better UI contrast
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),

          // Scanning Overlay
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  'NHẬN DIỆN KHUÔN MẶT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ).animate().fadeIn(),
                const Spacer(),
                
                // Scanning Frame
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Scanner Aura
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
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds),

                      // Main Frame
                      Container(
                        width: 260,
                        height: 360,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(130),
                          border: Border.all(
                            color: _isSuccess 
                                ? AppColors.success 
                                : Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(130),
                          child: Stack(
                            children: [
                              if (_isScanning)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          AppColors.primary.withValues(alpha: 0.4),
                                          AppColors.primary.withValues(alpha: 0),
                                        ],
                                      ),
                                    ),
                                  ).animate(onPlay: (c) => c.repeat())
                                   .moveY(begin: -120, end: 400, duration: 2.seconds),
                                ),
                              
                              if (_isSuccess)
                                Container(
                                  color: AppColors.success.withValues(alpha: 0.1),
                                  child: Center(
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 80,
                                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Corner Guides
                      if (_isScanning)
                        SizedBox(
                          width: 280,
                          height: 400,
                          child: Stack(
                            children: [
                              _buildModernCorner(0, 0),
                              _buildModernCorner(1, 0),
                              _buildModernCorner(0, 1),
                              _buildModernCorner(1, 1),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Instructions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Text(
                        _isSuccess ? 'Đã nhận diện' : 'Đang quét...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ).animate(target: _isSuccess ? 1 : 0).shimmer(),
                      const SizedBox(height: 12),
                      Text(
                        _isSuccess 
                          ? 'Võ Minh Khoa\n08:30:45 AM - Văn phòng' 
                          : 'Vui lòng đưa khuôn mặt vào giữa khung hình',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withValues(alpha: 0.6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Hủy bỏ'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_isSuccess)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Xác nhận'),
                          ).animate().fadeIn().scale(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Floating Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
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

  Widget _buildModernCorner(int h, int v) {
    return Positioned(
      top: v == 0 ? 0 : null,
      bottom: v == 1 ? 0 : null,
      left: h == 0 ? 0 : null,
      right: h == 1 ? 0 : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: v == 0 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            bottom: v == 1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            left: h == 0 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
            right: h == 1 ? const BorderSide(color: AppColors.primary, width: 4) : BorderSide.none,
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
     .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds);
  }
}

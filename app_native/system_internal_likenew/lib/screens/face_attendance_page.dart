import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class FaceAttendancePage extends StatefulWidget {
  const FaceAttendancePage({super.key});

  @override
  State<FaceAttendancePage> createState() => _FaceAttendancePageState();
}

class _FaceAttendancePageState extends State<FaceAttendancePage> {
  bool _isScanning = true;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _startSimulatedScan();
  }

  void _startSimulatedScan() async {
    await Future.delayed(const Duration(seconds: 4));
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chấm công khuôn mặt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          // Camera Preview Area
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simulated Camera Frame
                Container(
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(140),
                    border: Border.all(
                      color: _isSuccess ? AppColors.success : AppColors.primary,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSuccess ? AppColors.success : AppColors.primary).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(140),
                    child: Stack(
                      children: [
                        // Placeholder for User Face (Simulated)
                        Center(
                          child: Icon(
                            LucideIcons.user,
                            size: 120,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        
                        // Scanning Animation
                        if (_isScanning)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0),
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0),
                                  ],
                                ),
                              ),
                            )
                            .animate(onPlay: (controller) => controller.repeat())
                            .moveY(begin: 50, end: 330, duration: 2.seconds, curve: Curves.easeInOut),
                          ),
                        
                        // Success Overlay
                        if (_isSuccess)
                          Container(
                            color: AppColors.success.withOpacity(0.1),
                            child: const Center(
                              child: Icon(
                                Icons.check_circle,
                                color: AppColors.success,
                                size: 80,
                              ),
                            ),
                          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                      ],
                    ),
                  ),
                ),
                
                // Face Frame Guide (Corners)
                if (_isScanning)
                  SizedBox(
                    width: 240,
                    height: 340,
                    child: Stack(
                      children: [
                        _buildCorner(0, 0), // Top left
                        _buildCorner(1, 0), // Top right
                        _buildCorner(0, 1), // Bottom left
                        _buildCorner(1, 1), // Bottom right
                      ],
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .fadeIn(duration: 1.seconds)
                  .scale(begin: const Offset(0.98, 0.98), end: const Offset(1.02, 1.02), duration: 2.seconds),
                
                // Tech Overlay (Icon)
                if (_isScanning)
                  Icon(
                    LucideIcons.scanFace,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ).animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2.seconds, color: AppColors.primary.withOpacity(0.5)),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Instruction Text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Text(
                  _isSuccess ? 'Chấm công thành công!' : 'Đang nhận diện khuôn mặt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isSuccess 
                    ? 'Thời gian: 08:30:45 AM\nĐịa điểm: Văn phòng chính' 
                    : 'Vui lòng giữ điện thoại ổn định và đưa khuôn mặt vào trong khung hình',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                    ),
                    child: Text(
                      'Hủy bỏ',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSuccess ? () => Navigator.pop(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_isSuccess ? 'Xác nhận' : 'Đang quét...'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCorner(int horizontal, int vertical) {
    return Positioned(
      top: vertical == 0 ? 0 : null,
      bottom: vertical == 1 ? 0 : null,
      left: horizontal == 0 ? 0 : null,
      right: horizontal == 1 ? 0 : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: vertical == 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            bottom: vertical == 1 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            left: horizontal == 0 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
            right: horizontal == 1 ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

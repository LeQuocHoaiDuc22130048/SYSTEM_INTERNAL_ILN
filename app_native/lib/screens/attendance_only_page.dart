import '../widgets/permission_gate.dart';
import 'package:provider/provider.dart';
import '../utils/auth_provider.dart';
import '../models/app_permission.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class AttendanceOnlyPage extends StatelessWidget {
  const AttendanceOnlyPage({
    super.key,
    required this.onStartScan,
    required this.onLogout,
  });

  final VoidCallback onStartScan;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: onLogout,
                icon: const Icon(LucideIcons.logOut, color: Colors.white70),
                tooltip: '\u0110\u0103ng xu\u1EA5t',
              ),
            ),
            Positioned(
              top: 60,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: context.read<AuthProvider>().tablets,
                builder: (context, _) {
                  final t = context.read<AuthProvider>().tablets;
                  return Column(
                    children: [
                      Text(
                        t.message,
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Mã tablet: ${t.deviceId ?? "Chưa đăng ký"}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        'Chờ gửi: ${t.pendingSync} · Chờ duyệt: ${t.pendingReview}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (t.authorization != null)
                        Text(
                          'Offline đến: ${t.authorization!.expiresAt.toLocal()}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      TextButton(
                        onPressed: () => t.refresh(),
                        child: const Text('Kết nối / kiểm tra lại'),
                      ),
                      if (t.deviceId != null)
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Chuyển dữ liệu cũ'),
                                content: const Text(
                                  'Gửi các lượt cũ không xác định được tài khoản gốc để admin kiểm tra và chỉnh công thủ công. Các lượt này không tự động được tính công.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Gửi để kiểm tra'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              final count = await t.transferLegacyForReview();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Đã chuyển $count lượt cũ sang hàng đợi kiểm tra.',
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Chưa chuyển được dữ liệu cũ. Vui lòng thử lại.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text(
                            'Chuyển dữ liệu cũ để admin kiểm tra',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Center(
              child: PermissionGate(
                permission: AppPermission.useAttendanceKiosk,
                child: FilledButton.icon(
                  onPressed: () async {
                    final service = context.read<AuthProvider>().tablets;
                    if (await service.canCapture()) {
                      onStartScan();
                    } else {
                      await service.refresh();
                      if (context.mounted && await service.canCapture()) {
                        onStartScan();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(service.message)),
                        );
                      }
                    }
                  },
                  icon: const Icon(LucideIcons.scanFace, size: 24),
                  label: const Text(
                    'Ch\u1EA5m c\u00F4ng / Qu\u00E9t khu\u00F4n m\u1EB7t',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

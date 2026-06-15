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
            Center(
              child: FilledButton.icon(
                onPressed: onStartScan,
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
          ],
        ),
      ),
    );
  }
}

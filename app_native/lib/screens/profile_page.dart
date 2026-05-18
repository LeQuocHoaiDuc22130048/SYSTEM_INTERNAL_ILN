import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmployee = Provider.of<AuthProvider>(context).isEmployee;
    
    final name = isEmployee ? 'Nguyễn Văn Nhân Viên' : 'Nguyễn Văn Quản Lý';
    final role = isEmployee ? 'Nhân viên - NV-2024-002' : 'Quản lý - QL-2024-001';
    final avatarColor = isEmployee ? Colors.blue : const Color(0xFFD946EF);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundColor: avatarColor,
                child: const Text(
                  'NV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoSection(isDark),
              const SizedBox(height: 24),
              _buildSettingsSection(isDark, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: LucideIcons.mail,
            title: 'Email',
            value: 'nguyenvan@example.com',
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          _buildInfoTile(
            icon: LucideIcons.phone,
            title: 'Số điện thoại',
            value: '0987654321',
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          _buildInfoTile(
            icon: LucideIcons.mapPin,
            title: 'Địa chỉ',
            value: '123 Đường ABC, Quận X, TP Y',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(bool isDark, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(LucideIcons.settings, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            title: Text(
              'Cài đặt tài khoản',
              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
            trailing: Icon(LucideIcons.chevronRight, size: 18, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            onTap: () {},
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ListTile(
            leading: Icon(LucideIcons.lock, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            title: Text(
              'Đổi mật khẩu',
              style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
            trailing: Icon(LucideIcons.chevronRight, size: 18, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

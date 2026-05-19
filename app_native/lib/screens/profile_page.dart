import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final name = user?.name ?? 'Người dùng';
    final role = user == null
        ? ''
        : '${user.roleLabel} - ${user.employeeId.isEmpty ? user.username : user.employeeId}';
    final avatarColor = auth.isEmployee ? Colors.blue : const Color(0xFFD946EF);
    final initials = _initials(name);

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
                child: Text(
                  initials,
                  style: const TextStyle(
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
              _buildInfoSection(isDark, user),
              const SizedBox(height: 24),
              _buildSettingsSection(isDark, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isDark, User? user) {
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
            icon: LucideIcons.user,
            title: 'Tên đăng nhập',
            value: user?.username ?? '-',
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          _buildInfoTile(
            icon: LucideIcons.phone,
            title: 'Số điện thoại',
            value: user?.phone ?? '-',
            isDark: isDark,
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          _buildInfoTile(
            icon: LucideIcons.building2,
            title: 'Bộ phận',
            value: user?.department ?? '-',
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

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'ND';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}

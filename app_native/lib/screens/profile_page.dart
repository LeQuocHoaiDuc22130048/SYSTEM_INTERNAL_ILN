import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
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
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 32),
              _buildInfoSection(isDark, user),
              const SizedBox(height: 24),
              _buildSettingsSection(isDark, user),
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
          Divider(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          _buildInfoTile(
            icon: LucideIcons.phone,
            title: 'Số điện thoại',
            value: user?.phone ?? '-',
            isDark: isDark,
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
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

  Widget _buildSettingsSection(bool isDark, User? user) {
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
            leading: Icon(
              LucideIcons.settings,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            title: Text(
              'Cài đặt tài khoản',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            onTap: user == null ? null : () => _showAccountSettings(user),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          ListTile(
            leading: Icon(
              LucideIcons.lock,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            title: Text(
              'Đổi mật khẩu',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            trailing: Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            onTap: _showChangePassword,
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
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountSettings(User user) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final departmentController = TextEditingController(
      text: user.department ?? '',
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSaving = false;

          Future<void> submit(StateSetter setDialogState) async {
            if (!formKey.currentState!.validate()) return;

            setDialogState(() => isSaving = true);
            try {
              await context.read<AuthProvider>().updateProfile(
                fullName: nameController.text.trim(),
                phone: phoneController.text.trim(),
                department: departmentController.text.trim(),
              );

              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              _showSnackBar('Đã cập nhật thông tin tài khoản.');
            } on ApiException catch (error) {
              if (dialogContext.mounted) {
                _showSnackBar(error.message, isError: true);
              }
            } catch (_) {
              if (dialogContext.mounted) {
                _showSnackBar(
                  'Không thể cập nhật thông tin. Vui lòng thử lại.',
                  isError: true,
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isSaving = false);
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Cài đặt tài khoản'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: _inputDecoration('Họ tên'),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập họ tên.';
                          }
                          if (value.trim().length > 100) {
                            return 'Họ tên tối đa 100 ký tự.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        decoration: _inputDecoration('Số điện thoại'),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isEmpty) return null;
                          if (!RegExp(r'^[0-9]{10,11}$').hasMatch(phone)) {
                            return 'Số điện thoại phải có 10-11 chữ số.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: departmentController,
                        decoration: _inputDecoration('Bộ phận'),
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if ((value?.trim().length ?? 0) > 100) {
                            return 'Bộ phận tối đa 100 ký tự.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () => submit(setDialogState),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Delay disposal to prevent text fields from accessing disposed controllers during transition
      Future.delayed(const Duration(milliseconds: 500), () {
        nameController.dispose();
        phoneController.dispose();
        departmentController.dispose();
      });
    }
  }

  Future<void> _showChangePassword() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSaving = false;

          Future<void> submit(StateSetter setDialogState) async {
            if (!formKey.currentState!.validate()) return;

            setDialogState(() => isSaving = true);
            try {
              await context.read<AuthProvider>().changePassword(
                currentPassword: currentController.text,
                newPassword: newController.text,
                confirmPassword: confirmController.text,
              );

              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              _showSnackBar(
                'Đổi mật khẩu thành công. Vui lòng đăng nhập lại.',
              );
            } on ApiException catch (error) {
              if (dialogContext.mounted) {
                _showSnackBar(error.message, isError: true);
              }
            } catch (_) {
              if (dialogContext.mounted) {
                _showSnackBar(
                  'Không thể đổi mật khẩu. Vui lòng thử lại.',
                  isError: true,
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isSaving = false);
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Đổi mật khẩu'),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentController,
                        decoration: _inputDecoration('Mật khẩu hiện tại'),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Vui lòng nhập mật khẩu hiện tại.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newController,
                        decoration: _inputDecoration('Mật khẩu mới'),
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final password = value ?? '';
                          if (!RegExp(
                            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$',
                          ).hasMatch(password)) {
                            return 'Tối thiểu 8 ký tự, gồm chữ hoa, chữ thường và số.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmController,
                        decoration: _inputDecoration('Xác nhận mật khẩu mới'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value != newController.text) {
                            return 'Mật khẩu xác nhận không khớp.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                   TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () => submit(setDialogState),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Đổi mật khẩu'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Delay disposal to prevent text fields from accessing disposed controllers during transition
      Future.delayed(const Duration(milliseconds: 500), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
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

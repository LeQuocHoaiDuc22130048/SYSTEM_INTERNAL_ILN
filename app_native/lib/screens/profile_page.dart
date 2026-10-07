import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/app_routes.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/auth_provider.dart';
import '../utils/notification_provider.dart';
import '../utils/update_provider.dart';
import '../widgets/navigation/app_back_button.dart';
import '../widgets/navigation/mobile_navigation_bar.dart';
import '../widgets/app_quick_actions.dart';
import 'privacy_policy_page.dart';

/// Profile Page designed faithfully according to Stitch Home Service Marketplace
/// Preserving all existing functionality, options, dialogs, and backend integrations.
class ProfilePage extends StatefulWidget {
  final bool showBottomNav;
  final bool hideTopBar;
  final VoidCallback? onNavigateToHome;
  final void Function(int tabIndex)? onNavigateToTab;

  const ProfilePage({
    super.key,
    this.showBottomNav = false,
    this.hideTopBar = false,
    this.onNavigateToHome,
    this.onNavigateToTab,
  });

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
    final initials = _initials(name);
    final updateProvider = context.watch<UpdateProvider>();
    final currentVersion = updateProvider.currentVersion;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar matching Stitch
            if (!widget.hideTopBar) _buildTopBar(isDark, user),

            // Scrollable Profile Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  children: [
                    // Hero Section: Avatar with Camera Badge, Name, Handle, Edit Profile Pill
                    _buildHeroSection(isDark, user, name, initials),
                    const SizedBox(height: 24),

                    // Section 1: Thông tin tài khoản (Preserved from old version)
                    _buildSectionHeader(isDark, 'THÔNG TIN TÀI KHOẢN'),
                    const SizedBox(height: 8),
                    _buildAccountInfoCard(isDark, user),
                    const SizedBox(height: 24),

                    // Section 2: Cài đặt & Tiện ích (Preserved from old version)
                    _buildSectionHeader(isDark, 'CÀI ĐẶT & HỆ THỐNG'),
                    const SizedBox(height: 8),
                    _buildSettingsCard(isDark, user, currentVersion),
                    const SizedBox(height: 24),

                    // Section 3: Tài khoản & Thao tác nguy hiểm (Preserved from old version)
                    _buildSectionHeader(isDark, 'BẢO MẬT & TÀI KHOẢN'),
                    const SizedBox(height: 8),
                    _buildSecurityActionsCard(isDark, user),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? MobileNavigationBar(
              isDark: isDark,
              profileSelected: true,
              onHome:
                  widget.onNavigateToHome ??
                  () => Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.home),
              onBooking: () => showAppQuickActions(
                context,
                onNavigateToTab: widget.onNavigateToTab,
              ),
              onProfile: () {},
            )
          : null,
    );
  }

  // 1. Top Navigation Bar (Stitch style)
  Widget _buildTopBar(bool isDark, User? user) {
    final canPop = Navigator.of(context).canPop();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back / Home button
          AppBackButton(
            isDark: isDark,
            icon: (widget.onNavigateToHome != null || canPop)
                ? LucideIcons.chevronLeft
                : LucideIcons.house,
            onPressed: () {
              if (widget.onNavigateToHome != null) {
                widget.onNavigateToHome!();
              } else if (canPop) {
                Navigator.of(context).maybePop();
              } else {
                Navigator.of(context).pushReplacementNamed(AppRoutes.home);
              }
            },
          ),

          // Title
          Text(
            'Hồ sơ của tôi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),

          // Settings Action Button
          InkWell(
            onTap: user == null ? null : () => _showAccountSettings(user),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                LucideIcons.settings,
                size: 18,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Hero Avatar & Profile Identity
  Widget _buildHeroSection(
    bool isDark,
    User? user,
    String name,
    String initials,
  ) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Centered Avatar with Camera Badge
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar Circle
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3.5),
                ),
                child: ClipOval(
                  child: user?.avatar != null && user!.avatar!.isNotEmpty
                      ? Image.network(
                          user.avatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitialsWidget(initials),
                        )
                      : _buildInitialsWidget(initials),
                ),
              ),

              // Camera Icon Badge at bottom-right
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: user == null ? null : () => _showAccountSettings(user),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.camera,
                      size: 15,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Full Name
        Text(
          name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),

        // Handle & Role
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null && user.roleLabel.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                ),
                child: Text(
                  user.roleLabel,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              '@${user?.username ?? 'user'}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Edit Profile Pill Button (Matching Stitch)
        ElevatedButton(
          onPressed: user == null ? null : () => _showAccountSettings(user),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 3,
            shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.pencil, size: 14),
              SizedBox(width: 6),
              Text(
                'Chỉnh sửa hồ sơ',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsWidget(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // 3. Section Header
  Widget _buildSectionHeader(bool isDark, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textSecondaryDark
                : const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  // 4. Section 1: Thông tin tài khoản
  Widget _buildAccountInfoCard(bool isDark, User? user) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            _buildInfoRow(
              icon: LucideIcons.user,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              title: 'Tên đăng nhập',
              value: user?.username ?? '-',
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildInfoRow(
              icon: LucideIcons.phone,
              iconBg: const Color(0xFFECFDF5),
              iconColor: const Color(0xFF059669),
              title: 'Số điện thoại',
              value: user?.phone ?? '-',
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildInfoRow(
              icon: LucideIcons.building2,
              iconBg: const Color(0xFFFFFBEB),
              iconColor: const Color(0xFFD97706),
              title: 'Bộ phận',
              value: user?.department ?? '-',
              isDark: isDark,
            ),
            _buildDivider(isDark),
            _buildInfoRow(
              icon: LucideIcons.badgeCheck,
              iconBg: const Color(0xFFF5F3FF),
              iconColor: const Color(0xFF7C3AED),
              title: 'Mã nhân viên / Vai trò',
              value: user != null
                  ? '${user.employeeId.isNotEmpty ? user.employeeId : user.username} (${user.roleLabel})'
                  : '-',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  // 5. Section 2: Cài đặt & Tiện ích
  Widget _buildSettingsCard(bool isDark, User? user, String currentVersion) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            _buildActionRow(
              icon: LucideIcons.userCog,
              iconBg: const Color(0xFFEFF6FF),
              iconColor: const Color(0xFF2563EB),
              title: 'Cài đặt tài khoản',
              subtitle: 'Cập nhật họ tên, điện thoại, bộ phận',
              isDark: isDark,
              onTap: user == null ? null : () => _showAccountSettings(user),
            ),
            _buildDivider(isDark),
            _buildActionRow(
              icon: LucideIcons.lockKeyhole,
              iconBg: const Color(0xFFEEF2FF),
              iconColor: const Color(0xFF4F46E5),
              title: 'Đổi mật khẩu',
              subtitle: 'Cập nhật mật khẩu bảo vệ tài khoản',
              isDark: isDark,
              onTap: _showChangePassword,
            ),
            _buildDivider(isDark),
            _buildActionRow(
              icon: LucideIcons.refreshCw,
              iconBg: const Color(0xFFF0FDF4),
              iconColor: const Color(0xFF16A34A),
              title: 'Kiểm tra cập nhật',
              subtitle: 'Phiên bản hiện tại: v$currentVersion',
              isDark: isDark,
              onTap: () {
                context.read<UpdateProvider>().checkForUpdate(
                  context,
                  manual: true,
                );
              },
            ),
            _buildDivider(isDark),
            _buildActionRow(
              icon: LucideIcons.shieldCheck,
              iconBg: const Color(0xFFFAF5FF),
              iconColor: const Color(0xFF9333EA),
              title: 'Chính sách bảo mật',
              subtitle: 'Quy định quyền riêng tư & bảo vệ dữ liệu',
              isDark: isDark,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 6. Section 3: Bảo mật & Thao tác tài khoản
  Widget _buildSecurityActionsCard(bool isDark, User? user) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            _buildActionRow(
              icon: LucideIcons.logOut,
              iconBg: const Color(0xFFFFF1F2),
              iconColor: const Color(0xFFE11D48),
              title: 'Đăng xuất',
              subtitle: 'Đăng xuất khỏi phiên làm việc hiện tại',
              titleColor: const Color(0xFFE11D48),
              isDark: isDark,
              onTap: _handleLogout,
            ),
            _buildDivider(isDark),
            _buildActionRow(
              icon: LucideIcons.userX,
              iconBg: const Color(0xFFFEF2F2),
              iconColor: Colors.red,
              title: 'Xóa tài khoản',
              subtitle: 'Vô hiệu hóa vĩnh viễn tài khoản và dữ liệu',
              titleColor: Colors.red,
              isDark: isDark,
              onTap: user == null ? null : () => _showDeleteAccountDialog(user),
            ),
          ],
        ),
      ),
    );
  }

  // Helper row for info display
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper row for interactive action
  Widget _buildActionRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color:
                          titleColor ??
                          (isDark
                              ? AppColors.textPrimaryDark
                              : const Color(0xFF1E293B)),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color:
                  titleColor ??
                  (isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFFCBD5E1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      endIndent: 16,
      color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
    );
  }

  // =========================================================================
  // PRESERVED MODALS & ACTION HANDLERS (Identical Logic & Validation)
  // =========================================================================

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<NotificationProvider>().prepareForLogout();
        if (!mounted) return;
        await context.read<AuthProvider>().logout();
      } catch (_) {
        _showSnackBar('Không thể đăng xuất. Vui lòng thử lại.', isError: true);
      }
    }
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
              _showSnackBar('Đã cập nhật thông tin tài khoản thành công.');
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  'Cài đặt tài khoản',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
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
                    onPressed: isSaving ? null : () => submit(setDialogState),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Lưu thay đổi'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
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
              _showSnackBar('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  'Đổi mật khẩu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
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
                    onPressed: isSaving ? null : () => submit(setDialogState),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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
      Future.delayed(const Duration(milliseconds: 500), () {
        currentController.dispose();
        newController.dispose();
        confirmController.dispose();
      });
    }
  }

  Future<void> _showDeleteAccountDialog(User user) async {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();
    final reasonController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isDeleting = false;
          var obscurePassword = true;
          var confirmedCheckbox = false;
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

          Future<void> submit(StateSetter setDialogState) async {
            if (!formKey.currentState!.validate()) return;
            if (!confirmedCheckbox) {
              _showSnackBar(
                'Vui lòng đánh dấu xác nhận đồng ý xóa tài khoản.',
                isError: true,
              );
              return;
            }

            setDialogState(() => isDeleting = true);
            try {
              await context.read<NotificationProvider>().prepareForLogout();
              if (!mounted) return;
              await context.read<AuthProvider>().deleteAccount(
                password: passwordController.text,
                reason: reasonController.text.trim().isEmpty
                    ? null
                    : reasonController.text.trim(),
              );

              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              _showSnackBar(
                'Tài khoản của bạn đã được xóa và vô hiệu hóa thành công.',
              );
            } on ApiException catch (error) {
              if (dialogContext.mounted) {
                _showSnackBar(error.message, isError: true);
              }
            } catch (_) {
              if (dialogContext.mounted) {
                _showSnackBar(
                  'Không thể xóa tài khoản. Vui lòng thử lại.',
                  isError: true,
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isDeleting = false);
              }
            }
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Row(
                  children: [
                    Icon(
                      LucideIcons.alertTriangle,
                      color: Colors.red,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Xóa tài khoản',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(
                              alpha: isDark ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CẢNH BÁO BẢO MẬT & DỮ LIỆU:',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '• Hành động này không thể hoàn tác.\n'
                                '• Mọi quyền truy cập hệ thống và phiên đăng nhập sẽ bị chấm dứt ngay lập tức.\n'
                                '• Dữ liệu tài khoản cá nhân và thông báo đẩy sẽ bị hủy bỏ hoàn toàn.\n'
                                '• Tài khoản sẽ bị vô hiệu hóa theo đúng quy trình bảo mật hệ thống.',
                                style: TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Xác minh mật khẩu để tiếp tục:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu hiện tại *',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 18,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                          obscureText: obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu xác nhận.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            labelText: 'Lý do xóa (tùy chọn)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: isDeleting
                              ? null
                              : () {
                                  setDialogState(() {
                                    confirmedCheckbox = !confirmedCheckbox;
                                  });
                                },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: confirmedCheckbox,
                                    activeColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: isDeleting
                                        ? null
                                        : (val) {
                                            setDialogState(() {
                                              confirmedCheckbox = val ?? false;
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Tôi hiểu và đồng ý xóa vĩnh viễn tài khoản này.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isDeleting
                        ? null
                        : () {
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: isDeleting ? null : () => submit(setDialogState),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isDeleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Xác nhận xóa tài khoản'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        passwordController.dispose();
        reasonController.dispose();
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

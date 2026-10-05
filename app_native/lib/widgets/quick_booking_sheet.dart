import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../app/app_routes.dart';
import '../models/app_permission.dart';
import '../navigation/main_tabs.dart';
import '../screens/location_management_page.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';

Future<void> showQuickBookingSheet(
  BuildContext context, {
  String? expertName,
  String? serviceName,
  void Function(int tabIndex)? onNavigateToTab,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickBookingSheet(
      expertName: expertName,
      serviceName: serviceName,
      onNavigateToTab: onNavigateToTab,
    ),
  );
}

class _QuickActionItem {
  const _QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
}

class _QuickBookingSheet extends StatefulWidget {
  const _QuickBookingSheet({
    this.expertName,
    this.serviceName,
    this.onNavigateToTab,
  });

  final String? expertName;
  final String? serviceName;
  final void Function(int tabIndex)? onNavigateToTab;

  @override
  State<_QuickBookingSheet> createState() => _QuickBookingSheetState();
}

class _QuickBookingSheetState extends State<_QuickBookingSheet> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF64748B);
    final fieldColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    // Xây dựng danh sách tác vụ nhanh dựa trên quyền của tài khoản (Phương án 1)
    final actions = <_QuickActionItem>[];

    if (auth.can(AppPermission.manageRepairOrders)) {
      actions.add(
        _QuickActionItem(
          title: 'Tạo đơn sửa chữa',
          subtitle: 'Tiếp nhận thiết bị & lập phiếu sửa',
          icon: LucideIcons.wrench,
          gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
          onTap: () {
            Navigator.of(context).pop();
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(MainTabs.repairOrders);
            } else {
              Navigator.of(context).pushNamed(
                AppRoutes.dashboard,
                arguments: MainTabs.repairOrders,
              );
            }
          },
        ),
      );
    }

    if (auth.can(AppPermission.manageWarehouse)) {
      actions.add(
        _QuickActionItem(
          title: 'Vị trí kho & Kệ hàng',
          subtitle: 'Thiết lập sơ đồ & tạo vị trí QR',
          icon: LucideIcons.mapPin,
          gradient: const [Color(0xFFEA580C), Color(0xFFF97316)],
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationManagementPage()),
            );
          },
        ),
      );
    }

    if (auth.can(AppPermission.manageWarehouse) ||
        auth.can(AppPermission.viewWarehouse)) {
      actions.add(
        _QuickActionItem(
          title: 'Kho bo mạch & Linh kiện',
          subtitle: 'Tra cứu tồn kho, xuất dùng & kiểm kê',
          icon: LucideIcons.boxes,
          gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
          onTap: () {
            Navigator.of(context).pop();
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(MainTabs.warehouse);
            } else {
              Navigator.of(
                context,
              ).pushNamed(AppRoutes.dashboard, arguments: MainTabs.warehouse);
            }
          },
        ),
      );
    }

    if (auth.can(AppPermission.useMessages)) {
      actions.add(
        _QuickActionItem(
          title: 'Cuộc trò chuyện mới',
          subtitle: 'Nhắn tin nội bộ, trao đổi kỹ thuật',
          icon: LucideIcons.messageSquarePlus,
          gradient: const [Color(0xFF7C3AED), Color(0xFF9333EA)],
          onTap: () {
            Navigator.of(context).pop();
            if (widget.onNavigateToTab != null) {
              widget.onNavigateToTab!(MainTabs.messages);
            } else {
              Navigator.of(
                context,
              ).pushNamed(AppRoutes.dashboard, arguments: MainTabs.messages);
            }
          },
        ),
      );
    }

    final isSpecificBooking =
        widget.expertName != null || widget.serviceName != null;
    final sheetTitle = widget.expertName != null
        ? 'Đặt lịch với ${widget.expertName}'
        : (widget.serviceName != null
              ? 'Đặt dịch vụ: ${widget.serviceName}'
              : 'Tạo mới & Thao tác nhanh');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Tiêu đề & nút đóng
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheetTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        if (!isSpecificBooking && auth.currentUser != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Tài khoản: ${auth.currentUser?.name ?? auth.currentUser?.username ?? ""} • ${auth.currentUser?.role ?? ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: secondaryTextColor,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              // Danh sách hành động theo quyền hạn (Chỉ hiện khi không phải đặt dịch vụ cụ thể)
              if (!isSpecificBooking && actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'NGHIỆP VỤ ĐƯỢC PHÂN QUYỀN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),
                ...actions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: action.onTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: fieldColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: action.gradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: action.gradient.first.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  action.icon,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      action.subtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                LucideIcons.chevronRight,
                                size: 18,
                                color: secondaryTextColor.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (!isSpecificBooking && actions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.shieldAlert,
                          size: 40,
                          color: secondaryTextColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có nghiệp vụ khả dụng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tài khoản của bạn chưa được phân quyền thao tác nhanh.',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // Chỉ hiển thị form đặt lịch khi được gọi cụ thể cho chuyên gia / dịch vụ
              if (isSpecificBooking) ...[
                const SizedBox(height: 16),
                Text(
                  'Mô tả yêu cầu hoặc lỗi cần sửa:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  style: TextStyle(color: primaryTextColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Nhập thông tin sự cố, mã lỗi hoặc yêu cầu kiểm tra...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: fieldColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Đã gửi yêu cầu dịch vụ thành công! Kỹ thuật viên sẽ liên hệ sớm.',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Xác nhận đặt lịch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

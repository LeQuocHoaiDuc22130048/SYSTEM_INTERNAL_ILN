import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../interactive_bounce.dart';
import 'account_avatar.dart';

class MobileNavigationBar extends StatelessWidget {
  const MobileNavigationBar({
    super.key,
    required this.isDark,
    required this.onHome,
    required this.onBooking,
    this.onOrders,
    this.onNotifications,
    this.onProfile,
    this.homeSelected = false,
    this.ordersSelected = false,
    this.notificationsSelected = false,
    this.profileSelected = false,
    this.notificationBadge = '',
  });

  final bool isDark;
  final bool homeSelected;
  final bool ordersSelected;
  final bool notificationsSelected;
  final bool profileSelected;
  final String notificationBadge;
  final VoidCallback onHome;
  final VoidCallback? onOrders;
  final VoidCallback onBooking;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final labelGrowth = (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(
      0.0,
      double.infinity,
    );
    final showNotifBadge =
        notificationBadge.isNotEmpty && notificationBadge != '0';

    return SizedBox(
      height: 78 + bottomInset + labelGrowth * 1.5,
      child: Stack(
        children: [
          Positioned.fill(
            top: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset + 10),
              child: Row(
                children: [
                  Expanded(
                    child: _tab(
                      'Trang chủ',
                      LucideIcons.house,
                      homeSelected,
                      onHome,
                      tabKey: const ValueKey('bottom-nav-home-tab'),
                    ),
                  ),
                  Expanded(
                    child: _tab(
                      'Đơn hàng',
                      LucideIcons.clipboardList,
                      ordersSelected,
                      onOrders ?? () {},
                      tabKey: const ValueKey('bottom-nav-orders-tab'),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Mở thao tác nhanh',
                      child: Tooltip(
                        message: 'Mở thao tác nhanh',
                        child: InteractiveBounce(
                          key: const ValueKey('bottom-nav-booking-button'),
                          scaleDown: 0.88,
                          onTap: onBooking,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF4F46E5),
                                      Color(0xFF3B82F6),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2563EB,
                                      ).withValues(alpha: 0.42),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: surface,
                                    width: 3.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    LucideIcons.plus,
                                    key: ValueKey('bottom-nav-center-icon'),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Text(
                                    'Tạo nhanh',
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _tab(
                      'Thông báo',
                      LucideIcons.bell,
                      notificationsSelected,
                      onNotifications ?? () {},
                      tabKey: const ValueKey('bottom-nav-notifications-tab'),
                      badgeText: showNotifBadge ? notificationBadge : null,
                    ),
                  ),
                  Expanded(
                    child: onProfile == null
                        ? const SizedBox.shrink()
                        : _tab(
                            'Cá nhân',
                            LucideIcons.user,
                            profileSelected,
                            onProfile!,
                            tabKey: const ValueKey('bottom-nav-profile-tab'),
                            iconWidget: AccountAvatar(
                              selected: profileSelected,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap, {
    Key? tabKey,
    Widget? iconWidget,
    String? badgeText,
  }) {
    final color = selected
        ? const Color(0xFF2563EB)
        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        selected: selected,
        button: true,
        child: Tooltip(
          message: label,
          child: InteractiveBounce(
            key: tabKey,
            scaleDown: 0.92,
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 38,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF2563EB).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: iconWidget ?? Icon(icon, size: 18, color: color),
                    ),
                    if (badgeText != null && badgeText.isNotEmpty)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 15,
                            minHeight: 15,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

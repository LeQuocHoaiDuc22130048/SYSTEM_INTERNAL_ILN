import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../theme/app_colors.dart';
import 'app_back_button.dart';
import 'badge_widgets.dart';

class DashboardMobileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DashboardMobileAppBar({
    super.key,
    required this.isDark,
    required this.notificationBadge,
    required this.onToggleTheme,
    required this.onToggleNotifications,
    this.showNotification = false,
    this.onBack,
    this.showBack = true,
  });

  final bool isDark;
  final String notificationBadge;
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleNotifications;
  final bool showNotification;
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(59);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    const barVerticalPadding = EdgeInsets.only(top: 6, bottom: 4);

    return AppBar(
      primary: true,
      toolbarHeight: 58,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleSpacing: 0,
      leadingWidth: 64,
      automaticallyImplyLeading: false,
      leading: showBack
          ? Padding(
              padding: const EdgeInsets.only(left: 16, top: 6, bottom: 4),
              child: Center(
                child: AppBackButton(
                  isDark: isDark,
                  tooltip: 'Quay lại Trang chủ',
                  onPressed:
                      onBack ??
                      () {
                        if (canPop) {
                          Navigator.of(context).maybePop();
                        } else {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (route) => false,
                          );
                        }
                      },
                ),
              ),
            )
          : null,
      title: Padding(
        padding: barVerticalPadding,
        child: Image.asset(
          "assets/images/app_logo.png",
          height: 32,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
      actions: [
        Padding(
          padding: barVerticalPadding,
          child: Center(
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 22),
              onPressed: onToggleTheme,
              tooltip: 'Giao diện',
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (showNotification)
          Padding(
            padding: barVerticalPadding,
            child: Center(
              child: BadgeIconButton(
                icon: Icons.notifications_outlined,
                badge: notificationBadge,
                tooltip: 'Thông báo',
                onPressed: onToggleNotifications,
              ),
            ),
          ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
    );
  }
}

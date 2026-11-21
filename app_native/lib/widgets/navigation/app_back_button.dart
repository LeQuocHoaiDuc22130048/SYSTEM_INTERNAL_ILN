import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';

/// Stitch-style back button with rounded square border and chevron icon,
/// synchronized across ProfilePage, MobileDashboardAppBar, and other screens.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool? isDark;
  final IconData? icon;
  final double size;
  final double iconSize;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.isDark,
    this.icon,
    this.size = 38,
    this.iconSize = 19,
    this.tooltip = 'Quay lại',
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final resolvedBg =
        backgroundColor ??
        (effectiveDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final resolvedBorder =
        borderColor ??
        (effectiveDark ? AppColors.borderDark : const Color(0xFFE2E8F0));
    final resolvedIcon =
        iconColor ??
        (effectiveDark ? AppColors.textPrimaryDark : const Color(0xFF334155));

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: resolvedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: resolvedBorder,
            ),
          ),
          child: Center(
            child: Icon(
              icon ?? LucideIcons.chevronLeft,
              size: iconSize,
              color: resolvedIcon,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}

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

  const AppBackButton({
    super.key,
    this.onPressed,
    this.isDark,
    this.icon,
    this.size = 38,
    this.iconSize = 19,
    this.tooltip = 'Quay lại',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDark =
        isDark ?? (Theme.of(context).brightness == Brightness.dark);

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveDark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: effectiveDark
                  ? AppColors.borderDark
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Center(
            child: Icon(
              icon ?? LucideIcons.chevronLeft,
              size: iconSize,
              color: effectiveDark
                  ? AppColors.textPrimaryDark
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}

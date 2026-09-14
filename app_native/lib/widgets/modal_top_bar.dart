import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Thanh trên cùng chuẩn cho các Bottom Sheet và Modal trên thiết bị di động.
/// Luôn có nút đóng (Icons.close) ở góc trên cùng bên trái theo tiêu chuẩn UX di động.
class ModalTopBar extends StatelessWidget {
  final VoidCallback? onClose;
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final bool showHandle;

  const ModalTopBar({
    super.key,
    this.onClose,
    this.title,
    this.titleWidget,
    this.trailing,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showHandle && title == null && titleWidget == null)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (titleWidget != null)
              Center(child: titleWidget!)
            else if (title != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  tooltip: 'Đóng',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  onPressed: onClose ?? () => Navigator.pop(context),
                ),
              ),
            ),
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
          ],
        ),
      ),
    );
  }
}

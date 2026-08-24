import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String color;
  final Map<String, dynamic>? trend;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = 'blue',
    this.trend,
    this.subtitle,
  });

  Map<String, Color> _getColors(String color, bool isDark) {
    switch (color) {
      case 'blue':
        return {
          'icon': isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
          'iconFg': AppColors.info,
          'border': const Color(0xFFBFDBFE),
        };
      case 'emerald':
        return {
          'icon': isDark ? const Color(0xFF064E3B) : AppColors.successLight,
          'iconFg': AppColors.success,
          'border': const Color(0xFFA7F3D0),
        };
      case 'amber':
        return {
          'icon': isDark ? const Color(0xFF78350F) : AppColors.warningLight,
          'iconFg': AppColors.warning,
          'border': const Color(0xFFFDE68A),
        };
      case 'red':
        return {
          'icon': isDark ? const Color(0xFF7F1D1D) : AppColors.errorLight,
          'iconFg': AppColors.error,
          'border': const Color(0xFFFECACA),
        };
      case 'purple':
        return {
          'icon': isDark ? const Color(0xFF581C87) : AppColors.purpleLight,
          'iconFg': AppColors.purple,
          'border': const Color(0xFFE9D5FF),
        };
      default:
        return {
          'icon': isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          'iconFg': const Color(0xFF64748B),
          'border': const Color(0xFFCBD5E1),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColors(color, isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    if (trend != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${trend!['value'] >= 0 ? '↑' : '↓'} ${(trend!['value'] as num).abs()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: trend!['value'] >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              trend!['label'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors['icon'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: colors['iconFg'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

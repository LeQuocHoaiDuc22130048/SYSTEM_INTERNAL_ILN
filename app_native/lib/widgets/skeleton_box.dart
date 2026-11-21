import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// Theme-aware skeleton placeholder that respects `MediaQuery.disableAnimationsOf(context)`.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF1B2A42)
        : const Color(0xFFE2E8F0);
    final highlightColor = isDark
        ? const Color(0xFF253959)
        : const Color(0xFFF1F5F9);

    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: borderRadius,
      ),
    );

    if (AppMotion.isReduced(context)) {
      return placeholder;
    }

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: placeholder,
    );
  }
}

/// Predictable skeleton layout for Dashboard loading states (Section 5.8).
class DashboardSkeleton extends StatelessWidget {
  final bool wide;

  const DashboardSkeleton({super.key, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Semantics(
      label: 'Đang tải dữ liệu Dashboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.builder(
            itemCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: wide ? 4 : 2,
              mainAxisSpacing: wide ? 20 : 10,
              crossAxisSpacing: wide ? 12 : 10,
              mainAxisExtent: wide ? 114 : 106,
            ),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 90, height: 12),
                    SkeletonBox(width: 56, height: 22),
                    SkeletonBox(width: 72, height: 10),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 16),
                SizedBox(height: 16),
                SkeletonBox(height: 190),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


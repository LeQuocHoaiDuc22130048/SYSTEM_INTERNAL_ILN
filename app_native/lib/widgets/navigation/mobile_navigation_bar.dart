import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/app_colors.dart';
import '../interactive_bounce.dart';

class MobileNavigationBar extends StatelessWidget {
  const MobileNavigationBar({
    super.key,
    required this.isDark,
    required this.onHome,
    required this.onBooking,
    this.onProfile,
    this.homeSelected = false,
    this.profileSelected = false,
  });

  final bool isDark;
  final bool homeSelected;
  final bool profileSelected;
  final VoidCallback onHome;
  final VoidCallback onBooking;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final labelGrowth = (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(
      0.0,
      double.infinity,
    );
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
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: _tab(
                      'Trang chủ',
                      LucideIcons.house,
                      homeSelected,
                      onHome,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Semantics(
                        button: true,
                        label: 'Đặt lịch dịch vụ mới',
                        child: Tooltip(
                          message: 'Đặt lịch dịch vụ mới',
                          child: InteractiveBounce(
                            scaleDown: 0.88,
                            onTap: onBooking,
                            child: Container(
                              width: 54,
                              height: 54,
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
                                    ).withValues(alpha: 0.45),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(color: surface, width: 3.5),
                              ),
                              child: const Icon(
                                LucideIcons.plus,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _tab(String label, IconData icon, bool selected, VoidCallback onTap) {
    final color = selected
        ? const Color(0xFF2563EB)
        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B));
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        selected: selected,
        button: true,
        child: InteractiveBounce(
          scaleDown: 0.92,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

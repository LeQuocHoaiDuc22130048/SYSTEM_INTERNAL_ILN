import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../navigation/main_tabs.dart';
import '../../navigation/navigation_item.dart';
import '../../theme/app_colors.dart';
import '../../utils/chat_provider.dart';
import 'badge_widgets.dart';

class MobileNavigationBar extends StatelessWidget {
  const MobileNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.isDark,
    required this.onIndexChanged,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onIndexChanged;

  @override
  Widget build(BuildContext context) {
    final unreadChats = context.watch<ChatProvider>().totalUnreadCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == item.tabIndex;
              final color = isSelected
                  ? Theme.of(context).primaryColor
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight);

              return Expanded(
                child: InkWell(
                  onTap: () => onIndexChanged(item.tabIndex),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 20,
                            color: color,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (item.tabIndex == MainTabs.messages && unreadChats > 0)
                        Positioned(
                          top: 10,
                          right: 22,
                          child: BadgePill(
                            text: unreadChats > 99
                                ? '99+'
                                : unreadChats.toString(),
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/app_permission.dart';
import '../../theme/app_colors.dart';
import '../../utils/auth_provider.dart';
import '../../utils/chat_provider.dart';

class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.currentIndex,
    required this.isDark,
    required this.isExpanded,
    required this.onIndexChanged,
    required this.onToggleExpand,
    required this.onToggleTheme,
    required this.notificationBadge,
    required this.onLogout,
  });

  final int currentIndex;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleTheme;
  final String notificationBadge;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF111C2E) : const Color(0xFF111C2E);

    final unreadChats = context.watch<ChatProvider>().totalUnreadCount;
    final auth = context.watch<AuthProvider>();
    final chatBadge = unreadChats > 0
        ? (unreadChats > 99 ? '99+' : unreadChats.toString())
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? 240 : 80,
      color: bgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inverter like new',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Internal Management',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (isExpanded) const _CategoryLabel('MENU CH\u00CDNH'),
                if (auth.can(AppPermission.viewDashboard))
                  _SideNavItem(
                    icon: LucideIcons.layoutDashboard,
                    label: 'Dashboard',
                    isSelected: currentIndex == 0,
                    onTap: () => onIndexChanged(0),
                    isExpanded: isExpanded,
                  ),
                if (auth.can(AppPermission.viewRepairOrders))
                  _SideNavItem(
                    icon: LucideIcons.wrench,
                    label: '\u0110\u01A1n s\u1EEDa ch\u1EEFa',
                    isSelected: currentIndex == 1,
                    onTap: () => onIndexChanged(1),
                    isExpanded: isExpanded,
                  ),
                if (auth.can(AppPermission.viewWarehouse))
                  _SideNavItem(
                    icon: LucideIcons.cpu,
                    label: 'Kho bo m\u1EA1ch',
                    isSelected: currentIndex == 2,
                    onTap: () => onIndexChanged(2),
                    isExpanded: isExpanded,
                  ),
                if (auth.can(AppPermission.useMessages))
                  _SideNavItem(
                    icon: LucideIcons.messageSquare,
                    label: 'Tin nh\u1EAFn',
                    isSelected: currentIndex == 4,
                    onTap: () => onIndexChanged(4),
                    isExpanded: isExpanded,
                    badge: chatBadge,
                  ),
                if (auth.can(AppPermission.viewNotifications))
                  _SideNavItem(
                    icon: LucideIcons.bell,
                    label: 'Th\u00F4ng b\u00E1o',
                    isSelected: currentIndex == 5,
                    onTap: () => onIndexChanged(5),
                    isExpanded: isExpanded,
                    badge: notificationBadge,
                  ),
                const SizedBox(height: 16),
                if (isExpanded &&
                    auth.canAny({
                      AppPermission.manageEmployees,
                      AppPermission.approveAccounts,
                    }))
                  const _CategoryLabel('QU\u1EA2N L\u00DD'),
                if (auth.canAny({
                  AppPermission.manageEmployees,
                  AppPermission.approveAccounts,
                }))
                  _SideNavItem(
                    icon: LucideIcons.users,
                    label: 'Qu\u1EA3n l\u00FD nh\u00E2n vi\u00EAn',
                    isSelected: currentIndex == 6,
                    onTap: () => onIndexChanged(6),
                    isExpanded: isExpanded,
                  ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                const SizedBox(height: 12),
                if (auth.can(AppPermission.viewProfile))
                  _SideNavItem(
                    icon: LucideIcons.user,
                    label: 'C\u00E1 nh\u00E2n',
                    isSelected: currentIndex == 8,
                    onTap: () => onIndexChanged(8),
                    isExpanded: isExpanded,
                  ),
                _SideNavItem(
                  icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                  label: isDark
                      ? 'Ch\u1EBF \u0111\u1ED9 s\u00E1ng'
                      : 'Ch\u1EBF \u0111\u1ED9 t\u1ED1i',
                  isSelected: false,
                  onTap: onToggleTheme,
                  isExpanded: isExpanded,
                ),
                _SideNavItem(
                  icon: LucideIcons.logOut,
                  label: '\u0110\u0103ng xu\u1EA5t',
                  isSelected: false,
                  onTap: onLogout,
                  isExpanded: isExpanded,
                ),
                const SizedBox(height: 12),
                _UserProfile(isExpanded: isExpanded),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onToggleExpand,
                  icon: Icon(
                    isExpanded
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    size: 16,
                    color: Colors.white54,
                  ),
                  label: isExpanded
                      ? const Text(
                          'Thu g\u1ECDn',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isExpanded,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isExpanded;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = Colors.white.withValues(alpha: 0.6);
    final visibleBadge = badge != null && badge != '0';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : inactiveColor,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : inactiveColor,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (visibleBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

class _UserProfile extends StatelessWidget {
  const _UserProfile({required this.isExpanded});

  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    final name = currentUser?.name ?? 'Ng\u01B0\u1EDDi d\u00F9ng';
    final role = currentUser == null
        ? ''
        : '${currentUser.roleLabel} - ${currentUser.employeeId.isEmpty ? currentUser.username : currentUser.employeeId}';
    final initials = _initials(name);

    if (!isExpanded) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary,
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFD946EF),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'ND';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }
}

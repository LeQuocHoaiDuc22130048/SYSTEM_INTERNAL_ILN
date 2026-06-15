import 'package:flutter/material.dart';

import '../models/app_permission.dart';
import '../utils/auth_provider.dart';
import 'main_tabs.dart';
import 'navigation_item.dart';

List<NavigationItem> buildMainNavigationItems(AuthProvider auth) {
  if (auth.isAttendanceAccount) {
    return const [
      NavigationItem(
        icon: Icons.access_time_outlined,
        label: 'Ch\u1EA5m c\u00F4ng',
        activeIcon: Icons.access_time,
        tabIndex: MainTabs.attendance,
      ),
    ];
  }

  return [
    if (auth.can(AppPermission.viewDashboard))
      const NavigationItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        activeIcon: Icons.dashboard,
        tabIndex: MainTabs.dashboard,
      ),
    if (auth.can(AppPermission.viewRepairOrders))
      const NavigationItem(
        icon: Icons.build_outlined,
        label: '\u0110\u01A1n',
        activeIcon: Icons.build,
        tabIndex: MainTabs.repairOrders,
      ),
    if (auth.can(AppPermission.viewWarehouse))
      const NavigationItem(
        icon: Icons.inventory_2_outlined,
        label: 'Kho',
        activeIcon: Icons.inventory_2,
        tabIndex: MainTabs.warehouse,
      ),
    if (auth.can(AppPermission.useMessages))
      const NavigationItem(
        icon: Icons.chat_bubble_outline,
        label: 'Tin nh\u1EAFn',
        activeIcon: Icons.chat_bubble,
        tabIndex: MainTabs.messages,
      ),
    if (auth.canAny({
      AppPermission.manageEmployees,
      AppPermission.approveAccounts,
    }))
      const NavigationItem(
        icon: Icons.people_outline,
        label: 'Qu\u1EA3n l\u00FD NV',
        activeIcon: Icons.people,
        tabIndex: MainTabs.employeeManagement,
      ),
    if (auth.can(AppPermission.viewProfile))
      const NavigationItem(
        icon: Icons.person_outline,
        label: 'C\u00E1 nh\u00E2n',
        activeIcon: Icons.person,
        tabIndex: MainTabs.profile,
      ),
  ];
}

bool canAccessMainTab(AuthProvider auth, int tabIndex) {
  if (auth.isAttendanceAccount) {
    return tabIndex == MainTabs.attendance;
  }

  switch (tabIndex) {
    case MainTabs.dashboard:
      return auth.can(AppPermission.viewDashboard);
    case MainTabs.repairOrders:
      return auth.can(AppPermission.viewRepairOrders);
    case MainTabs.warehouse:
      return auth.can(AppPermission.viewWarehouse);
    case MainTabs.attendance:
      return auth.can(AppPermission.viewAttendance);
    case MainTabs.messages:
      return auth.can(AppPermission.useMessages);
    case MainTabs.notifications:
      return auth.can(AppPermission.viewNotifications);
    case MainTabs.employeeManagement:
    case MainTabs.accountApproval:
      return auth.canAny({
        AppPermission.manageEmployees,
        AppPermission.approveAccounts,
      });
    case MainTabs.profile:
      return auth.can(AppPermission.viewProfile);
    default:
      return false;
  }
}

int firstAllowedMainTab(AuthProvider auth) {
  final items = buildMainNavigationItems(auth);
  return items.isEmpty ? MainTabs.profile : items.first.tabIndex;
}

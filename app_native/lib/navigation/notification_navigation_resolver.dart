import '../models/app_notification.dart';
import '../utils/auth_provider.dart';
import 'main_tabs.dart';
import 'navigation_config.dart';

class NotificationNavigationTarget {
  const NotificationNavigationTarget({
    required this.tabIndex,
    this.refId,
    this.subTabIndex,
  });

  final int tabIndex;
  final String? refId;
  final int? subTabIndex;
}

NotificationNavigationTarget? resolveNotificationNavigation(
  AppNotification item, {
  required AuthProvider auth,
}) {
  if (auth.isAttendanceAccount) return null;

  final type = item.type;
  final refType = item.refType;
  final refId = item.refId;

  if (type == 'NEW_MESSAGE' || refType == 'CONVERSATION') {
    final target = NotificationNavigationTarget(
      tabIndex: MainTabs.messages,
      refId: refId,
    );
    return canAccessMainTab(auth, target.tabIndex) ? target : null;
  }

  if (type.startsWith('ORDER_') ||
      type.startsWith('NEW_REPAIR_') ||
      refType == 'REPAIR_ORDER') {
    final target = NotificationNavigationTarget(
      tabIndex: MainTabs.repairOrders,
      refId: refId,
    );
    return canAccessMainTab(auth, target.tabIndex) ? target : null;
  }

  if (type.startsWith('ACCOUNT_') || refType == 'USER') {
    const target = NotificationNavigationTarget(
      tabIndex: MainTabs.employeeManagement,
      subTabIndex: 1,
    );
    return canAccessMainTab(auth, target.tabIndex) ? target : null;
  }

  return null;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_routes.dart';
import '../models/app_permission.dart';
import '../navigation/main_tabs.dart';
import '../screens/repair_orders_page.dart';
import '../utils/auth_provider.dart';
import 'home_attendance.dart';

enum QuickAction {
  createRepair,
  repairOrders,
  warehouse,
  messages,
  attendance,
  employees,
  notifications,
  profile,
}

bool canUseQuickAction(AuthProvider auth, QuickAction action) {
  if (!auth.isAuthenticated || auth.isAttendanceAccount) return false;
  return switch (action) {
    QuickAction.createRepair =>
      auth.can(AppPermission.viewRepairOrders) &&
          auth.can(AppPermission.manageRepairOrders),
    QuickAction.repairOrders => auth.can(AppPermission.viewRepairOrders),
    QuickAction.warehouse => auth.can(AppPermission.viewWarehouse),
    QuickAction.messages => auth.can(AppPermission.useMessages),
    QuickAction.attendance => auth.can(AppPermission.viewAttendance),
    QuickAction.employees => auth.canAny({
      AppPermission.manageEmployees,
      AppPermission.approveAccounts,
    }),
    QuickAction.notifications => auth.can(AppPermission.viewNotifications),
    QuickAction.profile => auth.can(AppPermission.viewProfile),
  };
}

Future<void> showAppQuickActions(
  BuildContext context, {
  ValueChanged<int>? onNavigateToTab,
}) async {
  final action = await showModalBottomSheet<QuickAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _QuickActionsSheet(),
  );
  if (!context.mounted ||
      action == null ||
      !canUseQuickAction(context.read<AuthProvider>(), action)) {
    return;
  }
  if (action == QuickAction.createRepair) {
    await showCreateRepairOrderSheet(context);
    return;
  }
  if (action == QuickAction.attendance) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: const HomeAttendance(),
          ),
        ),
      ),
    );
    return;
  }
  final tab = switch (action) {
    QuickAction.repairOrders => MainTabs.repairOrders,
    QuickAction.warehouse => MainTabs.warehouse,
    QuickAction.messages => MainTabs.messages,
    QuickAction.employees => MainTabs.employeeManagement,
    QuickAction.notifications => MainTabs.notifications,
    QuickAction.profile => MainTabs.profile,
    _ => MainTabs.home,
  };
  if (onNavigateToTab != null) {
    onNavigateToTab(tab);
  } else {
    Navigator.of(context).pushNamed(AppRoutes.dashboard, arguments: tab);
  }
}

class _QuickActionsSheet extends StatelessWidget {
  const _QuickActionsSheet();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    const labels = {
      QuickAction.createRepair: 'Tạo đơn sửa chữa',
      QuickAction.repairOrders: 'Đơn sửa chữa',
      QuickAction.warehouse: 'Kho linh kiện',
      QuickAction.messages: 'Nhắn tin',
      QuickAction.attendance: 'Chấm công hôm nay',
      QuickAction.employees: 'Quản lý nhân viên',
      QuickAction.notifications: 'Thông báo',
      QuickAction.profile: 'Cá nhân',
    };
    const icons = {
      QuickAction.createRepair: Icons.add_circle_outline,
      QuickAction.repairOrders: Icons.build_outlined,
      QuickAction.warehouse: Icons.inventory_2_outlined,
      QuickAction.messages: Icons.chat_bubble_outline,
      QuickAction.attendance: Icons.access_time,
      QuickAction.employees: Icons.people_outline,
      QuickAction.notifications: Icons.notifications_outlined,
      QuickAction.profile: Icons.person_outline,
    };
    final actions = QuickAction.values
        .where((action) => canUseQuickAction(auth, action))
        .toList();
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thao tác nhanh',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng thao tác nhanh',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (actions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tài khoản chưa có thao tác nhanh khả dụng.'),
                ),
              for (final action in actions)
                ListTile(
                  leading: Icon(
                    icons[action],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(labels[action]!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

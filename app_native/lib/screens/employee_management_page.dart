import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/auth_provider.dart';
import '../models/app_permission.dart';
import '../theme/app_colors.dart';
import 'employees_page.dart';
import 'account_approval_page.dart';

class EmployeeManagementPage extends StatelessWidget {
  final int initialTabIndex;
  const EmployeeManagementPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final showEmployees = auth.can(AppPermission.viewEmployees);
    final showApproval = auth.can(AppPermission.approveAccounts);
    final tabs = <Tab>[
      if (showEmployees) const Tab(text: 'Nhân viên'),
      if (showApproval) const Tab(text: 'Duyệt tài khoản'),
    ];
    if (tabs.isEmpty) {
      return const Center(
        child: Text('Bạn chưa được cấp quyền sử dụng chức năng này.'),
      );
    }

    return DefaultTabController(
      key: ValueKey('$showEmployees-$showApproval'),
      length: tabs.length,
      initialIndex: initialTabIndex == 1 && showEmployees && showApproval
          ? 1
          : 0,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 0,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            bottom: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              indicatorColor: AppColors.primary,
              tabs: tabs,
            ),
          ),
        ),
        body: TabBarView(
          physics:
              NeverScrollableScrollPhysics(), // Prevent horizontal swipe issues
          children: [
            if (showEmployees) const EmployeesPage(),
            if (showApproval) const AccountApprovalPage(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import 'employees_page.dart';
import 'account_approval_page.dart';

class EmployeeManagementPage extends StatelessWidget {
  final int initialTabIndex;
  const EmployeeManagementPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final canManageEmployees = auth.can(AppPermission.manageEmployees);
    final canApproveAccounts = auth.can(AppPermission.approveAccounts);

    final tabs = <Widget>[
      if (canManageEmployees) const Tab(text: 'Nhân viên'),
      if (canApproveAccounts) const Tab(text: 'Duyệt tài khoản'),
    ];

    final views = <Widget>[
      if (canManageEmployees) const EmployeesPage(),
      if (canApproveAccounts) const AccountApprovalPage(),
    ];

    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Bạn không có quyền truy cập chức năng này')),
      );
    }

    if (tabs.length == 1) {
      return Scaffold(body: views.first);
    }

    final initialIndex = initialTabIndex.clamp(0, tabs.length - 1);

    return DefaultTabController(
      length: tabs.length,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppBar(
            automaticallyImplyLeading: false,
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
          physics: const NeverScrollableScrollPhysics(),
          children: views,
        ),
      ),
    );
  }
}

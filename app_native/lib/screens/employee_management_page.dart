import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'employees_page.dart';
import 'account_approval_page.dart';

class EmployeeManagementPage extends StatelessWidget {
  final int initialTabIndex;
  const EmployeeManagementPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
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
              tabs: const [
                Tab(text: 'Nhân viên'),
                Tab(text: 'Duyệt tài khoản'),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(), // Prevent horizontal swipe issues
          children: [
            EmployeesPage(),
            AccountApprovalPage(),
          ],
        ),
      ),
    );
  }
}

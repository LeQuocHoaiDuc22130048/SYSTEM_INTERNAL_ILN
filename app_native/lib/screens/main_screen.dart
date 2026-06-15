import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_routes.dart';
import '../app/theme_provider.dart';
import '../models/app_notification.dart';
import '../navigation/main_tabs.dart';
import '../navigation/navigation_config.dart';
import '../navigation/navigation_item.dart';
import '../navigation/notification_navigation_resolver.dart';
import '../utils/auth_provider.dart';
import '../utils/chat_provider.dart';
import '../utils/notification_provider.dart';
import '../widgets/navigation/mobile_dashboard_app_bar.dart';
import '../widgets/navigation/mobile_navigation_bar.dart';
import '../widgets/navigation/side_navigation.dart';
import 'attendance_only_page.dart';
import 'attendance_screen.dart';
import 'dashboard_page.dart';
import 'employee_management_page.dart';
import 'messages_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'repair_orders_page.dart';
import 'warehouse_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = MainTabs.dashboard;
  int _previousIndex = MainTabs.dashboard;
  bool _isSidebarExpanded = true;
  String? _targetRepairOrderId;
  int _targetEmployeeManagementTabIndex = 0;

  late final List<Widget?> _pages;
  StreamSubscription<AppNotification>? _notificationSub;
  bool _navigatingToLogin = false;

  List<NavigationItem> get _navItems {
    return buildMainNavigationItems(context.watch<AuthProvider>());
  }

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _currentIndex = firstAllowedMainTab(auth);
    _previousIndex = _currentIndex;
    _pages = List<Widget?>.filled(MainTabs.count, null);
    _pages[_currentIndex] = _buildPage(_currentIndex);
    _bindNotificationClicks();
  }

  void _bindNotificationClicks() {
    final notificationProvider = context.read<NotificationProvider>();
    if (notificationProvider.pendingNotificationClick != null) {
      final pending = notificationProvider.pendingNotificationClick!;
      notificationProvider.pendingNotificationClick = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationClick(pending);
      });
    }

    _notificationSub = notificationProvider.notificationClickStream.listen(
      _handleNotificationClick,
    );
  }

  void _handleNotificationClick(AppNotification item) {
    final auth = context.read<AuthProvider>();
    final target = resolveNotificationNavigation(item, auth: auth);
    if (target == null) return;

    _setCurrentIndex(
      target.tabIndex,
      refId: target.refId,
      subTabIndex: target.subTabIndex,
    );

    if (target.tabIndex == MainTabs.messages &&
        target.refId != null &&
        target.refId!.isNotEmpty) {
      context.read<ChatProvider>().selectConversationById(target.refId!);
    }
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    super.dispose();
  }

  Widget _buildPage(int index) {
    switch (index) {
      case MainTabs.dashboard:
        return const DashboardPage();
      case MainTabs.repairOrders:
        return RepairOrdersPage(targetOrderId: _targetRepairOrderId);
      case MainTabs.warehouse:
        return const WarehousePage();
      case MainTabs.attendance:
        return context.read<AuthProvider>().isAttendanceAccount
            ? _buildAttendanceOnlyScaffold()
            : const DashboardPage();
      case MainTabs.messages:
        return const MessagesPage();
      case MainTabs.notifications:
        return NotificationsPage(
          onNavigateToTab: (tabIndex, {String? refId, int? subTab}) {
            _setCurrentIndex(tabIndex, refId: refId, subTabIndex: subTab);
            if (tabIndex == MainTabs.messages && refId != null) {
              context.read<ChatProvider>().selectConversationById(refId);
            }
          },
        );
      case MainTabs.employeeManagement:
        return EmployeeManagementPage(
          initialTabIndex: _targetEmployeeManagementTabIndex,
        );
      case MainTabs.accountApproval:
        return const SizedBox.shrink();
      case MainTabs.profile:
        return const ProfilePage();
      default:
        return const DashboardPage();
    }
  }

  void _setCurrentIndex(int index, {String? refId, int? subTabIndex}) {
    final auth = context.read<AuthProvider>();
    if (auth.isAttendanceAccount && index != MainTabs.attendance) {
      index = MainTabs.attendance;
      refId = null;
      subTabIndex = null;
    }
    if (!auth.isAttendanceAccount && index == MainTabs.attendance) {
      index = MainTabs.dashboard;
      refId = null;
      subTabIndex = null;
    }
    if (!canAccessMainTab(auth, index)) {
      index = firstAllowedMainTab(auth);
      refId = null;
      subTabIndex = null;
    }

    setState(() {
      if (index == MainTabs.repairOrders) {
        _targetRepairOrderId = refId;
        _pages[MainTabs.repairOrders] = RepairOrdersPage(targetOrderId: refId);
      } else if (index == MainTabs.employeeManagement) {
        _targetEmployeeManagementTabIndex = subTabIndex ?? 0;
        _pages[MainTabs.employeeManagement] = EmployeeManagementPage(
          initialTabIndex: subTabIndex ?? 0,
        );
      }
      _pages[index] ??= _buildPage(index);
      _currentIndex = index;
    });
  }

  List<Widget> get _visiblePages {
    return List<Widget>.generate(
      _pages.length,
      (index) => _pages[index] ?? const SizedBox.shrink(),
    );
  }

  void _returnToLogin({String? warning}) {
    if (_navigatingToLogin || !mounted) return;
    _navigatingToLogin = true;
    if (warning != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(warning)));
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await context.read<NotificationProvider>().prepareForLogout();
    await auth.logout();
    _returnToLogin(warning: auth.logoutWarning);
  }

  Widget _buildAttendanceOnlyScaffold() {
    return AttendanceOnlyPage(
      onLogout: _logout,
      onStartScan: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AttendanceScreen(
              allowEnrollment: false,
              selfCheckOnly: true,
              refreshAttendanceAfterVerification: false,
              showMatchedEmployeeInfo: false,
              popOnVerificationSuccess: true,
            ),
          ),
        );
      },
    );
  }

  Widget _withProfileNotice(Widget child, AuthProvider auth) {
    if (auth.profileError == null) return child;
    return Column(
      children: [
        MaterialBanner(
          content: const Text(
            'Kh\u00F4ng th\u1EC3 \u0111\u1ED3ng b\u1ED9 h\u1ED3 s\u01A1 m\u1EDBi nh\u1EA5t. Th\u00F4ng tin \u0111ang hi\u1EC3n th\u1ECB c\u00F3 th\u1EC3 \u0111\u00E3 c\u0169.',
          ),
          actions: [
            TextButton(
              onPressed: auth.isLoadingProfile ? null : auth.loadMe,
              child: Text(
                auth.isLoadingProfile
                    ? '\u0110ANG T\u1EA2I...'
                    : 'TH\u1EEC L\u1EA0I',
              ),
            ),
          ],
        ),
        Expanded(child: child),
      ],
    );
  }

  void _toggleNotifications() {
    if (_currentIndex == MainTabs.notifications) {
      _setCurrentIndex(_previousIndex);
    } else {
      _previousIndex = _currentIndex;
      _setCurrentIndex(MainTabs.notifications);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated && !_navigatingToLogin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _returnToLogin());
    }
    if (auth.isAuthenticated && !canAccessMainTab(auth, _currentIndex)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _setCurrentIndex(firstAllowedMainTab(auth));
        }
      });
    }

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final unreadNotifications = context
        .watch<NotificationProvider>()
        .unreadCount;
    final notificationBadge = unreadNotifications > 99
        ? '99+'
        : unreadNotifications.toString();

    if (auth.isAttendanceAccount) {
      return _buildAttendanceOnlyScaffold();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final body = _withProfileNotice(
          IndexedStack(index: _currentIndex, children: _visiblePages),
          auth,
        );

        if (isWide) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Row(
              children: [
                SideNavigation(
                  currentIndex: _currentIndex,
                  isDark: isDark,
                  isExpanded: _isSidebarExpanded,
                  onIndexChanged: _setCurrentIndex,
                  onToggleExpand: () =>
                      setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                  onToggleTheme: themeProvider.toggleTheme,
                  notificationBadge: notificationBadge,
                  onLogout: _logout,
                ),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: DashboardMobileAppBar(
            isDark: isDark,
            notificationBadge: notificationBadge,
            onLogout: _logout,
            onToggleTheme: themeProvider.toggleTheme,
            onToggleNotifications: _toggleNotifications,
          ),
          body: body,
          bottomNavigationBar: MobileNavigationBar(
            items: _navItems,
            currentIndex: _currentIndex,
            isDark: isDark,
            onIndexChanged: _setCurrentIndex,
          ),
        );
      },
    );
  }
}

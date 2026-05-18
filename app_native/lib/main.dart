import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'screens/account_approval_page.dart';
import 'screens/attendance_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/employees_page.dart';
import 'screens/login_page.dart';
import 'screens/messages_page.dart';
import 'screens/notifications_page.dart';
import 'screens/repair_orders_page.dart';
import 'screens/warehouse_page.dart';
import 'screens/profile_page.dart';
import 'screens/employee_management_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'utils/auth_provider.dart';
import 'utils/network_provider.dart';
import 'utils/pending_sync_provider.dart';
import 'widgets/offline_banner.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProxyProvider<NetworkProvider, PendingSyncProvider>(
          create: (_) => PendingSyncProvider(),
          update: (_, network, pendingSync) {
            final provider = pendingSync ?? PendingSyncProvider();
            provider.bindNetwork(network);
            return provider;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Inverter like new',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const LoginPage(),
          builder: (context, child) {
            return OfflineBanner(child: child ?? const SizedBox.shrink());
          },
          routes: {
            '/login': (context) => const LoginPage(),
            '/dashboard': (context) => const MainScreen(),
          },
        );
      },
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isSidebarExpanded = true;

  late final List<Widget?> _pages;

  List<NavigationItem> get _navItems {
    final isEmployee = Provider.of<AuthProvider>(context).isEmployee;
    return [
      NavigationItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        activeIcon: Icons.dashboard,
        tabIndex: 0,
      ),
      NavigationItem(
        icon: Icons.build_outlined,
        label: 'Đơn',
        activeIcon: Icons.build,
        tabIndex: 1,
      ),
      NavigationItem(
        icon: Icons.inventory_2_outlined,
        label: 'Kho',
        activeIcon: Icons.inventory_2,
        tabIndex: 2,
      ),
      if (!isEmployee)
        NavigationItem(
          icon: Icons.access_time_outlined,
          label: 'Chấm công',
          activeIcon: Icons.access_time,
          tabIndex: 3,
        ),
      NavigationItem(
        icon: Icons.chat_bubble_outline,
        label: 'Tin nhắn',
        activeIcon: Icons.chat_bubble,
        tabIndex: 4,
      ),
      if (!isEmployee)
        NavigationItem(
          icon: Icons.people_outline,
          label: 'Quản lý NV',
          activeIcon: Icons.people,
          tabIndex: 6,
        ),
      NavigationItem(
        icon: Icons.person_outline,
        label: 'Cá nhân',
        activeIcon: Icons.person,
        tabIndex: 8,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(9, null);
    _pages[_currentIndex] = _buildPage(_currentIndex);
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const RepairOrdersPage();
      case 2:
        return const WarehousePage();
      case 3:
        return const AttendancePage();
      case 4:
        return const MessagesPage();
      case 5:
        return const NotificationsPage();
      case 6:
        return const EmployeeManagementPage();
      case 7:
        return const SizedBox.shrink(); // AccountApproval is inside EmployeeManagementPage now
      case 8:
        return const ProfilePage();
      default:
        return const DashboardPage();
    }
  }

  void _setCurrentIndex(int index) {
    setState(() {
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Row(
              children: [
                _SideNavigation(
                  currentIndex: _currentIndex,
                  isDark: isDark,
                  isExpanded: _isSidebarExpanded,
                  onIndexChanged: _setCurrentIndex,
                  onToggleExpand: () =>
                      setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                  themeProvider: themeProvider,
                  isEmployee: Provider.of<AuthProvider>(context).isEmployee,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _visiblePages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            toolbarHeight: 56,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.logout, size: 22),
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              tooltip: 'Đăng xuất',
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Image.asset("assets/images/app_logo.png"),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 22),
                onPressed: themeProvider.toggleTheme,
                tooltip: 'Giao diện',
              ),
              _BadgeIconButton(
                icon: Icons.notifications_outlined,
                badge: '3',
                tooltip: 'Thông báo',
                onPressed: () {
                  if (_currentIndex == 5) {
                    _setCurrentIndex(_previousIndex);
                  } else {
                    _previousIndex = _currentIndex;
                    _setCurrentIndex(5);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          body: IndexedStack(index: _currentIndex, children: _visiblePages),
          bottomNavigationBar: Container(
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
                  children: List.generate(_navItems.length, (index) {
                    final item = _navItems[index];
                    final isSelected = _currentIndex == item.tabIndex;
                    final color = isSelected
                        ? Theme.of(context).primaryColor
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight);

                    return Expanded(
                      child: InkWell(
                        onTap: () => _setCurrentIndex(item.tabIndex),
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
                            if (item.tabIndex == 4)
                              Positioned(
                                top: 10,
                                right: 22,
                                child: _BadgePill(text: '4', size: 14),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectFromDrawer(BuildContext context, int index) {
    _setCurrentIndex(index);
    Navigator.pop(context);
  }
}

class _SideNavigation extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final bool isExpanded;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onToggleExpand;
  final ThemeProvider themeProvider;
  final bool isEmployee;

  const _SideNavigation({
    required this.currentIndex,
    required this.isDark,
    required this.isExpanded,
    required this.onIndexChanged,
    required this.onToggleExpand,
    required this.themeProvider,
    required this.isEmployee,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xFF111C2E)
        : const Color(0xFF111C2E); // Dark blue like in image

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? 240 : 80,
      color: bgColor,
      child: Column(
        children: [
          // Logo
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
                if (isExpanded) _CategoryLabel('MENU CHÍNH'),
                _SideNavItem(
                  icon: LucideIcons.layoutDashboard,
                  label: 'Dashboard',
                  isSelected: currentIndex == 0,
                  onTap: () => onIndexChanged(0),
                  isExpanded: isExpanded,
                ),
                _SideNavItem(
                  icon: LucideIcons.wrench,
                  label: 'Đơn sửa chữa',
                  isSelected: currentIndex == 1,
                  onTap: () => onIndexChanged(1),
                  isExpanded: isExpanded,
                ),
                _SideNavItem(
                  icon: LucideIcons.cpu,
                  label: 'Kho bo mạch',
                  isSelected: currentIndex == 2,
                  onTap: () => onIndexChanged(2),
                  isExpanded: isExpanded,
                ),
                if (!isEmployee)
                  _SideNavItem(
                    icon: LucideIcons.clock,
                    label: 'Chấm công',
                    isSelected: currentIndex == 3,
                    onTap: () => onIndexChanged(3),
                    isExpanded: isExpanded,
                  ),
                _SideNavItem(
                  icon: LucideIcons.messageSquare,
                  label: 'Tin nhắn',
                  isSelected: currentIndex == 4,
                  onTap: () => onIndexChanged(4),
                  isExpanded: isExpanded,
                  badge: '4',
                ),
                _SideNavItem(
                  icon: LucideIcons.bell,
                  label: 'Thông báo',
                  isSelected: currentIndex == 5,
                  onTap: () => onIndexChanged(5),
                  isExpanded: isExpanded,
                  badge: '3',
                ),
                const SizedBox(height: 16),
                if (isExpanded && !isEmployee) _CategoryLabel('QUẢN LÝ'),
                if (!isEmployee)
                  _SideNavItem(
                    icon: LucideIcons.users,
                    label: 'Quản lý nhân viên',
                    isSelected: currentIndex == 6,
                    onTap: () => onIndexChanged(6),
                    isExpanded: isExpanded,
                  ),                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // Footer items moved inside scrollable list
                const SizedBox(height: 12),
                _SideNavItem(
                  icon: LucideIcons.user,
                  label: 'Cá nhân',
                  isSelected: currentIndex == 8,
                  onTap: () => onIndexChanged(8),
                  isExpanded: isExpanded,
                ),
                _SideNavItem(
                  icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                  label: isDark ? 'Chế độ sáng' : 'Chế độ tối',
                  isSelected: false,
                  onTap: themeProvider.toggleTheme,
                  isExpanded: isExpanded,
                ),
                _SideNavItem(
                  icon: LucideIcons.logOut,
                  label: 'Đăng xuất',
                  isSelected: false,
                  onTap: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
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
                          'Thu gọn',
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
  final String label;
  const _CategoryLabel(this.label);

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
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isExpanded;
  final String? badge;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isExpanded,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = Colors.white.withValues(alpha: 0.6);

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
                if (badge != null)
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
  final bool isExpanded;
  const _UserProfile({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    if (!isExpanded) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary,
        child: Text(
          'NM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFD946EF),
          child: Text(
            'NM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nguyễn Văn Minh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Super Admin - NV-2024-001',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerDestination extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    );
  }
}

class _BadgeIconButton extends StatelessWidget {
  final IconData icon;
  final String badge;
  final String tooltip;
  final VoidCallback onPressed;

  const _BadgeIconButton({
    required this.icon,
    required this.badge,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, size: 21),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
        Positioned(
          right: 10,
          top: 10,
          child: _BadgePill(text: badge, size: 16),
        ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String text;
  final double size;

  const _BadgePill({required this.text, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size <= 14 ? 8 : 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int tabIndex;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.tabIndex,
  });
}

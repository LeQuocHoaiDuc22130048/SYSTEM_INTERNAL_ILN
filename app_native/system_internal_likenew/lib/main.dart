import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/attendance_page.dart';
import 'screens/dashboard_page.dart';
import 'screens/employees_page.dart';
import 'screens/login_page.dart';
import 'screens/notifications_page.dart';
import 'screens/repair_orders_page.dart';
import 'screens/warehouse_page.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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
          title: 'TechFix IMS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const LoginPage(),
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

  final List<Widget> _pages = [
    const DashboardPage(),
    const RepairOrdersPage(),
    const WarehousePage(),
    const AttendancePage(),
    const MessagesPage(),
    const NotificationsPage(),
    const EmployeesPage(),
  ];

  final List<NavigationItem> _navItems = [
    NavigationItem(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      activeIcon: Icons.dashboard,
    ),
    NavigationItem(
      icon: Icons.build_outlined,
      label: 'Đơn',
      activeIcon: Icons.build,
    ),
    NavigationItem(
      icon: Icons.inventory_2_outlined,
      label: 'Kho',
      activeIcon: Icons.inventory_2,
    ),
    NavigationItem(
      icon: Icons.access_time_outlined,
      label: 'Chấm công',
      activeIcon: Icons.access_time,
    ),
    NavigationItem(
      icon: Icons.chat_bubble_outline,
      label: 'Tin nhắn',
      activeIcon: Icons.chat_bubble,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu, size: 22),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            );
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text(
                  'IMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TechFix IMS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        actions: [
          _BadgeIconButton(
            icon: Icons.notifications_outlined,
            badge: '3',
            tooltip: 'Thông báo',
            onPressed: () {},
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'IMS',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'TechFix IMS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            _DrawerDestination(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              selected: _currentIndex == 0,
              onTap: () => _selectFromDrawer(context, 0),
            ),
            _DrawerDestination(
              icon: Icons.build_outlined,
              label: 'Đơn sửa chữa',
              selected: _currentIndex == 1,
              onTap: () => _selectFromDrawer(context, 1),
            ),
            _DrawerDestination(
              icon: Icons.inventory_2_outlined,
              label: 'Kho bo mạch',
              selected: _currentIndex == 2,
              onTap: () => _selectFromDrawer(context, 2),
            ),
            _DrawerDestination(
              icon: Icons.access_time_outlined,
              label: 'Chấm công',
              selected: _currentIndex == 3,
              onTap: () => _selectFromDrawer(context, 3),
            ),
            _DrawerDestination(
              icon: Icons.chat_bubble_outline,
              label: 'Tin nhắn',
              selected: _currentIndex == 4,
              onTap: () => _selectFromDrawer(context, 4),
            ),
            const Divider(),
            ListTile(
              leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              title: Text(isDark ? 'Chế độ sáng' : 'Chế độ tối'),
              onTap: themeProvider.toggleTheme,
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cài đặt'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Đăng xuất'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
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
                final isSelected = _currentIndex == index;
                final color = isSelected
                    ? Theme.of(context).primaryColor
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight);

                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
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
                        if (index == 4)
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
  }

  void _selectFromDrawer(BuildContext context, int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context);
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

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

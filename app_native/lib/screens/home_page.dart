import '../widgets/app_quick_actions.dart';
import '../widgets/home_attendance.dart';
import '../widgets/field_work_requests.dart';
import '../widgets/field_work_bottom_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_routes.dart';
import '../navigation/main_tabs.dart';
import '../navigation/navigation_config.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/chat_provider.dart';
import '../utils/notification_provider.dart';
import '../models/app_permission.dart';
import '../models/app_banner.dart';
import '../widgets/navigation/mobile_navigation_bar.dart';
import '../widgets/quick_booking_sheet.dart';
import '../widgets/app_banner_carousel.dart';
import '../widgets/interactive_bounce.dart';
import '../widgets/directional_slide_switcher.dart';
import '../widgets/navigation/mobile_dashboard_app_bar.dart';
import '../app/theme_provider.dart';
import '../theme/app_colors.dart';
import 'profile_page.dart';

/// Home Screen designed faithfully from Stitch (Home Screen - Home Service Marketplace)
/// Features:
/// - Sticky TopBar with account profile avatar, name, role badge, notification indicator
/// - User Greeting ("Hello, [Name] 👋")
/// - Promotional Banner featuring the 3D Character (`assets/images/image_character.png`)
/// - Service Categories Grid (Chức năng: Dashboard, Đơn, Kho, Nhắn tin, Quản lý nhân viên)
/// - Top Rated Experts list with verified badges, ratings, and booking action
/// - Optional 3-Tab Bottom Navigation Bar matching Stitch
class HomePage extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final bool showBottomNav;
  final bool embedded;
  final int initialNavTab;

  const HomePage({
    super.key,
    this.onNavigateToTab,
    this.showBottomNav = false,
    this.embedded = false,
    this.initialNavTab = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late int _currentNavTab; // 0: Home, 1: Book (+), 2: Profile
  bool _navigatingBack = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentNavTab = widget.initialNavTab;
    _navigatingBack = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final backend = context.read<BackendDataProvider>();
        if (!backend.isLoadingBanners) {
          unawaited(backend.loadBanners());
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final backend = context.read<BackendDataProvider>();
      if (!backend.isLoadingBanners) unawaited(backend.loadBanners());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<Map<String, dynamic>> get _categories => const [
    {
      'id': 'dashboard',
      'label': 'Dashboard',
      'tooltip': 'Dashboard - Bảng điều khiển',
      'tabIndex': MainTabs.dashboard,
      'icon': LucideIcons.layoutDashboard,
      'bgColor': Color(0xFFEFF6FF),
      'textColor': Color(0xFF2563EB),
      'borderColor': Color(0xFFBFDBFE),
    },
    {
      'id': 'repair_orders',
      'label': 'Đơn hàng',
      'tooltip': 'Đơn sửa chữa',
      'tabIndex': MainTabs.repairOrders,
      'icon': LucideIcons.wrench,
      'bgColor': Color(0xFFEFF6FF),
      'textColor': Color(0xFF2563EB),
      'borderColor': Color(0xFFBFDBFE),
    },
    {
      'id': 'warehouse',
      'label': 'Kho',
      'tooltip': 'Kho linh kiện',
      'tabIndex': MainTabs.warehouse,
      'icon': LucideIcons.boxes,
      'bgColor': Color(0xFFEFF6FF),
      'textColor': Color(0xFF2563EB),
      'borderColor': Color(0xFFBFDBFE),
    },
    {
      'id': 'messages',
      'label': 'Nhắn tin',
      'tooltip': 'Tin nhắn trao đổi',
      'tabIndex': MainTabs.messages,
      'icon': LucideIcons.messageSquare,
      'bgColor': Color(0xFFEEF2FF),
      'textColor': Color(0xFF4F46E5),
      'borderColor': Color(0xFFC7D2FE),
    },
    {
      'id': 'employee_management',
      'label': 'Nhân viên',
      'tooltip': 'Quản lý nhân viên & tài khoản',
      'tabIndex': MainTabs.employeeManagement,
      'icon': LucideIcons.users,
      'bgColor': Color(0xFFEEF2FF),
      'textColor': Color(0xFF4F46E5),
      'borderColor': Color(0xFFC7D2FE),
    },
    {
      'id': 'customers',
      'label': 'Khách hàng',
      'tooltip': 'Hồ sơ & danh bạ khách hàng',
      'tabIndex': MainTabs.customers,
      'icon': LucideIcons.contact,
      'bgColor': Color(0xFFEFF6FF),
      'textColor': Color(0xFF2563EB),
      'borderColor': Color(0xFFBFDBFE),
    },
    {
      'id': 'field_work',
      'label': 'Đi công trình',
      'tooltip': 'Báo cáo đi công trình',
      'icon': LucideIcons.briefcase,
      'bgColor': Color(0xFFFEF3C7),
      'textColor': Color(0xFFD97706),
      'borderColor': Color(0xFFFDE68A),
    },
  ];

  void _navigateToTab(int tabIndex) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.dashboard, arguments: tabIndex);
    }
  }

  void _switchToTab(int tabIndex, {bool? isBack}) {
    if (_currentNavTab == tabIndex) return;
    final bool goingBack = isBack ?? (tabIndex < _currentNavTab);
    setState(() {
      _navigatingBack = goingBack;
      _currentNavTab = tabIndex;
    });
  }

  void _goBackHome() {
    _switchToTab(0, isBack: true);
  }

  void _showBookingSheet({String? expertName, String? serviceName}) {
    showQuickBookingSheet(
      context,
      expertName: expertName,
      serviceName: serviceName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
      });
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final userName =
        auth.currentUser?.name ?? auth.currentUser?.username ?? 'Alex';
    final roleLabel = auth.currentUser?.roleLabel;

    final Widget middleContent;
    if (_currentNavTab == 2) {
      middleContent = KeyedSubtree(
        key: const ValueKey('profile_tab_view'),
        child: ProfilePage(
          hideTopBar: true,
          showBottomNav: false,
          onNavigateToHome: _goBackHome,
          onNavigateToTab: widget.onNavigateToTab,
        ),
      );
    } else {
      middleContent = KeyedSubtree(
        key: const ValueKey('home_tab_view'),
        child: RefreshIndicator(
          onRefresh: () async {
            if (!auth.isAttendanceAccount) {
              await context.read<BackendDataProvider>().loadAll(
                isManagerOrAbove: auth.isManagerOrAbove,
              );
            }
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Greeting Section
                _buildGreeting(userName, roleLabel, isDark),
                const SizedBox(height: 6),

                // Promotional Banner with 3D Character (assets/images/image_character.png)
                _buildPromotionalBanner(),
                const SizedBox(height: 12),

                // Service Categories Grid
                _buildServiceCategories(isDark),
                const SizedBox(height: 12),

                // Field Work Requests / Báo cáo công trình section
                const FieldWorkRequests(),
                const SizedBox(height: 12),

                // Today's Attendance
                const HomeAttendance(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.embedded) return middleContent;

    final badgeStr = unreadCount == 0
        ? ''
        : unreadCount > 99
        ? '99+'
        : '$unreadCount';

    return PopScope(
      canPop: _currentNavTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBackHome();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFF8FAFC),
        appBar: DashboardMobileAppBar(
          isDark: isDark,
          showBack: _currentNavTab != 0 || Navigator.canPop(context),
          notificationBadge: badgeStr,
          onToggleTheme: () => context.read<ThemeProvider>().toggleTheme(),
          onToggleNotifications: () => _navigateToTab(MainTabs.notifications),
          showNotification: false,
          onBack: _currentNavTab == 2
              ? _goBackHome
              : () => Navigator.of(context).maybePop(),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Middle Content (slides left when navigating forward, right when returning)
              Expanded(
                child: ClipRect(
                  child: DirectionalSlideSwitcher(
                    isForward: !_navigatingBack,
                    child: middleContent,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.showBottomNav
            ? MobileNavigationBar(
                isDark: isDark,
                homeSelected: _currentNavTab == 0,
                ordersSelected: false,
                notificationsSelected: false,
                profileSelected: _currentNavTab == 2,
                notificationBadge: badgeStr,
                onHome: () => _switchToTab(0, isBack: true),
                onOrders: auth.can(AppPermission.viewRepairOrders)
                    ? () => _navigateToTab(MainTabs.repairOrders)
                    : null,
                onBooking: () => showAppQuickActions(
                  context,
                  onNavigateToTab: (tab) {
                    if (tab == MainTabs.profile) {
                      _switchToTab(2);
                    } else {
                      _navigateToTab(tab);
                    }
                  },
                ),
                onNotifications: auth.can(AppPermission.viewNotifications)
                    ? () => _navigateToTab(MainTabs.notifications)
                    : null,
                onProfile: auth.can(AppPermission.viewProfile)
                    ? () => _switchToTab(2, isBack: false)
                    : null,
              )
            : null,
      ),
    );
  }

  static String _formatVietnameseDate(DateTime date) {
    const weekdays = {
      DateTime.monday: 'Thứ Hai',
      DateTime.tuesday: 'Thứ Ba',
      DateTime.wednesday: 'Thứ Tư',
      DateTime.thursday: 'Thứ Năm',
      DateTime.friday: 'Thứ Sáu',
      DateTime.saturday: 'Thứ Bảy',
      DateTime.sunday: 'Chủ Nhật',
    };
    final weekday = weekdays[date.weekday] ?? '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$weekday, $day/$month/${date.year}';
  }

  // 2. User Greeting Section
  Widget _buildGreeting(String userName, String? roleLabel, bool isDark) {
    final dateStr = _formatVietnameseDate(DateTime.now());
    final subtitleText = (roleLabel != null && roleLabel.trim().isNotEmpty)
        ? '$dateStr  •  Ca trực: $roleLabel'
        : dateStr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Xin chào, $userName 👋',
          style: TextStyle(
            fontSize: 20,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              LucideIcons.calendarDays,
              size: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 3. Dynamic Promotional Banner matching the web editor's 2:1 canvas.
  Widget _buildPromotionalBanner() {
    final backendProvider = Provider.of<BackendDataProvider?>(context);
    final banners =
        (backendProvider?.banners != null &&
            backendProvider!.banners.isNotEmpty)
        ? backendProvider.banners
        : const [AppBanner.defaultBanner];

    final baseUrl = backendProvider?.api.activeBaseUrl ?? '';

    return AppBannerCarousel(
      banners: banners,
      baseUrl: baseUrl,
      showLoadingPlaceholder:
          backendProvider != null && backendProvider.banners.isEmpty,
      onActionTap: _handleBannerButtonAction,
    );
  }

  void _openBannerTab(int tabIndex) {
    final auth = context.read<AuthProvider>();
    if (!canAccessMainTab(auth, tabIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền truy cập chức năng này.'),
        ),
      );
      return;
    }
    _navigateToTab(tabIndex);
  }

  Future<void> _handleBannerButtonAction(AppBannerButton btn) async {
    if (btn.actionType == 'BOOKING') {
      _showBookingSheet(
        serviceName: btn.actionValue ?? 'Gói bảo trì ưu đãi 25%',
      );
    } else if (btn.actionType == 'REPAIR_ORDER') {
      _openBannerTab(MainTabs.repairOrders);
    } else if (btn.actionType == 'SCREEN') {
      final value = (btn.actionValue ?? '').trim().toLowerCase();
      const routes = {
        'dashboard': MainTabs.dashboard,
        'repair_orders': MainTabs.repairOrders,
        'warehouse': MainTabs.warehouse,
        'attendance': MainTabs.attendance,
        'notifications': MainTabs.notifications,
        'account_approval': MainTabs.accountApproval,
        'messages': MainTabs.messages,
        'employee_management': MainTabs.employeeManagement,
        'customers': MainTabs.customers,
        'customer': MainTabs.customers,
        'profile': MainTabs.profile,
      };
      final tabIndex = routes[value];
      if (tabIndex != null) {
        _openBannerTab(tabIndex);
      } else if (value.contains('warehouse') || value.contains('kho')) {
        _openBannerTab(MainTabs.warehouse);
      } else if (value.contains('customer') || value.contains('khách')) {
        _openBannerTab(MainTabs.customers);
      } else if (value.contains('message') ||
          value.contains('chat') ||
          value.contains('nhắn')) {
        _openBannerTab(MainTabs.messages);
      } else if (value.contains('employee') || value.contains('nhân viên')) {
        _openBannerTab(MainTabs.employeeManagement);
      } else if (value.contains('repair') || value.contains('đơn')) {
        _openBannerTab(MainTabs.repairOrders);
      }
    }
  }

  // 6. Service Categories Grid
  Widget _buildServiceCategories(bool isDark) {
    final auth = context.watch<AuthProvider>();
    final categories = auth.isAuthenticated && auth.currentUser != null
        ? _categories.where((category) {
            if (category['id'] == 'field_work') {
              return auth.isAdminOrAbove ||
                  auth.can(AppPermission.saveFieldWork);
            }
            final tabIndex = category['tabIndex'] as int?;
            return tabIndex != null && canAccessMainTab(auth, tabIndex);
          }).toList()
        : <Map<String, dynamic>>[];
    if (categories.isEmpty) return const SizedBox.shrink();

    int unreadChats = 0;
    try {
      unreadChats = Provider.of<ChatProvider?>(context)?.totalUnreadCount ?? 0;
    } catch (_) {}

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chức năng',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 6,
            mainAxisSpacing: 8,
            mainAxisExtent: 68 + MediaQuery.textScalerOf(context).scale(24),
          ),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final tabIndex = (cat['tabIndex'] as int?) ?? MainTabs.dashboard;
            final label = cat['label']?.toString() ?? '';
            final tooltip = cat['tooltip']?.toString() ?? label;
            final baseBgColor =
                cat['bgColor'] as Color? ?? const Color(0xFFEFF6FF);
            final baseTextColor =
                cat['textColor'] as Color? ?? const Color(0xFF2563EB);
            final baseBorderColor =
                cat['borderColor'] as Color? ?? const Color(0xFFBFDBFE);
            final iconData = cat['icon'] is IconData
                ? cat['icon'] as IconData
                : null;
            final iconText = cat['icon'] is String
                ? cat['icon'] as String
                : null;
            final catId = cat['id']?.toString() ?? '';

            final effectiveColor = isDark
                ? _getDarkCategoryTone(baseTextColor)
                : baseTextColor;
            final iconBgColor = isDark
                ? effectiveColor.withValues(alpha: 0.16)
                : baseBgColor;
            final iconBorderColor = isDark
                ? effectiveColor.withValues(alpha: 0.35)
                : baseBorderColor;

            return Tooltip(
              message: tooltip,
              child: InteractiveBounce(
                key: ValueKey('category-$catId'),
                scaleDown: 0.94,
                onTap: () {
                  if (catId == 'field_work') {
                    showFieldWorkBottomSheet(context, isDark: isDark);
                    return;
                  }
                  final auth = context.read<AuthProvider>();
                  if (!canAccessMainTab(auth, tabIndex)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bạn không có quyền truy cập chức năng $label.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  _navigateToTab(tabIndex);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.025,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: iconBorderColor.withValues(alpha: 0.85),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: iconData != null
                                  ? Icon(
                                      iconData,
                                      size: 20,
                                      color: effectiveColor,
                                    )
                                  : Text(
                                      iconText ?? '',
                                      style: const TextStyle(fontSize: 18),
                                    ),
                            ),
                          ),
                          if (catId == 'messages' && unreadChats > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.surfaceDark
                                        : Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  unreadChats > 99
                                      ? '99+'
                                      : unreadChats.toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : const Color(0xFF1E293B),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getDarkCategoryTone(Color c) {
    if (c.toARGB32() == const Color(0xFF2563EB).toARGB32()) {
      return const Color(0xFF60A5FA);
    }
    if (c.toARGB32() == const Color(0xFFD97706).toARGB32()) {
      return const Color(0xFFFBBF24);
    }
    if (c.toARGB32() == const Color(0xFF059669).toARGB32()) {
      return const Color(0xFF34D399);
    }
    if (c.toARGB32() == const Color(0xFF4F46E5).toARGB32()) {
      return const Color(0xFF818CF8);
    }
    if (c.toARGB32() == const Color(0xFF7C3AED).toARGB32()) {
      return const Color(0xFFA78BFA);
    }
    return c;
  }
}

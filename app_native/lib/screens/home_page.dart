import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'profile_page.dart';

/// Home Screen designed faithfully from Stitch (Home Screen - Home Service Marketplace)
/// Features:
/// - Sticky TopBar with location picker, app logo avatar, notification indicator
/// - User Greeting ("Hello, [Name] 👋")
/// - Promotional Banner featuring the 3D Character (`assets/images/image_character.png`)
/// - Service Categories Grid (Chức năng: Dashboard, Đơn, Kho, Nhắn tin, Quản lý nhân viên)
/// - Top Rated Experts list with verified badges, ratings, and booking action
/// - Optional 3-Tab Bottom Navigation Bar matching Stitch
class HomePage extends StatefulWidget {
  final void Function(int tabIndex)? onNavigateToTab;
  final bool showBottomNav;
  final int initialNavTab;

  const HomePage({
    super.key,
    this.onNavigateToTab,
    this.showBottomNav = false,
    this.initialNavTab = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late int _currentNavTab; // 0: Home, 1: Book (+), 2: Profile
  late final PageController _bannerController;
  int _currentBannerIndex = 0;
  int _previousBannerCount = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentNavTab = widget.initialNavTab;
    _bannerController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final backend = context.read<BackendDataProvider>();
        _previousBannerCount = backend.banners.length;
        _startBannerTimer(backend.banners.length);
        backend.loadBanners(notify: true).then((_) {
          if (mounted) {
            final count = context.read<BackendDataProvider>().banners.length;
            _previousBannerCount = count;
            _startBannerTimer(count);
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<BackendDataProvider>().loadBanners(notify: true);
    }
  }

  void _startBannerTimer(int count) {
    _bannerTimer?.cancel();
    if (count <= 1) {
      _currentBannerIndex = 0;
      return;
    }
    if (_currentBannerIndex >= count) {
      _currentBannerIndex = 0;
      if (_bannerController.hasClients) {
        _bannerController.jumpToPage(0);
      }
    }
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final nextIndex = (_currentBannerIndex + 1) % count;
      _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetBannerTimer(int count) {
    _startBannerTimer(count);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _bannerController.dispose();
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
      'label': 'Đơn',
      'tooltip': 'Đơn sửa chữa',
      'tabIndex': MainTabs.repairOrders,
      'icon': LucideIcons.wrench,
      'bgColor': Color(0xFFFFFBEB),
      'textColor': Color(0xFFD97706),
      'borderColor': Color(0xFFFDE68A),
    },
    {
      'id': 'warehouse',
      'label': 'Kho',
      'tooltip': 'Kho linh kiện',
      'tabIndex': MainTabs.warehouse,
      'icon': LucideIcons.boxes,
      'bgColor': Color(0xFFECFDF5),
      'textColor': Color(0xFF059669),
      'borderColor': Color(0xFFA7F3D0),
    },
    {
      'id': 'messages',
      'label': 'Nhắn tin',
      'tooltip': 'Nhắn tin',
      'tabIndex': MainTabs.messages,
      'icon': LucideIcons.messageSquare,
      'bgColor': Color(0xFFEEF2FF),
      'textColor': Color(0xFF4F46E5),
      'borderColor': Color(0xFFC7D2FE),
    },
    {
      'id': 'employee_management',
      'label': 'Quản lý nhân viên',
      'tooltip': 'Quản lý nhân viên & tài khoản',
      'tabIndex': MainTabs.employeeManagement,
      'icon': LucideIcons.users,
      'bgColor': Color(0xFFFAF5FF),
      'textColor': Color(0xFF7C3AED),
      'borderColor': Color(0xFFE9D5FF),
    },
  ];

  final List<Map<String, dynamic>> _experts = const [
    {
      'id': 'exp_1',
      'name': 'David Miller',
      'role': 'Chuyên gia Bo mạch Inverter • 6 năm exp',
      'rating': 4.9,
      'reviews': 128,
      'price': '350.000đ/h',
      'initials': 'DM',
      'gradient': [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      'verified': true,
    },
    {
      'id': 'exp_2',
      'name': 'Sarah Jenkins',
      'role': 'Chuyên viên Vệ sinh & Bảo dưỡng • 4 năm exp',
      'rating': 5.0,
      'reviews': 94,
      'price': '280.000đ/h',
      'initials': 'SJ',
      'gradient': [Color(0xFFA855F7), Color(0xFFEC4899)],
      'verified': true,
    },
    {
      'id': 'exp_3',
      'name': 'Trần Anh Tuấn',
      'role': 'Kỹ sư Tự động hóa & Biến tần • 8 năm exp',
      'rating': 4.9,
      'reviews': 215,
      'price': '420.000đ/h',
      'initials': 'TA',
      'gradient': [Color(0xFF10B981), Color(0xFF0F766E)],
      'verified': true,
    },
  ];

  void _navigateToTab(int tabIndex) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.dashboard, arguments: tabIndex);
    }
  }

  void _showBookingSheet({String? expertName, String? serviceName}) {
    showQuickBookingSheet(
      context,
      expertName: expertName,
      serviceName: serviceName,
      onNavigateToTab: _navigateToTab,
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

    final notificationProvider = context.watch<NotificationProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final userName =
        auth.currentUser?.name ?? auth.currentUser?.username ?? 'Alex';

    final Widget bodyContent;
    if (_currentNavTab == 2) {
      bodyContent = ProfilePage(
        showBottomNav: false,
        onNavigateToHome: () {
          setState(() => _currentNavTab = 0);
        },
        onNavigateToTab: widget.onNavigateToTab,
      );
    } else {
      bodyContent = RefreshIndicator(
        onRefresh: () async {
          if (!auth.isAttendanceAccount) {
            await context.read<BackendDataProvider>().loadAll(
              isManagerOrAbove: auth.isManagerOrAbove,
            );
          }
        },
        child: Column(
          children: [
            // Sticky Top Bar Header
            _buildTopBar(unreadCount),

            // Scrollable Main Content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Greeting Section
                    _buildGreeting(userName),
                    const SizedBox(height: 18),

                    // Promotional Banner with 3D Character (assets/images/image_character.png)
                    _buildPromotionalBanner(),
                    const SizedBox(height: 22),

                    // Service Categories Grid
                    _buildServiceCategories(),
                    const SizedBox(height: 22),

                    // Top Rated Experts
                    _buildTopRatedExperts(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50 from Stitch
      body: SafeArea(child: bodyContent),
      bottomNavigationBar: widget.showBottomNav
          ? MobileNavigationBar(
              isDark: Theme.of(context).brightness == Brightness.dark,
              homeSelected: _currentNavTab == 0,
              profileSelected: _currentNavTab == 2,
              onHome: () {
                setState(() => _currentNavTab = 0);
                context.read<BackendDataProvider>().loadBanners(notify: true);
              },
              onBooking: auth.isAuthenticated
                  ? () => _showBookingSheet()
                  : null,
              onProfile: auth.can(AppPermission.viewProfile)
                  ? () => setState(() => _currentNavTab = 2)
                  : null,
            )
          : null,
    );
  }

  // 1. Top Bar Header
  Widget _buildTopBar(int unreadCount) {
    final auth = context.watch<AuthProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Location Picker with App Logo Avatar
          Expanded(
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Vị trí hiện tại: 124 Oxford St, Quận 1, TP.HCM',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'VỊ TRÍ CỦA BẠN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: const [
                            Flexible(
                              child: Text(
                                '124 Oxford St, Quận 1',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notification Bell Icon with Badge
          if (auth.can(AppPermission.viewNotifications))
            InkWell(
              onTap: () => _navigateToTab(MainTabs.notifications),
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.bell,
                        size: 18,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 2. User Greeting Section
  Widget _buildGreeting(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, $userName 👋',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Tìm kiếm chuyên gia & đặt dịch vụ bảo trì nhanh chóng',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // 3. Dynamic Promotional Banner with 3D Character or Custom Image
  Widget _buildPromotionalBanner() {
    final backendProvider = Provider.of<BackendDataProvider?>(context);
    final banners =
        (backendProvider?.banners != null &&
            backendProvider!.banners.isNotEmpty)
        ? backendProvider.banners
        : AppBanner.defaultBanners;

    final baseUrl = backendProvider?.api.activeBaseUrl ?? '';

    if (_currentBannerIndex >= banners.length) {
      _currentBannerIndex = 0;
    }

    if (_bannerTimer == null ||
        !_bannerTimer!.isActive ||
        _previousBannerCount != banners.length) {
      _previousBannerCount = banners.length;
      _startBannerTimer(banners.length);
    }

    return SizedBox(
      height: 225,
      child: Stack(
        children: [
          Listener(
            onPointerDown: (_) => _bannerTimer?.cancel(),
            onPointerUp: (_) => _resetBannerTimer(banners.length),
            onPointerCancel: (_) => _resetBannerTimer(banners.length),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = index;
                });
                _resetBannerTimer(banners.length);
              },
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _bannerController,
                  builder: (context, child) {
                    double pageOffset = 0.0;
                    if (_bannerController.position.haveDimensions) {
                      pageOffset =
                          (_bannerController.page ??
                              _currentBannerIndex.toDouble()) -
                          index;
                    } else {
                      pageOffset = (_currentBannerIndex - index).toDouble();
                    }
                    final double absOffset = pageOffset.abs().clamp(0.0, 1.0);
                    final double scale = 1.0 - (absOffset * 0.06);
                    final double opacity = 1.0 - (absOffset * 0.28);
                    final double translationX = pageOffset * 14;

                    return Transform.translate(
                      offset: Offset(translationX, 0.0),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _buildBannerCard(banners[index], baseUrl),
                );
              },
            ),
          ),

          // Pinned Carousel Indicator Dots (Stitch modern capsule style)
          if (banners.length > 1)
            Positioned(
              bottom: 12,
              left: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(banners.length, (dotIdx) {
                  final isDotActive = dotIdx == _currentBannerIndex;
                  return GestureDetector(
                    onTap: () {
                      _bannerController.animateToPage(
                        dotIdx,
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeInOutCubic,
                      );
                      _resetBannerTimer(banners.length);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 6),
                      width: isDotActive ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDotActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isDotActive
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(AppBanner banner, String baseUrl) {
    return GestureDetector(
      onTap: () => _handleBannerAction(banner),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient:
              (banner.backgroundImageUrl == null ||
                  banner.backgroundImageUrl!.isEmpty)
              ? LinearGradient(
                  colors: banner.gradientColorList,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          image:
              (banner.backgroundImageUrl != null &&
                  banner.backgroundImageUrl!.isNotEmpty)
              ? DecorationImage(
                  image: NetworkImage(
                    _resolveImageUrl(banner.backgroundImageUrl, baseUrl),
                  ),
                  fit: BoxFit.cover,
                  onError: (_, _) {},
                  colorFilter: banner.darkenOverlay
                      ? ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.35),
                          BlendMode.darken,
                        )
                      : null,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: banner.gradientColorList.first.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background soft radial blur
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Banner text and action button
            Padding(
              padding: _getBannerTextPadding(banner.imagePosition),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pill Deal
                  if (banner.badgeText != null &&
                      banner.badgeText!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        banner.badgeText!,
                        style: _getBannerTextStyle(
                          fontFamily: banner.fontFamily,
                          baseStyle: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (banner.title.trim().isNotEmpty) ...[
                    Text(
                      banner.title,
                      style: _getBannerTextStyle(
                        fontFamily: banner.fontFamily,
                        baseStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                  if (banner.subtitle != null &&
                      banner.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildSubtitle(banner.subtitle!, banner.fontFamily),
                  ],
                  if (banner.buttons.isNotEmpty &&
                      banner.buttonPosition != 'TOP_RIGHT' &&
                      banner.buttonPosition != 'TOP_LEFT' &&
                      banner.buttonPosition != 'CUSTOM') ...[
                    const SizedBox(height: 12),
                    _buildButtonsContainer(banner),
                  ],
                ],
              ),
            ),

            // Custom / Stack Positioned Buttons (if TOP_RIGHT, TOP_LEFT, or CUSTOM)
            _buildCustomPositionedButtons(banner),

            // 3D Character or Custom Image based on imagePosition
            _buildPositionedMascot(banner, baseUrl),
          ],
        ),
      ),
    );
  }

  TextStyle _getBannerTextStyle({
    required String? fontFamily,
    required TextStyle baseStyle,
  }) {
    if (fontFamily == null ||
        fontFamily.trim().isEmpty ||
        fontFamily == 'DEFAULT') {
      return baseStyle;
    }
    try {
      return GoogleFonts.getFont(fontFamily.trim(), textStyle: baseStyle);
    } catch (_) {
      return baseStyle;
    }
  }

  Widget _buildSubtitle(String text, [String? fontFamily]) {
    final baseStyle = _getBannerTextStyle(
      fontFamily: fontFamily,
      baseStyle: TextStyle(
        fontSize: 11,
        color: Colors.blue.shade100,
        height: 1.3,
      ),
    );
    final highlightStyle = _getBannerTextStyle(
      fontFamily: fontFamily,
      baseStyle: const TextStyle(
        fontSize: 11,
        color: Color(0xFFFDE047),
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
    );

    if (text.contains('25% GIÁ TRỊ')) {
      final parts = text.split('25% GIÁ TRỊ');
      return RichText(
        text: TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: parts.first),
            TextSpan(text: '25% GIÁ TRỊ', style: highlightStyle),
            if (parts.length > 1)
              TextSpan(text: parts.sublist(1).join('25% GIÁ TRỊ')),
          ],
        ),
      );
    }
    return Text(text, style: baseStyle);
  }

  EdgeInsets _getBannerTextPadding(String imagePosition) {
    switch (imagePosition) {
      case 'LEFT':
        return const EdgeInsets.fromLTRB(124, 16, 18, 20);
      case 'RIGHT_TOP':
        return const EdgeInsets.fromLTRB(18, 16, 95, 20);
      case 'NONE':
        return const EdgeInsets.fromLTRB(18, 16, 18, 20);
      case 'RIGHT':
      default:
        return const EdgeInsets.fromLTRB(18, 16, 118, 20);
    }
  }

  Widget _buildPositionedMascot(AppBanner banner, String baseUrl) {
    if (banner.imagePosition == 'NONE' || banner.imagePosition == 'EMPTY') {
      return const SizedBox.shrink();
    }
    // If banner has an uploaded custom image and no specific mascot image is configured, omit mascot
    if (banner.backgroundImageUrl != null &&
        banner.backgroundImageUrl!.isNotEmpty &&
        (banner.imageUrl == null || banner.imageUrl!.isEmpty)) {
      return const SizedBox.shrink();
    }
    if (banner.imagePosition == 'LEFT') {
      return Positioned(
        left: 0,
        bottom: 0,
        width: 120,
        height: 120,
        child: _buildBannerImage(banner, baseUrl),
      );
    }
    if (banner.imagePosition == 'RIGHT_TOP') {
      return Positioned(
        right: 8,
        top: 8,
        width: 85,
        height: 85,
        child: _buildBannerImage(banner, baseUrl),
      );
    }
    return Positioned(
      right: 0,
      bottom: 0,
      width: 125,
      height: 125,
      child: _buildBannerImage(banner, baseUrl),
    );
  }

  String _resolveImageUrl(String? url, String baseUrl) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }

  Widget _buildBannerImage(AppBanner banner, String baseUrl) {
    final imgUrl = banner.imageUrl;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      final fullUrl = _resolveImageUrl(imgUrl, baseUrl);
      return Image.network(
        fullUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/image_character.png',
          fit: BoxFit.contain,
        ),
      );
    }
    return Image.asset(
      'assets/images/image_character.png',
      fit: BoxFit.contain,
    );
  }

  Widget _buildButtonsContainer(AppBanner banner) {
    final pos = banner.buttonPosition;
    final buttonsWidget = _buildBannerButtons(banner);

    if (pos == 'BOTTOM_CENTER') {
      return Center(child: buttonsWidget);
    } else if (pos == 'BOTTOM_RIGHT') {
      return Align(alignment: Alignment.centerRight, child: buttonsWidget);
    }
    // Default BOTTOM_LEFT
    return Align(alignment: Alignment.centerLeft, child: buttonsWidget);
  }

  Widget _buildCustomPositionedButtons(AppBanner banner) {
    if (banner.buttons.isEmpty) return const SizedBox.shrink();

    if (banner.buttonPosition == 'CUSTOM') {
      return Positioned(
        top: banner.buttonTop,
        bottom: banner.buttonBottom,
        left: banner.buttonLeft,
        right: banner.buttonRight,
        child: _buildBannerButtons(banner),
      );
    }

    if (banner.buttonPosition == 'TOP_RIGHT') {
      return Positioned(
        top: banner.buttonTop ?? 14,
        right: banner.buttonRight ?? 14,
        bottom: banner.buttonBottom,
        left: banner.buttonLeft,
        child: _buildBannerButtons(banner),
      );
    }

    if (banner.buttonPosition == 'TOP_LEFT') {
      return Positioned(
        top: banner.buttonTop ?? 14,
        left: banner.buttonLeft ?? 18,
        bottom: banner.buttonBottom,
        right: banner.buttonRight,
        child: _buildBannerButtons(banner),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBannerButtons(AppBanner banner) {
    if (banner.buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    final auth = context.watch<AuthProvider>();
    final allowedButtons = banner.buttons.where((btn) {
      if (btn.actionType == 'BOOKING') {
        return auth.can(AppPermission.manageRepairOrders);
      }
      if (btn.actionType == 'REPAIR_ORDER') {
        return auth.can(AppPermission.viewRepairOrders);
      }
      if (btn.actionType == 'SCREEN') {
        final val = (btn.actionValue ?? '').toLowerCase();
        if (val.contains('warehouse') || val.contains('kho')) {
          return auth.can(AppPermission.viewWarehouse);
        }
        if (val.contains('message') ||
            val.contains('chat') ||
            val.contains('nhắn')) {
          return auth.can(AppPermission.useMessages);
        }
        if (val.contains('employee') || val.contains('nhân viên')) {
          return auth.canAny({
            AppPermission.manageEmployees,
            AppPermission.approveAccounts,
          });
        }
        return auth.can(AppPermission.viewDashboard);
      }
      return true;
    }).toList();

    if (allowedButtons.isEmpty) {
      return const SizedBox.shrink();
    }

    final brandColor = banner.gradientColorList.length > 2
        ? banner.gradientColorList[2]
        : const Color(0xFF1D4ED8);

    final buttonWidgets = allowedButtons.map((btn) {
      final isSecondary = btn.styleType == 'SECONDARY';
      final isOutline = btn.styleType == 'OUTLINE';

      if (isSecondary) {
        return OutlinedButton(
          onPressed: () => _handleBannerButtonAction(btn),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            foregroundColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                btn.text,
                style: _getBannerTextStyle(
                  fontFamily: banner.fontFamily,
                  baseStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                btn.actionType == 'CALL'
                    ? LucideIcons.phone
                    : LucideIcons.arrowRight,
                size: 12,
              ),
            ],
          ),
        );
      }

      if (isOutline) {
        return OutlinedButton(
          onPressed: () => _handleBannerButtonAction(btn),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white, width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                btn.text,
                style: _getBannerTextStyle(
                  fontFamily: banner.fontFamily,
                  baseStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                btn.actionType == 'CALL'
                    ? LucideIcons.phone
                    : LucideIcons.arrowRight,
                size: 12,
              ),
            ],
          ),
        );
      }

      // Default PRIMARY
      return ElevatedButton(
        onPressed: () => _handleBannerButtonAction(btn),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: brandColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              btn.text,
              style: _getBannerTextStyle(
                fontFamily: banner.fontFamily,
                baseStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              btn.actionType == 'CALL'
                  ? LucideIcons.phone
                  : LucideIcons.arrowRight,
              size: 13,
            ),
          ],
        ),
      );
    }).toList();

    return Wrap(spacing: 8, runSpacing: 6, children: buttonWidgets);
  }

  void _handleBannerButtonAction(AppBannerButton btn) {
    if (btn.actionType == 'BOOKING') {
      _showBookingSheet(
        serviceName: btn.actionValue ?? 'Gói bảo trì ưu đãi 25%',
      );
    } else if (btn.actionType == 'REPAIR_ORDER') {
      _navigateToTab(MainTabs.repairOrders);
    } else if (btn.actionType == 'CALL') {
      final phone = btn.actionValue ?? '0912345678';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gọi hotline: $phone'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (btn.actionType == 'SCREEN') {
      final val = (btn.actionValue ?? '').toLowerCase();
      if (val.contains('warehouse') || val.contains('kho')) {
        _navigateToTab(MainTabs.warehouse);
      } else if (val.contains('message') ||
          val.contains('chat') ||
          val.contains('nhắn')) {
        _navigateToTab(MainTabs.messages);
      } else if (val.contains('employee') || val.contains('nhân viên')) {
        _navigateToTab(MainTabs.employeeManagement);
      } else {
        _navigateToTab(MainTabs.dashboard);
      }
    } else if (btn.actionType == 'LINK') {
      if (mounted && btn.actionValue != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Liên kết: ${btn.actionValue}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _handleBannerAction(AppBanner banner) {
    if (banner.buttons.isNotEmpty) {
      _handleBannerButtonAction(banner.buttons.first);
    } else {
      _handleBannerButtonAction(
        AppBannerButton(
          text: banner.buttonText ?? 'Đặt lịch ngay',
          actionType: banner.actionType,
          actionValue: banner.actionValue,
        ),
      );
    }
  }

  // 6. Service Categories Grid
  Widget _buildServiceCategories() {
    int unreadChats = 0;
    try {
      unreadChats = Provider.of<ChatProvider?>(context)?.totalUnreadCount ?? 0;
    } catch (_) {}

    final auth = context.watch<AuthProvider>();
    final visibleCategories = _categories.where((cat) {
      final tabIndex = (cat['tabIndex'] as int?) ?? MainTabs.dashboard;
      return canAccessMainTab(auth, tabIndex);
    }).toList();

    if (visibleCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chức năng',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            if (canAccessMainTab(auth, MainTabs.dashboard))
              InkWell(
                onTap: () {
                  _navigateToTab(MainTabs.dashboard);
                },
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: visibleCategories.length <= 4
                ? (visibleCategories.isEmpty ? 1 : visibleCategories.length)
                : 5,
            crossAxisSpacing: 6,
            mainAxisSpacing: 8,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, index) {
            final cat = visibleCategories[index];
            final tabIndex = (cat['tabIndex'] as int?) ?? MainTabs.dashboard;
            final label = cat['label']?.toString() ?? '';
            final tooltip = cat['tooltip']?.toString() ?? label;
            final bgColor = cat['bgColor'] as Color? ?? const Color(0xFFEFF6FF);
            final textColor =
                cat['textColor'] as Color? ?? const Color(0xFF2563EB);
            final borderColor =
                cat['borderColor'] as Color? ?? const Color(0xFFBFDBFE);
            final iconData = cat['icon'] is IconData
                ? cat['icon'] as IconData
                : null;
            final iconText = cat['icon'] is String
                ? cat['icon'] as String
                : null;
            final catId = cat['id']?.toString() ?? '';

            return Tooltip(
              message: tooltip,
              child: InkWell(
                onTap: () {
                  _navigateToTab(tabIndex);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
                              color: bgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: borderColor.withValues(alpha: 0.8),
                                width: 1.0,
                              ),
                            ),
                            child: Center(
                              child: iconData != null
                                  ? Icon(iconData, size: 20, color: textColor)
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
                                    color: Colors.white,
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
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
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

  // 7. Top Rated Experts Section
  Widget _buildTopRatedExperts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Kỹ thuật viên tiêu biểu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Chuyên gia đã xác thực & đánh giá cao',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            if (canAccessMainTab(
              context.watch<AuthProvider>(),
              MainTabs.employeeManagement,
            )) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _navigateToTab(MainTabs.employeeManagement),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _experts.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final exp = _experts[index];
            final gradients = exp['gradient'] as List<Color>;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar with Initials & Verified badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradients,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            exp['initials'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (exp['verified'] == true)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                '✓',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Name, role, rating & price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                exp['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Đã xác thực',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exp['role'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${exp['rating']}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '(${exp['reviews']})',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          exp['price'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Book Button
                  if (context.watch<AuthProvider>().can(
                    AppPermission.manageRepairOrders,
                  ))
                    ElevatedButton(
                      onPressed: () =>
                          _showBookingSheet(expertName: exp['name'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Đặt lịch',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

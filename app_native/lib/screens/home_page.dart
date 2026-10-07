import '../widgets/app_quick_actions.dart';
import '../widgets/home_attendance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../widgets/banner_canvas.dart';
import '../widgets/interactive_bounce.dart';
import '../widgets/directional_slide_switcher.dart';
import '../widgets/smooth_banner_physics.dart';
import '../widgets/navigation/mobile_dashboard_app_bar.dart';
import '../app/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
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
  static const int _kInitialVirtualPage = 10080;
  late final PageController _bannerController;
  int _currentBannerIndex = 0;
  Timer? _bannerAutoPlayTimer;
  int _lastAutoPlayBannerCount = 0;

  static int _toRealBannerIndex(int index, int length) {
    if (length <= 0) return 0;
    final mod = index % length;
    return mod < 0 ? mod + length : mod;
  }

  void _startBannerAutoPlay(int bannerCount) {
    _stopBannerAutoPlay();
    if (bannerCount <= 1) return;
    _bannerAutoPlayTimer = Timer.periodic(AppMotion.bannerHold, (timer) {
      if (!mounted ||
          !_bannerController.hasClients ||
          _bannerController.positions.length != 1) {
        return;
      }
      if (_bannerController.position.isScrollingNotifier.value ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }
      final currentPage =
          _bannerController.page?.round() ?? _kInitialVirtualPage;
      final nextPage = currentPage + 1;
      _bannerController.animateToPage(
        nextPage,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.banner,
        curve: AppMotion.curve,
      );
    });
  }

  void _animateToBannerIndex(int targetBannerIndex, int totalCount) {
    if (!_bannerController.hasClients || totalCount <= 1) return;
    _stopBannerAutoPlay();
    final currentPage = _bannerController.page?.round() ?? _kInitialVirtualPage;
    final currentModulo = _toRealBannerIndex(currentPage, totalCount);
    final forwardDelta = (targetBannerIndex - currentModulo) % totalCount;
    final backwardDelta = (currentModulo - targetBannerIndex) % totalCount;
    final targetPage = forwardDelta <= backwardDelta
        ? currentPage + forwardDelta
        : currentPage - backwardDelta;

    _bannerController.animateToPage(
      targetPage,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.banner,
      curve: AppMotion.curve,
    );
    _startBannerAutoPlay(totalCount);
  }

  void _stopBannerAutoPlay() {
    _bannerAutoPlayTimer?.cancel();
    _bannerAutoPlayTimer = null;
  }

  void _syncBannerAutoPlay(int bannerCount) {
    if (bannerCount <= 1) {
      _stopBannerAutoPlay();
      _lastAutoPlayBannerCount = bannerCount;
      return;
    }
    if (_bannerAutoPlayTimer == null ||
        _lastAutoPlayBannerCount != bannerCount) {
      _lastAutoPlayBannerCount = bannerCount;
      _startBannerAutoPlay(bannerCount);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentNavTab = widget.initialNavTab;
    _navigatingBack = false;
    _bannerController = PageController(initialPage: _kInitialVirtualPage);
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
    if (state != AppLifecycleState.resumed) _stopBannerAutoPlay();
    if (state == AppLifecycleState.resumed && mounted) {
      final backend = context.read<BackendDataProvider>();
      _startBannerAutoPlay(backend.banners.length);
      if (!backend.isLoadingBanners) unawaited(backend.loadBanners());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBannerAutoPlay();
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
      'tooltip': 'Tin nhắn trao đổi',
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

    final Widget middleContent;
    if (_currentNavTab == 2) {
      _stopBannerAutoPlay();
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Greeting Section
                _buildGreeting(userName, isDark),
                const SizedBox(height: 18),

                // Promotional Banner with 3D Character (assets/images/image_character.png)
                _buildPromotionalBanner(),
                const SizedBox(height: 22),

                // Service Categories Grid
                _buildServiceCategories(isDark),
                const SizedBox(height: 22),

                // Top Rated Experts
                const HomeAttendance(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.embedded) return middleContent;

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
          notificationBadge: unreadCount == 0
              ? ''
              : unreadCount > 99
              ? '99+'
              : '$unreadCount',
          onToggleTheme: () => context.read<ThemeProvider>().toggleTheme(),
          onToggleNotifications: () => _navigateToTab(MainTabs.notifications),
          showNotification: auth.can(AppPermission.viewNotifications),
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
                profileSelected: _currentNavTab == 2,
                onHome: () => _switchToTab(0, isBack: true),
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
                onProfile: auth.can(AppPermission.viewProfile)
                    ? () => _switchToTab(2, isBack: false)
                    : null,
              )
            : null,
      ),
    );
  }

  // 2. User Greeting Section
  Widget _buildGreeting(String userName, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, $userName 👋',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : const Color(0xFF0F172A),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textSecondaryDark
                : const Color(0xFF64748B),
          ),
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
        : const [AppBanner.defaultBanner];

    final baseUrl = backendProvider?.api.activeBaseUrl ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bannerHeight = (constraints.maxWidth - 12) / 2;
        if (banners.length == 1) {
          _stopBannerAutoPlay();
          return SizedBox(
            height: bannerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildBannerCard(banners.first, baseUrl, 0, 1),
            ),
          );
        }

        _syncBannerAutoPlay(banners.length);

        return SizedBox(
          height: bannerHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _stopBannerAutoPlay();
              } else if (notification is ScrollEndNotification) {
                _startBannerAutoPlay(banners.length);
              }
              return false;
            },
            child: PageView.builder(
              controller: _bannerController,
              physics: const SmoothBannerPhysics(),
              clipBehavior: Clip.hardEdge,
              onPageChanged: (index) {
                setState(() {
                  _currentBannerIndex = _toRealBannerIndex(
                    index,
                    banners.length,
                  );
                });
              },
              itemBuilder: (context, index) {
                final realIndex = _toRealBannerIndex(index, banners.length);
                return Padding(
                  key: ValueKey('banner-slide-${banners[realIndex].id}'),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildBannerCard(
                    banners[realIndex],
                    baseUrl,
                    _currentBannerIndex,
                    banners.length,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerCard(
    AppBanner banner,
    String baseUrl,
    int currentIndex,
    int totalCount,
  ) {
    final design = banner.canvasDesign;
    if (design != null) {
      return BannerCanvas(
        banner: banner,
        design: design,
        baseUrl: baseUrl,
        mascot: _buildBannerImage(
          banner,
          baseUrl,
          imageAlignment: Alignment.center,
        ),
        onTap: () => _handleBannerAction(banner),
        onButtonTap: _handleBannerButtonAction,
        textStyle: (font, style) =>
            _getBannerTextStyle(fontFamily: font, baseStyle: style),
      );
    }
    return GestureDetector(
      onTap: () => _handleBannerAction(banner),
      child: Container(
        width: double.infinity,
        height: double.infinity,
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
                    banner.backgroundImageUrl!.startsWith('http')
                        ? banner.backgroundImageUrl!
                        : '$baseUrl${banner.backgroundImageUrl}',
                  ),
                  fit: BoxFit.cover,
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
              child: SingleChildScrollView(
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
            ),

            // Custom / Stack Positioned Buttons (if TOP_RIGHT, TOP_LEFT, or CUSTOM)
            _buildCustomPositionedButtons(banner),

            // 3D Character or Custom Image based on imagePosition
            _buildPositionedMascot(banner, baseUrl),

            // Carousel indicator dots (Stitch style)
            Positioned(
              bottom: 8,
              left: banner.imagePosition == 'LEFT' ? null : 18,
              right: banner.imagePosition == 'LEFT' ? 18 : null,
              child: Row(
                children: List.generate(totalCount > 1 ? totalCount : 3, (
                  dotIdx,
                ) {
                  final isDotActive = dotIdx == currentIndex;
                  return GestureDetector(
                    onTap: () {
                      if (totalCount > 1) {
                        _animateToBannerIndex(dotIdx, totalCount);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(right: 4),
                      width: isDotActive ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDotActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
    return Text(
      text,
      style: baseStyle,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  EdgeInsets _getBannerTextPadding(String imagePosition) {
    switch (imagePosition) {
      case 'LEFT':
        return const EdgeInsets.fromLTRB(126, 14, 18, 16);
      case 'RIGHT_TOP':
        return const EdgeInsets.fromLTRB(18, 14, 95, 16);
      case 'NONE':
        return const EdgeInsets.fromLTRB(18, 14, 18, 16);
      case 'RIGHT':
      default:
        return const EdgeInsets.fromLTRB(18, 14, 118, 16);
    }
  }

  Widget _buildPositionedMascot(AppBanner banner, String baseUrl) {
    if (banner.imagePosition == 'NONE' || banner.imagePosition == 'EMPTY') {
      return const SizedBox.shrink();
    }
    if (banner.imagePosition == 'LEFT') {
      return Positioned(
        left: 0,
        bottom: 0,
        top: 0,
        width: 150,
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
      top: 0,
      width: 165,
      child: _buildBannerImage(banner, baseUrl),
    );
  }

  Widget _buildBannerImage(
    AppBanner banner,
    String baseUrl, {
    Alignment? imageAlignment,
  }) {
    final imgUrl = banner.imageUrl;
    final alignment =
        imageAlignment ??
        (banner.imagePosition == 'LEFT'
            ? Alignment.bottomLeft
            : Alignment.bottomRight);
    if (imgUrl != null && imgUrl.isNotEmpty) {
      final fullUrl = imgUrl.startsWith('http') ? imgUrl : '$baseUrl$imgUrl';
      return Image.network(
        fullUrl,
        fit: BoxFit.contain,
        alignment: alignment,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/image_character.png',
          fit: BoxFit.contain,
          alignment: alignment,
        ),
      );
    }
    return Image.asset(
      'assets/images/image_character.png',
      fit: BoxFit.contain,
      alignment: alignment,
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

    final brandColor = banner.gradientColorList.length > 2
        ? banner.gradientColorList[2]
        : const Color(0xFF1D4ED8);

    final buttonWidgets = banner.buttons.map((btn) {
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
              Flexible(
                child: Text(
                  btn.text,
                  style: _getBannerTextStyle(
                    fontFamily: banner.fontFamily,
                    baseStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
              Flexible(
                child: Text(
                  btn.text,
                  style: _getBannerTextStyle(
                    fontFamily: banner.fontFamily,
                    baseStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
            Flexible(
              child: Text(
                btn.text,
                style: _getBannerTextStyle(
                  fontFamily: banner.fontFamily,
                  baseStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
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
        'profile': MainTabs.profile,
      };
      final tabIndex = routes[value];
      if (tabIndex != null) {
        _openBannerTab(tabIndex);
      } else if (value.contains('warehouse') || value.contains('kho')) {
        _openBannerTab(MainTabs.warehouse);
      } else if (value.contains('message') ||
          value.contains('chat') ||
          value.contains('nhắn')) {
        _openBannerTab(MainTabs.messages);
      } else if (value.contains('employee') || value.contains('nhân viên')) {
        _openBannerTab(MainTabs.employeeManagement);
      } else if (value.contains('repair') || value.contains('đơn')) {
        _openBannerTab(MainTabs.repairOrders);
      }
    } else if (btn.actionType == 'LINK' || btn.actionType == 'CALL') {
      final rawTarget = (btn.actionValue ?? '').trim();
      final target = btn.actionType == 'CALL'
          ? rawTarget
                .replaceFirst(RegExp(r'^tel:', caseSensitive: false), '')
                .replaceAll(RegExp(r'[\s().-]'), '')
          : rawTarget;
      if (btn.actionType == 'CALL' &&
          !RegExp(r'^\+?[0-9]{3,15}$').hasMatch(target)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Số điện thoại của banner không hợp lệ.'),
            ),
          );
        }
        return;
      }
      final uri = btn.actionType == 'CALL'
          ? Uri(scheme: 'tel', path: target)
          : Uri.tryParse(target);
      if (target.isEmpty ||
          uri == null ||
          (btn.actionType == 'LINK' &&
              (!['http', 'https'].contains(uri.scheme) || uri.host.isEmpty))) {
        return;
      }
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                btn.actionType == 'CALL'
                    ? 'Không thể mở ứng dụng Điện thoại.'
                    : 'Không thể mở liên kết này.',
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                btn.actionType == 'CALL'
                    ? 'Không thể mở ứng dụng Điện thoại.'
                    : 'Không thể mở liên kết này.',
              ),
            ),
          );
        }
      }
    }
  }

  void _handleBannerAction(AppBanner banner) {
    _handleBannerButtonAction(
      AppBannerButton(
        text: banner.buttonText ?? '',
        actionType: banner.actionType,
        actionValue: banner.actionValue,
      ),
    );
  }

  // 6. Service Categories Grid
  Widget _buildServiceCategories(bool isDark) {
    final auth = context.watch<AuthProvider>();
    final categories = auth.isAuthenticated && auth.currentUser != null
        ? _categories
              .where(
                (category) =>
                    canAccessMainTab(auth, category['tabIndex'] as int),
              )
              .toList()
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
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 6,
            mainAxisSpacing: 8,
            mainAxisExtent: 70 + MediaQuery.textScalerOf(context).scale(26),
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
                scaleDown: 0.94,
                onTap: () {
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
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFF1F5F9),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.02,
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
                                color: iconBorderColor.withValues(alpha: 0.8),
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : const Color(0xFF334155),
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

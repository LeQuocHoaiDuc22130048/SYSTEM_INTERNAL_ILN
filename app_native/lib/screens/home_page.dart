import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_routes.dart';
import '../navigation/main_tabs.dart';
import '../navigation/navigation_config.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/chat_provider.dart';
import '../utils/notification_provider.dart';
import '../models/app_permission.dart';
import '../widgets/navigation/mobile_navigation_bar.dart';
import '../widgets/quick_booking_sheet.dart';
import 'profile_page.dart';

/// Home Screen designed faithfully from Stitch (Home Screen - Home Service Marketplace)
/// Features:
/// - Sticky TopBar with location picker, app logo avatar, notification indicator
/// - User Greeting ("Hello, [Name] 👋")
/// - Search & Filter Bar
/// - Ongoing Activity Card (Active Booking with Tech & Status)
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

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  late int _currentNavTab; // 0: Home, 1: Book (+), 2: Profile

  @override
  void initState() {
    super.initState();
    _currentNavTab = widget.initialNavTab;
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
      'tooltip': 'Nhắn tin nội bộ',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToTab(int tabIndex) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.of(context).pushNamed(
        AppRoutes.dashboard,
        arguments: tabIndex,
      );
    }
  }

  void _showBookingSheet({String? expertName, String? serviceName}) {
    showQuickBookingSheet(context, expertName: expertName, serviceName: serviceName);
  }

  void _showOrderDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ĐÃ XÁC NHẬN ✓',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Mã đơn: #INV-2026',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Bảo trì Inverter & Nạp linh kiện',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kỹ thuật viên phụ trách: Michael Vance\nThời gian: Ngày mai lúc 10:00 AM\nĐịa chỉ: 124 Oxford St, Quận 1',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToTab(MainTabs.repairOrders);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Xem trong danh sách đơn sửa chữa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      });
    }

    final notificationProvider = context.watch<NotificationProvider>();
    final unreadCount = notificationProvider.unreadCount;
    final userName = auth.currentUser?.name ?? auth.currentUser?.username ?? 'Alex';

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
                    const SizedBox(height: 16),

                    // Search & Filter Bar
                    _buildSearchBar(),
                    const SizedBox(height: 18),

                    // Ongoing Activity Card (Matching Stitch)
                    _buildOngoingBookingCard(),
                    const SizedBox(height: 20),

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
              onHome: () => setState(() => _currentNavTab = 0),
              onBooking: () => _showBookingSheet(),
              onProfile: auth.can(AppPermission.viewProfile)
                  ? () => setState(() => _currentNavTab = 2)
                  : null,
            )
          : null,
    );
  }

  // 1. Top Bar Header
  Widget _buildTopBar(int unreadCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFF1F5F9),
            width: 1.2,
          ),
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
                    content: Text('Vị trí hiện tại: 124 Oxford St, Quận 1, TP.HCM'),
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
                            Icon(LucideIcons.chevronDown, size: 14, color: Color(0xFF64748B)),
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
                    child: Icon(LucideIcons.bell, size: 18, color: Color(0xFF475569)),
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
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // 3. Search & Filter Bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(LucideIcons.search, size: 18, color: Color(0xFF94A3B8)),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm sửa chữa, điện nước, biến tần...',
                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                _showBookingSheet();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.slidersHorizontal,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Ongoing Booking Card (Matching Stitch)
  Widget _buildOngoingBookingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            ),
            child: const Center(
              child: Text('❄️', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.40),
                        ),
                      ),
                      child: const Text(
                        'ĐÃ XÁC NHẬN ✓',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFBFDBFE),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ngày mai, 10:00 AM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade100,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'Bảo trì Inverter & Nạp linh kiện',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Với KTV: Michael Vance',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade100.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showOrderDetailsSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Text(
                'Chi tiết',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Promotional Banner with 3D Character Image
  Widget _buildPromotionalBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
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
            padding: const EdgeInsets.fromLTRB(18, 18, 126, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pill Deal
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                  ),
                  child: const Text(
                    '⚡ ƯU ĐÃI ĐẶC BIỆT',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bảo Trì & Sửa Chữa Inverter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade100, height: 1.3),
                    children: const [
                      TextSpan(text: 'Giảm ngay '),
                      TextSpan(
                        text: '25% GIÁ TRỊ',
                        style: TextStyle(
                          color: Color(0xFFFDE047),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: ' cho lượt đặt dịch vụ đầu tiên!'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => _showBookingSheet(serviceName: 'Gói bảo trì ưu đãi 25%'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1D4ED8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đặt lịch ngay',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 4),
                      Icon(LucideIcons.arrowRight, size: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3D Character Image (Prepared by User in assets/images/image_character.png)
          Positioned(
            right: 4,
            bottom: 0,
            child: SizedBox(
              width: 130,
              height: 162,
              child: Image.asset(
                'assets/images/image_character.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Carousel indicator dots (Stitch style)
          Positioned(
            bottom: 8,
            left: 18,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 6. Service Categories Grid
  Widget _buildServiceCategories() {
    int unreadChats = 0;
    try {
      unreadChats = Provider.of<ChatProvider?>(context)?.totalUnreadCount ?? 0;
    } catch (_) {}

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
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 6,
            mainAxisSpacing: 8,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final tabIndex = (cat['tabIndex'] as int?) ?? MainTabs.dashboard;
            final label = cat['label']?.toString() ?? '';
            final tooltip = cat['tooltip']?.toString() ?? label;
            final bgColor = cat['bgColor'] as Color? ?? const Color(0xFFEFF6FF);
            final textColor = cat['textColor'] as Color? ?? const Color(0xFF2563EB);
            final borderColor = cat['borderColor'] as Color? ?? const Color(0xFFBFDBFE);
            final iconData = cat['icon'] is IconData ? cat['icon'] as IconData : null;
            final iconText = cat['icon'] is String ? cat['icon'] as String : null;
            final catId = cat['id']?.toString() ?? '';

            return Tooltip(
              message: tooltip,
              child: InkWell(
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
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
                                  ? Icon(
                                      iconData,
                                      size: 20,
                                      color: textColor,
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
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Text(
                                  unreadChats > 99 ? '99+' : unreadChats.toString(),
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
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
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
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
                  ElevatedButton(
                    onPressed: () => _showBookingSheet(expertName: exp['name'] as String),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Đặt lịch',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
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

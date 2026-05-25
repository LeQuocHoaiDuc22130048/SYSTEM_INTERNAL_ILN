import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../utils/api_client.dart';
import '../utils/network_provider.dart';
import '../utils/pending_sync_provider.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/status_badge.dart';
import 'face_attendance_page.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasCheckedIn = true;
  String _checkInTime = '07:52';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BackendDataProvider>().loadAttendance();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateFormat('EEEE, dd/MM/yyyy').format(DateTime.now());
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 20 : 22,
                  wide ? 22 : 16,
                  wide ? 20 : 22,
                  12,
                ),
                child:
                    Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chấm công',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              today,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        )
                        .animate(target: 1)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.2, end: 0, duration: 400.ms),
              ),
            ),

            // Check-in Card - Takes 1/3 of viewport
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = MediaQuery.sizeOf(context).height;
                    final checkInHeight = screenHeight * 0.25;

                    return Container(
                          height: checkInHeight,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hôm nay',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue[200],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateFormat(
                                          'HH:mm',
                                        ).format(DateTime.now()),
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (_hasCheckedIn) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Color(0xFF6EE7B7),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Đã check-in: $_checkInTime',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.blue[100],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _handleFaceScan,
                                        icon: const Icon(
                                          LucideIcons.scanFace,
                                          size: 18,
                                        ),
                                        label: const Text('Quét khuôn mặt'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                        .animate(target: 1)
                        .fadeIn(duration: 600.ms, delay: 100.ms)
                        .slideY(
                          begin: 0.2,
                          end: 0,
                          duration: 600.ms,
                          delay: 100.ms,
                        );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Tabs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: AppColors.primary),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Hôm nay'),
                      Tab(text: 'Lịch sử'),
                      Tab(text: 'Báo cáo'),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Tab Content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayTab(),
                  _buildHistoryTab(),
                  _buildReportTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFaceScan() async {
    final confirmed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const FaceAttendancePage(),
      ),
    );
    if (confirmed != true || !mounted) return;

    final checkInTime = DateFormat('HH:mm').format(DateTime.now());
    setState(() {
      _hasCheckedIn = true;
      _checkInTime = checkInTime;
    });

    final network = context.read<NetworkProvider>();
    final isOnline = await network.checkNow();
    if (!mounted) return;

    if (!isOnline) {
      context.read<PendingSyncProvider>().addAction(
            type: PendingSyncType.faceAttendance,
            title: 'Chấm công khuôn mặt',
            description: 'Check-in lúc $checkInTime',
          );
      _showSnackBar(
        'Đã ghi nhận tạm. Admin sẽ thấy thay đổi khi thiết bị có mạng lại.',
        AppColors.warning,
      );
      return;
    }

    try {
      final backend = context.read<BackendDataProvider>();
      final data = await backend.api.post(
        '/api/v1/attendance/check',
        body: {
          'deviceId': 'flutter-mobile',
          'note': 'Cham cong bang khuon mat tu ung dung',
        },
      );
      await backend.loadAttendance();
      if (!mounted) return;

      final type = data is Map<String, dynamic> ? data['type']?.toString() : null;
      final label = type == 'OUT' ? 'Check-out' : 'Check-in';
      _showSnackBar('$label thành công, đã cập nhật backend.', AppColors.success);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message, AppColors.error);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar('Không thể cập nhật chấm công lên backend.', AppColors.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTodayTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final records = context.watch<BackendDataProvider>().attendanceRecords;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Work rules info
        Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Giờ làm việc quy định\nCheck-in trước 08:00 • Check-out sau 17:00\nĐến muộn từ 5 phút trở lên sẽ được ghi nhận là muộn',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .animate(target: 1)
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms),
        const SizedBox(height: 24),

        // Today's attendance list
        Text(
          'Chấm công toàn bộ hôm nay',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 12),
        ...records.map((record) {
          final index = records.indexOf(record);
          return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          record.employeeName[0],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.employeeName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vào: ${record.checkIn}${record.checkOut != null ? ' • Ra: ${record.checkOut}' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: record.status, size: 'sm'),
                  ],
                ),
              )
              .animate(target: 1)
              .fadeIn(
                duration: 400.ms,
                delay: (300 + index * 50).ms,
              )
              .slideX(
                begin: -0.2,
                end: 0,
                duration: 400.ms,
                delay: (300 + index * 50).ms,
              );
        }),
      ],
    );
  }

  Widget _buildHistoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Lịch sử chấm công',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tính năng đang phát triển',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assessment,
            size: 64,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Báo cáo chấm công',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tính năng đang phát triển',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _handleCheckInOut() {
    setState(() {
      if (_hasCheckedIn) {
        // Check-out
        _hasCheckedIn = false;
      } else {
        // Check-in
        _hasCheckedIn = true;
        _checkInTime = DateFormat('HH:mm').format(DateTime.now());
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _hasCheckedIn ? 'Check-in thành công!' : 'Check-out thành công!',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/mock_data.dart';
import '../models/repair_order.dart';
import '../theme/app_colors.dart';
import '../widgets/status_badge.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final contentWidth = constraints.maxWidth > 980
                ? 980.0
                : constraints.maxWidth;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 20 : 22,
                wide ? 22 : 16,
                wide ? 20 : 22,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DashboardHeader(isDark: isDark, wide: wide),
                      const SizedBox(height: 24),
                      GridView.builder(
                        itemCount: _dashboardStats.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: wide ? 4 : 2,
                          mainAxisSpacing: wide ? 20 : 10,
                          crossAxisSpacing: wide ? 12 : 10,
                          mainAxisExtent: wide ? 112 : 98,
                        ),
                        itemBuilder: (context, index) {
                          final stat = _dashboardStats[index];
                          return _DashboardStatCard(stat: stat, isDark: isDark)
                              .animate()
                              .fadeIn(duration: 260.ms, delay: (index * 35).ms)
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                duration: 260.ms,
                                delay: (index * 35).ms,
                              );
                        },
                      ),
                      const SizedBox(height: 20),
                      _WeeklyOrdersChart(isDark: isDark),
                      const SizedBox(height: 20),
                      _StatusRatioCard(isDark: isDark, wide: wide),
                      const SizedBox(height: 20),
                      _TodayAttendanceCard(isDark: isDark),
                      const SizedBox(height: 20),
                      _RecentOrdersCard(isDark: isDark),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isDark;
  final bool wide;

  const _DashboardHeader({required this.isDark, required this.wide});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vietnameseDate(DateTime.now()),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.2,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Xin chào, Minh 👋',
                style: TextStyle(
                  fontSize: wide ? 24 : 22,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
        if (wide)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.successLight.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withOpacity(0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.success),
                SizedBox(width: 8),
                Text(
                  'Hệ thống hoạt động bình thường',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _vietnameseDate(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];

    return '${weekdays[date.weekday - 1]}, ${date.day} tháng ${date.month}, ${date.year}';
  }
}

class _DashboardStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final String? helper;
  final String? trend;

  const _DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
    this.helper,
    this.trend,
  });
}

const _dashboardStats = [
  _DashboardStat(
    label: 'Tổng đơn hôm nay',
    value: '24',
    icon: LucideIcons.wrench,
    color: AppColors.primary,
    background: AppColors.infoLight,
    trend: '↑ 12% so hôm qua',
  ),
  _DashboardStat(
    label: 'Đang xử lý',
    value: '8',
    icon: LucideIcons.activity,
    color: AppColors.warning,
    background: AppColors.warningLight,
    helper: 'Cần theo dõi',
  ),
  _DashboardStat(
    label: 'Hoàn thành hôm nay',
    value: '12',
    icon: LucideIcons.circleCheck,
    color: AppColors.success,
    background: AppColors.successLight,
    trend: '↑ 8% so hôm qua',
  ),
  _DashboardStat(
    label: 'Bo mạch sẵn sàng',
    value: '6/10',
    icon: LucideIcons.microchip,
    color: AppColors.purple,
    background: AppColors.purpleLight,
    helper: '3 đang dùng',
  ),
  _DashboardStat(
    label: 'Nhân viên có mặt',
    value: '6/6',
    icon: LucideIcons.usersRound,
    color: AppColors.primary,
    background: AppColors.infoLight,
    helper: '1 đến muộn',
  ),
  _DashboardStat(
    label: 'Đơn chờ phân công',
    value: '4',
    icon: LucideIcons.circle,
    color: AppColors.warning,
    background: AppColors.warningLight,
  ),
  _DashboardStat(
    label: 'Bo mạch bảo trì',
    value: '1',
    icon: LucideIcons.triangleAlert,
    color: AppColors.error,
    background: AppColors.errorLight,
  ),
  _DashboardStat(
    label: 'Tài khoản chờ duyệt',
    value: '2',
    icon: LucideIcons.userRoundPlus,
    color: AppColors.purple,
    background: AppColors.purpleLight,
  ),
];

class _DashboardStatCard extends StatelessWidget {
  final _DashboardStat stat;
  final bool isDark;

  const _DashboardStatCard({required this.stat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stat.value,
                  style: TextStyle(
                    fontSize: 23,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                if (stat.trend != null)
                  Text(
                    stat.trend!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (stat.helper != null)
                  Text(
                    stat.helper!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: stat.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(stat.icon, size: 18, color: stat.color),
          ),
        ],
      ),
    );
  }
}

class _WeeklyOrdersChart extends StatelessWidget {
  final bool isDark;

  const _WeeklyOrdersChart({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Thống kê đơn theo tuần', isDark: isDark),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                minY: 0,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= weeklyOrderStats.length) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            weeklyOrderStats[index].day,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value % 2 != 0) return const SizedBox.shrink();

                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color:
                          (isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight)
                              .withValues(alpha: 0.65),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(weeklyOrderStats.length, (index) {
                  final stat = weeklyOrderStats[index];
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 5,
                    barRods: [
                      _bar(stat.pending / 2, AppColors.chartPending),
                      _bar(stat.inProgress / 2, AppColors.chartInProgress),
                      _bar(stat.completed / 2, AppColors.chartCompleted),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Wrap(
              spacing: 16,
              children: [
                _LegendItem('Chờ xử lý', AppColors.chartPending),
                _LegendItem('Đang sửa', AppColors.chartInProgress),
                _LegendItem('Hoàn thành', AppColors.chartCompleted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BarChartRodData _bar(num value, Color color) {
    return BarChartRodData(
      toY: value.clamp(0, 10).toDouble(),
      color: color,
      width: 14,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    );
  }
}

class _StatusRatioCard extends StatelessWidget {
  final bool isDark;
  final bool wide;

  const _StatusRatioCard({required this.isDark, required this.wide});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Tỷ lệ trạng thái đơn', isDark: isDark),
          const SizedBox(height: 16),
          SizedBox(
            height: wide ? 240 : 185,
            child: Row(
              children: [
                Expanded(
                  flex: wide ? 3 : 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: wide ? 66 : 48,
                      startDegreeOffset: -80,
                      sections: [
                        _pie(statusStats.pending, AppColors.chartPending, wide),
                        _pie(
                          statusStats.inProgress,
                          AppColors.chartInProgress,
                          wide,
                        ),
                        _pie(
                          statusStats.completed,
                          AppColors.chartCompleted,
                          wide,
                        ),
                        _pie(
                          statusStats.delivered,
                          AppColors.chartDelivered,
                          wide,
                        ),
                      ],
                    ),
                  ),
                ),
                if (wide) ...[
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatusSummaryRow(
                          label: 'Chờ xử lý',
                          value: statusStats.pending,
                          color: AppColors.chartPending,
                          isDark: isDark,
                        ),
                        _StatusSummaryRow(
                          label: 'Đang sửa',
                          value: statusStats.inProgress,
                          color: AppColors.chartInProgress,
                          isDark: isDark,
                        ),
                        _StatusSummaryRow(
                          label: 'Hoàn thành',
                          value: statusStats.completed,
                          color: AppColors.chartCompleted,
                          isDark: isDark,
                        ),
                        _StatusSummaryRow(
                          label: 'Đã giao',
                          value: statusStats.delivered,
                          color: AppColors.chartDelivered,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!wide) ...[
            const SizedBox(height: 10),
            const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _LegendItem('Chờ xử lý', AppColors.chartPending),
                _LegendItem('Đang sửa', AppColors.chartInProgress),
                _LegendItem('Hoàn thành', AppColors.chartCompleted),
                _LegendItem('Đã giao', AppColors.chartDelivered),
              ],
            ),
          ],
        ],
      ),
    );
  }

  PieChartSectionData _pie(int value, Color color, bool wide) {
    return PieChartSectionData(
      value: value.toDouble().clamp(1, 100),
      color: color,
      radius: wide ? 34 : 24,
      title: '',
    );
  }
}

class _StatusSummaryRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const _StatusSummaryRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total =
        statusStats.pending +
        statusStats.inProgress +
        statusStats.completed +
        statusStats.delivered;
    final percent = total == 0 ? 0 : ((value / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              '$percent%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  final bool isDark;

  const _TodayAttendanceCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Chấm công hôm nay', isDark: isDark),
          const SizedBox(height: 12),
          ...mockAttendanceRecords.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.infoLight,
                    child: Text(
                      record.employeeName.characters.first,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.employeeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          record.checkIn ?? '--:--',
                          style: TextStyle(
                            fontSize: 11,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentOrdersCard extends StatelessWidget {
  final bool isDark;

  const _RecentOrdersCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      isDark: isDark,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Expanded(child: _SectionTitle('Đơn gần đây', isDark: isDark)),
                TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
              ],
            ),
          ),
          ...mockRepairOrders
              .take(4)
              .map((order) => _RecentOrderRow(order: order, isDark: isDark)),
        ],
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  final RepairOrder order;
  final bool isDark;

  const _RecentOrderRow({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.wrench,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.orderNumber} · ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 8),
          StatusBadge(status: order.status, size: 'sm'),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final bool isDark;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _Panel({
    required this.isDark,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.07),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionTitle(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

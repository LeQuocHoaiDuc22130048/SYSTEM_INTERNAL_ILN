import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<_NotificationItem> _currentNotifications;

  @override
  void initState() {
    super.initState();
    _currentNotifications = List.from(_notifications);
  }

  void _markAllAsRead() {
    setState(() {
      _currentNotifications = _currentNotifications.map((n) {
        return _NotificationItem(
          title: n.title,
          body: n.body,
          time: n.time,
          icon: n.icon,
          color: n.color,
          background: n.background,
          unread: false,
          highlight: n.highlight,
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.of(context).size.width > 760;
    final unreadCount = _currentNotifications.where((n) => n.unread).length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            wide ? 20 : 22,
            wide ? 22 : 16,
            wide ? 20 : 22,
            12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thông báo',
                              style: TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              unreadCount > 0
                                  ? '$unreadCount thông báo chưa đọc'
                                  : 'Không có thông báo mới',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (unreadCount > 0)
                        TextButton.icon(
                          onPressed: _markAllAsRead,
                          icon: const Icon(LucideIcons.checkCheck, size: 14),
                          label: const Text('Đọc tất cả'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_currentNotifications.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.bellOff,
                              size: 48,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bạn không có thông báo nào',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 7,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(_currentNotifications.length, (index) {
                          final item = _currentNotifications[index];
                          return Dismissible(
                            key: Key('${item.title}_${item.time}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.error,
                              child: const Icon(LucideIcons.trash2,
                                  color: Colors.white, size: 20),
                            ),
                            onDismissed: (direction) {
                              setState(() {
                                _currentNotifications.removeAt(index);
                              });
                            },
                            child: _NotificationTile(
                              item: item,
                              isDark: isDark,
                              showTopBorder: index != 0,
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  final Color background;
  final bool unread;
  final bool highlight;

  const _NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.background,
    this.unread = false,
    this.highlight = false,
  });
}

const _notifications = [
  _NotificationItem(
    title: 'Đơn mới tiếp nhận',
    body: 'ĐH-2024-0848 - Khách Nguyễn Thị Mai - Samsung Note 20 Ultra',
    time: '14:30 hôm nay',
    icon: LucideIcons.clipboardList,
    color: AppColors.primary,
    background: AppColors.infoLight,
    unread: true,
    highlight: true,
  ),
  _NotificationItem(
    title: 'Tài khoản chờ duyệt',
    body: 'Võ Minh Khoa (vmkhoa) đã đăng ký tài khoản, chờ phê duyệt',
    time: '13:15 hôm nay',
    icon: LucideIcons.userRoundPlus,
    color: AppColors.warning,
    background: AppColors.warningLight,
    unread: true,
    highlight: true,
  ),
  _NotificationItem(
    title: 'Bo mạch quá hạn',
    body: 'BD-003 đã được sử dụng 4 tiếng 30 phút, vượt quá 2 tiếng quy định',
    time: '12:30 hôm nay',
    icon: LucideIcons.circleAlert,
    color: AppColors.error,
    background: AppColors.errorLight,
    unread: true,
    highlight: true,
  ),
  _NotificationItem(
    title: 'Tài khoản chờ duyệt',
    body: 'Bùi Thị Hoa (bthoa) đã đăng ký tài khoản, chờ phê duyệt',
    time: '11:00 hôm nay',
    icon: LucideIcons.userRoundPlus,
    color: AppColors.warning,
    background: AppColors.warningLight,
  ),
  _NotificationItem(
    title: 'Được phân công đơn mới',
    body: 'Bạn được phân công xử lý ĐH-2024-0847 - MacBook Pro 14"',
    time: '09:15 hôm nay',
    icon: LucideIcons.userRoundCheck,
    color: AppColors.purple,
    background: AppColors.purpleLight,
  ),
  _NotificationItem(
    title: 'Đơn hoàn thành',
    body: 'ĐH-2024-0845 - Samsung Galaxy Tab S9 đã hoàn thành sửa chữa',
    time: '09:30 hôm nay',
    icon: LucideIcons.circleCheck,
    color: AppColors.success,
    background: AppColors.successLight,
  ),
  _NotificationItem(
    title: 'Đơn mới tiếp nhận',
    body: 'ĐH-2024-0846 - Khách Hoàng Minh Tuấn - iPhone 15 Pro Max',
    time: '07:15 hôm nay',
    icon: LucideIcons.clipboardList,
    color: AppColors.primary,
    background: AppColors.infoLight,
  ),
];

class _NotificationTile extends StatelessWidget {
  final _NotificationItem item;
  final bool isDark;
  final bool showTopBorder;

  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.showTopBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: item.highlight
            ? AppColors.infoLight.withValues(alpha: isDark ? 0.08 : 0.23)
            : Colors.transparent,
        border: Border(
          top: BorderSide(
            color: showTopBorder
                ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                : Colors.transparent,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.background,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 15, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.time,
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
          if (item.unread) ...[
            const SizedBox(width: 10),
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 7, color: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

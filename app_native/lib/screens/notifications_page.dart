import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../theme/app_colors.dart';
import '../utils/notification_provider.dart';

class NotificationsPage extends StatefulWidget {
  final Function(int, {String? refId, int? subTab})? onNavigateToTab;

  const NotificationsPage({super.key, this.onNavigateToTab});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<NotificationProvider>();
    Future.microtask(provider.loadNotifications);
  }

  void _handleNotificationTap(AppNotification item) {
    if (widget.onNavigateToTab == null) return;

    final type = item.type;
    final refType = item.refType;
    final refId = item.refId;

    if (type == 'NEW_MESSAGE' || refType == 'CONVERSATION') {
      widget.onNavigateToTab!(4, refId: refId);
    } else if (type.startsWith('ORDER_') || type.startsWith('NEW_REPAIR_') || refType == 'REPAIR_ORDER') {
      widget.onNavigateToTab!(1, refId: refId);
    } else if (type.startsWith('ACCOUNT_') || refType == 'USER') {
      widget.onNavigateToTab!(6, subTab: 1); // 1 = Account Approval tab
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width > 760;
    final unreadCount = provider.unreadCount;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.loadNotifications(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    _Header(
                      unreadCount: unreadCount,
                      isDark: isDark,
                      onMarkAllAsRead: unreadCount == 0
                          ? null
                          : provider.markAllAsRead,
                    ),
                    const SizedBox(height: 16),
                    if (provider.isLoading && provider.notifications.isEmpty)
                      const _LoadingState()
                    else if (provider.error != null &&
                        provider.notifications.isEmpty)
                      _ErrorState(
                        message: provider.error!,
                        onRetry: provider.loadNotifications,
                      )
                    else if (provider.notifications.isEmpty)
                      _EmptyState(isDark: isDark)
                    else
                      _NotificationList(
                        notifications: provider.notifications,
                        isDark: isDark,
                        onTap: (item) {
                          provider.markAsRead(item);
                          _handleNotificationTap(item);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int unreadCount;
  final bool isDark;
  final VoidCallback? onMarkAllAsRead;

  const _Header({
    required this.unreadCount,
    required this.isDark,
    required this.onMarkAllAsRead,
  });

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
        if (onMarkAllAsRead != null)
          TextButton.icon(
            onPressed: onMarkAllAsRead,
            icon: const Icon(LucideIcons.checkCheck, size: 14),
            label: const Text('Đọc tất cả'),
          ),
      ],
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<AppNotification> notifications;
  final bool isDark;
  final ValueChanged<AppNotification> onTap;

  const _NotificationList({
    required this.notifications,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(notifications.length, (index) {
          final item = notifications[index];
          return _NotificationTile(
            item: item,
            isDark: isDark,
            showTopBorder: index != 0,
            onTap: () => onTap(item),
          );
        }),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool isDark;
  final bool showTopBorder;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.isDark,
    required this.showTopBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _NotificationVisuals.fromType(item.type);
    final unread = !item.isRead;

    return Material(
      color: unread
          ? AppColors.infoLight.withValues(alpha: isDark ? 0.08 : 0.23)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
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
                  color: colors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(colors.icon, size: 15, color: colors.color),
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
                      item.relativeTime,
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
              if (unread) ...[
                const SizedBox(width: 10),
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 7, color: AppColors.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationVisuals {
  final IconData icon;
  final Color color;
  final Color background;

  const _NotificationVisuals({
    required this.icon,
    required this.color,
    required this.background,
  });

  factory _NotificationVisuals.fromType(String type) {
    switch (type) {
      case 'ACCOUNT_PENDING':
      case 'ACCOUNT_APPROVED':
      case 'ACCOUNT_REJECTED':
        return const _NotificationVisuals(
          icon: LucideIcons.userRoundPlus,
          color: AppColors.warning,
          background: AppColors.warningLight,
        );
      case 'ORDER_ASSIGNED':
        return const _NotificationVisuals(
          icon: LucideIcons.userRoundCheck,
          color: AppColors.purple,
          background: AppColors.purpleLight,
        );
      case 'ORDER_COMPLETED':
        return const _NotificationVisuals(
          icon: LucideIcons.circleCheck,
          color: AppColors.success,
          background: AppColors.successLight,
        );
      case 'ORDER_PRIORITY_CHANGED':
      case 'BOARD_OVERDUE':
        return const _NotificationVisuals(
          icon: LucideIcons.circleAlert,
          color: AppColors.error,
          background: AppColors.errorLight,
        );
      case 'NEW_MESSAGE':
        return const _NotificationVisuals(
          icon: LucideIcons.messageSquare,
          color: AppColors.primary,
          background: AppColors.infoLight,
        );
      case 'NEW_REPAIR_ORDER':
      case 'ORDER_STATUS_CHANGED':
      default:
        return const _NotificationVisuals(
          icon: LucideIcons.clipboardList,
          color: AppColors.primary,
          background: AppColors.infoLight,
        );
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(
              LucideIcons.cloudAlert,
              size: 46,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 15),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

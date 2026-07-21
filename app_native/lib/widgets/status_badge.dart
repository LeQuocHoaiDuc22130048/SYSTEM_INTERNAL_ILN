import 'package:flutter/material.dart';

import '../models/attendance.dart';
import '../models/board.dart';
import '../models/repair_order.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final dynamic status;
  final String? size;

  const StatusBadge({super.key, required this.status, this.size = 'md'});

  Map<String, dynamic> _getStatusConfig() {
    if (status is RepairOrderStatus) {
      switch (status as RepairOrderStatus) {
        case RepairOrderStatus.pending:
          return {
            'label': 'Chưa kiểm tra',
            'bgColor': const Color(0xFFF1F5F9),
            'textColor': const Color(0xFF64748B),
          };
        case RepairOrderStatus.waitingForCheck:
          return {
            'label': 'Chờ kiểm tra',
            'bgColor': const Color(0xFFFFEDD5),
            'textColor': const Color(0xFFD97706),
          };
        case RepairOrderStatus.checking:
          return {
            'label': 'Đang kiểm tra',
            'bgColor': const Color(0xFFE0F2FE),
            'textColor': const Color(0xFF0284C7),
          };
        case RepairOrderStatus.checked:
          return {
            'label': 'Đã kiểm tra',
            'bgColor': const Color(0xFFF3E8FF),
            'textColor': const Color(0xFF7E22CE),
          };
        case RepairOrderStatus.inProgress:
          return {
            'label': 'Đang sửa',
            'bgColor': const Color(0xFFFEF3C7),
            'textColor': const Color(0xFFD97706),
          };
        case RepairOrderStatus.completed:
          return {
            'label': 'Hoàn thành',
            'bgColor': AppColors.successLight,
            'textColor': AppColors.success,
          };
        case RepairOrderStatus.delivered:
          return {
            'label': 'Đã giao',
            'bgColor': const Color(0xFFE2E8F0),
            'textColor': const Color(0xFF475569),
          };
        case RepairOrderStatus.cancelled:
          return {
            'label': 'Đã trả',
            'bgColor': AppColors.errorLight,
            'textColor': AppColors.error,
          };
      }
    } else if (status is BoardStatus) {
      switch (status as BoardStatus) {
        case BoardStatus.available:
          return {
            'label': 'Sẵn sàng',
            'bgColor': AppColors.successLight,
            'textColor': AppColors.success,
          };
        case BoardStatus.checkedOut:
          return {
            'label': 'Đang dùng',
            'bgColor': AppColors.infoLight,
            'textColor': AppColors.info,
          };
        case BoardStatus.inRepair:
          return {
            'label': status.label,
            'bgColor': AppColors.infoLight,
            'textColor': AppColors.info,
          };
        case BoardStatus.damaged:
        case BoardStatus.lost:
          return {
            'label': status.label,
            'bgColor': AppColors.errorLight,
            'textColor': AppColors.error,
          };
        case BoardStatus.archived:
          return {
            'label': status.label,
            'bgColor': const Color(0xFFF1F5F9),
            'textColor': const Color(0xFF64748B),
          };
        case BoardStatus.maintenance:
          return {
            'label': 'Bảo trì',
            'bgColor': AppColors.warningLight,
            'textColor': AppColors.warning,
          };
      }
    } else if (status is AttendanceStatus) {
      switch (status as AttendanceStatus) {
        case AttendanceStatus.onTime:
          return {
            'label': 'Đúng giờ',
            'bgColor': AppColors.successLight,
            'textColor': AppColors.success,
          };
        case AttendanceStatus.late:
          return {
            'label': 'Muộn',
            'bgColor': AppColors.warningLight,
            'textColor': AppColors.warning,
          };
        case AttendanceStatus.absent:
          return {
            'label': 'Vắng',
            'bgColor': AppColors.errorLight,
            'textColor': AppColors.error,
          };
      }
    }

    return {
      'label': 'Không rõ',
      'bgColor': Colors.grey[200],
      'textColor': Colors.grey[700],
    };
  }

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();
    final isSmall = size == 'sm';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config['bgColor'],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config['label'],
        style: TextStyle(
          color: config['textColor'],
          fontSize: isSmall ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

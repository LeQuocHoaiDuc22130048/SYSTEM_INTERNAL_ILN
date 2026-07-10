import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/repair_order.dart';
import '../models/user.dart';
import '../models/app_permission.dart';
import '../theme/app_colors.dart';
import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../widgets/status_badge.dart';
import '../widgets/video_player_dialog.dart';
import '../widgets/image_preview_dialog.dart';

class RepairOrdersPage extends StatefulWidget {
  final String? targetOrderId;
  const RepairOrdersPage({super.key, this.targetOrderId});

  @override
  State<RepairOrdersPage> createState() => _RepairOrdersPageState();
}

class _RepairOrdersPageState extends State<RepairOrdersPage> {
  final ValueNotifier<RepairOrderStatus?> _filter = ValueNotifier(null);
  final ValueNotifier<String> _searchQuery = ValueNotifier('');
  final ValueNotifier<DateTime?> _dateFilter = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<BackendDataProvider>().loadRepairOrders();
      if (widget.targetOrderId != null) {
        _showOrderById(widget.targetOrderId!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RepairOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != null &&
        widget.targetOrderId != oldWidget.targetOrderId) {
      _showOrderById(widget.targetOrderId!);
    }
  }

  void _showOrderById(String id) {
    final orders = context.read<BackendDataProvider>().repairOrders;
    final matchIndex = orders.indexWhere((o) => o.id == id);
    if (matchIndex != -1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _OrderDetailSheet(order: orders[matchIndex]),
      );
    }
  }

  @override
  void dispose() {
    _searchQuery.dispose();
    _filter.dispose();
    _dateFilter.dispose();
    super.dispose();
  }

  void _showDatePickerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            width: 320,
            height: 380,
            child: CalendarDatePicker(
              initialDate: _dateFilter.value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              onDateChanged: (DateTime date) {
                setState(() {
                  _dateFilter.value = date;
                });
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  void _showCreateOrderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateOrderSheet(),
    );
  }

  List<RepairOrder> get _filteredOrders {
    final query = _searchQuery.value.toLowerCase();
    final currentFilter = _filter.value;
    final selectedDate = _dateFilter.value;
    final orders = context.read<BackendDataProvider>().repairOrders;
    return orders.where((order) {
      final matchesFilter =
          currentFilter == null || order.status == currentFilter;

      bool matchesDate = true;
      if (selectedDate != null) {
        matchesDate = order.createdAt.year == selectedDate.year &&
            order.createdAt.month == selectedDate.month &&
            order.createdAt.day == selectedDate.day;
      }

      final matchesSearch =
          query.isEmpty ||
          order.deviceName.toLowerCase().contains(query) ||
          order.orderNumber.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          (order.assignedToName ?? '').toLowerCase().contains(query) ||
          order.assigneeNames.any((name) => name.toLowerCase().contains(query));
      return matchesFilter && matchesSearch && matchesDate;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    final auth = context.watch<AuthProvider>();
    final orders = backend.repairOrders;
    final isEmployee = auth.role == UserRole.employee;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 20 : 22,
                    wide ? 22 : 16,
                    wide ? 20 : 22,
                    12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Đơn sửa chữa',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.textPrimaryDark
                                            : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${orders.length} đơn tổng cộng',
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
                              if (!isEmployee)
                                ElevatedButton.icon(
                                  onPressed: () => _showCreateOrderSheet(context),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Tạo đơn'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) =>
                                _searchQuery.value = value,
                            decoration: InputDecoration(
                              hintText:
                                  'Tìm theo mã đơn, thiết bị, khách, người sửa...',
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (_dateFilter.value != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: InputChip(
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                      side: const BorderSide(color: AppColors.primary),
                                      avatar: const Icon(Icons.date_range, size: 14, color: AppColors.primary),
                                      label: Text(
                                        DateFormat('dd/MM/yyyy').format(_dateFilter.value!),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      deleteIcon: const Icon(Icons.cancel, size: 16, color: AppColors.primary),
                                      onDeleted: () {
                                        setState(() {
                                          _dateFilter.value = null;
                                        });
                                      },
                                      onPressed: () => _showDatePickerDialog(context),
                                    ),
                                  )
                                else
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ActionChip(
                                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                                      side: BorderSide(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      ),
                                      avatar: Icon(
                                        Icons.calendar_today,
                                        size: 14,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                      label: Text(
                                        DateFormat('dd/MM/yyyy').format(DateTime.now()),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      onPressed: () => _showDatePickerDialog(context),
                                    ),
                                  ),
                                ...[
                                  _buildFilterChip('Tất cả', null),
                                  _buildFilterChip(
                                    'Chờ xử lý',
                                    RepairOrderStatus.pending,
                                  ),
                                  _buildFilterChip(
                                    'Đang sửa',
                                    RepairOrderStatus.inProgress,
                                  ),
                                  _buildFilterChip(
                                    'Hoàn thành',
                                    RepairOrderStatus.completed,
                                  ),
                                  _buildFilterChip(
                                    'Đã giao',
                                    RepairOrderStatus.delivered,
                                  ),
                                  _buildFilterChip(
                                    'Đã hủy',
                                    RepairOrderStatus.cancelled,
                                  ),
                                ]
                                .map(
                                  (child) => Padding(
                                    padding: const EdgeInsets.only(
                                      right: 8,
                                    ),
                                    child: child,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: backend.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : backend.error != null
                      ? _ErrorState(
                          message: backend.error!,
                          onRetry: () => context
                              .read<BackendDataProvider>()
                              .loadRepairOrders(),
                          isDark: isDark,
                        )
                      : AnimatedBuilder(
                          animation: Listenable.merge([_searchQuery, _filter, _dateFilter]),
                          builder: (context, _) {
                            final filtered = _filteredOrders;
                            if (filtered.isEmpty) {
                              return _EmptyOrders(isDark: isDark);
                            }
                            return ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                wide ? 20 : 22,
                                4,
                                wide ? 20 : 22,
                                24,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 980,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child:
                                          _OrderCard(
                                                order: filtered[index],
                                                isDark: isDark,
                                              )
                                              .animate(target: 1)
                                              .fadeIn(
                                                duration: 320.ms,
                                                delay: (index * 45).ms,
                                              )
                                              .slideY(
                                                begin: 0.08,
                                                end: 0,
                                                duration: 320.ms,
                                                delay: (index * 45).ms,
                                              ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, RepairOrderStatus? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orders = context.watch<BackendDataProvider>().repairOrders;
    final count = status == null
        ? orders.length
        : orders.where((order) => order.status == status).length;

    return ValueListenableBuilder<RepairOrderStatus?>(
      valueListenable: _filter,
      builder: (context, currentFilter, _) {
        final isSelected = currentFilter == status;
        return FilterChip(
          label: Text('$label  $count'),
          selected: isSelected,
          onSelected: (selected) => _filter.value = selected ? status : null,
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : const Color(0xFFF1F5F9),
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
          ),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RepairOrder order;
  final bool isDark;

  const _OrderCard({required this.order, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showOrderDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LucideIcons.wrench,
                    size: 19,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: order.status, size: 'sm'),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 560;
                final children = [
                  _InfoLine(
                    icon: Icons.person_outline,
                    label: 'Khách hàng',
                    value: order.customerName,
                    isDark: isDark,
                  ),
                  _InfoLine(
                    icon: Icons.phone_outlined,
                    label: 'SĐT khách',
                    value: order.customerPhone ?? 'Chưa có',
                    isDark: isDark,
                  ),
                  _InfoLine(
                    icon: Icons.engineering_outlined,
                    label: 'Người sửa',
                    value: order.assigneeNames.isNotEmpty
                        ? order.assigneeNames.join('\n')
                        : (order.assignedToName ?? 'Chưa phân công'),
                    isDark: isDark,
                    maxLines: null,
                  ),
                  _InfoLine(
                    icon: Icons.schedule,
                    label: 'Tiếp nhận',
                    value: DateFormat(
                      'dd/MM/yyyy HH:mm',
                    ).format(order.createdAt),
                    isDark: isDark,
                  ),
                ];

                if (!twoColumns) {
                  return Column(children: children);
                }

                return Wrap(
                  runSpacing: 10,
                  children: children
                      .map(
                        (child) => SizedBox(
                          width: constraints.maxWidth / 2,
                          child: child,
                        ),
                      )
                      .toList(),
                );
              },
            ),
            if (order.description != null) ...[
              const SizedBox(height: 12),
              Text(
                order.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrderDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailSheet(order: order),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final int? maxLines;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 13,
      color: isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight,
    );
    final valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 16,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: labelStyle,
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle,
              maxLines: maxLines,
              overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final RepairOrder order;

  const _OrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      LucideIcons.wrench,
                      size: 24,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 22),
              _DetailRow('Khách hàng', order.customerName),
              _DetailRow('SĐT khách', order.customerPhone ?? 'Chưa có'),
              _DetailRow(
                'Người sửa',
                order.assigneeNames.isNotEmpty
                    ? order.assigneeNames.join('\n')
                    : (order.assignedToName ?? 'Chưa phân công'),
              ),
              _DetailRow(
                'Ngày tạo',
                DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
              ),
              if (order.updatedAt != null)
                _DetailRow(
                  'Cập nhật',
                  DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt!),
                ),
              if (order.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Mô tả',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  order.description!,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
              if (order.media.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Đính kèm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.media.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final media = order.media[index];
                    final url = context
                        .read<BackendDataProvider>()
                        .api
                        .resolveUrl(media.url);
                    if (media.isVideo) {
                      return GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => VideoPlayerDialog(
                              videoUrl: url,
                              title: media.caption ?? 'Video đính kèm',
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: isDark ? AppColors.surfaceDark : Colors.grey[200],
                            child: const Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                                Positioned(
                                  bottom: 4,
                                  child: Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => ImagePreviewDialog(
                            imageUrl: url,
                            caption: media.caption,
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: isDark ? AppColors.surfaceDark : Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: isDark ? AppColors.surfaceDark : Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 20),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final updated = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _EditOrderSheet(order: order),
                        );
                        if (updated == true && context.mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          });
                        }
                      },
                      child: const Text('Chỉnh sửa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  final bool isDark;

  const _EmptyOrders({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.searchX,
            size: 44,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 14),
          Text(
            'Không tìm thấy đơn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thử thay đổi từ khóa hoặc bộ lọc',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 42, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditOrderSheet extends StatefulWidget {
  final RepairOrder order;

  const _EditOrderSheet({required this.order});

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  final _noteController = TextEditingController();
  final Set<String> _technicianIds = <String>{};
  String? _nextStatus;
  bool _saving = false;

  bool get _canAssign => context.read<AuthProvider>().can(AppPermission.assignRepairOrders);

  String get _currentStatusBackendCode {
    switch (widget.order.status) {
      case RepairOrderStatus.pending:
        return 'PENDING';
      case RepairOrderStatus.inProgress:
        return 'IN_PROGRESS';
      case RepairOrderStatus.completed:
        return 'COMPLETED';
      case RepairOrderStatus.delivered:
        return 'DELIVERED';
      case RepairOrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  @override
  void initState() {
    super.initState();
    _technicianIds.addAll(widget.order.assigneeIds);
    if (_technicianIds.isEmpty && widget.order.assignedToId != null) {
      _technicianIds.add(widget.order.assignedToId!);
    }
    _nextStatus = _currentStatusBackendCode;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> _availableStatuses() {
    return const [
      MapEntry('PENDING', 'Chờ xử lý'),
      MapEntry('IN_PROGRESS', 'Đang sửa'),
      MapEntry('COMPLETED', 'Hoàn thành'),
      MapEntry('DELIVERED', 'Đã giao'),
      MapEntry('CANCELLED', 'Đã hủy'),
    ];
  }

  Future<void> _save() async {
    final Set<String> originalIds = widget.order.assigneeIds.toSet();
    if (originalIds.isEmpty && widget.order.assignedToId != null) {
      originalIds.add(widget.order.assignedToId!);
    }

    final assignmentChanged = _canAssign &&
        (!originalIds.containsAll(_technicianIds) || !_technicianIds.containsAll(originalIds));

    if (assignmentChanged && _technicianIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ít nhất một người sửa.')));
      return;
    }
    final statusChanged = _nextStatus != null && _nextStatus != _currentStatusBackendCode;
    if (!assignmentChanged && !statusChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có thay đổi để lưu.')));
      return;
    }

    setState(() => _saving = true);
    final backend = context.read<BackendDataProvider>();
    final note = _noteController.text.trim();
    try {
      if (assignmentChanged) {
        await backend.assignRepairOrder(
          widget.order.id,
          technicianIds: _technicianIds.toList(),
          note: note.isEmpty ? null : note,
          reload: !statusChanged,
        );
      }
      if (statusChanged) {
        await backend.updateRepairOrderStatus(
          widget.order.id,
          status: _nextStatus!,
          note: note.isEmpty ? null : note,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật đơn sửa chữa thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backend = context.watch<BackendDataProvider>();
    User? assignedTechnician;
    for (final employee in backend.employees) {
      if (employee.id == widget.order.assignedToId) {
        assignedTechnician = employee;
        break;
      }
    }
    final technicians = backend.employees
        .where(
          (user) =>
              (user.role == UserRole.employee || user.role == UserRole.technician) &&
              user.status == UserStatus.active,
        )
        .toList();
    final statuses = _availableStatuses();

    return _KeyboardBottomPadding(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chỉnh sửa ${widget.order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Nhân viên đang sửa chữa',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (widget.order.assigneeIds.isEmpty && widget.order.assignedToId == null)
                  _AssignedTechnicianCard(
                    name: 'Chưa phân công',
                    employeeId: null,
                    department: null,
                    phone: null,
                    isAssigned: false,
                    isDark: isDark,
                  )
                else ...[
                  ...widget.order.assigneeIds.map((id) {
                    final tech = backend.employees.firstWhere(
                      (t) => t.id == id,
                      orElse: () => User(
                        id: id,
                        name: widget.order.assigneeNames.length > widget.order.assigneeIds.indexOf(id)
                            ? widget.order.assigneeNames[widget.order.assigneeIds.indexOf(id)]
                            : 'Kỹ thuật viên',
                        email: '',
                        employeeId: '',
                        role: UserRole.employee,
                        status: UserStatus.active,
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _AssignedTechnicianCard(
                        name: tech.name,
                        employeeId: tech.employeeId,
                        department: tech.department,
                        phone: tech.phone,
                        isAssigned: true,
                        isDark: isDark,
                      ),
                    );
                  }),
                  if (widget.order.assigneeIds.isEmpty && widget.order.assignedToId != null)
                    _AssignedTechnicianCard(
                      name: assignedTechnician?.name ?? widget.order.assignedToName ?? 'Kỹ thuật viên',
                      employeeId: assignedTechnician?.employeeId,
                      department: assignedTechnician?.department,
                      phone: assignedTechnician?.phone,
                      isAssigned: true,
                      isDark: isDark,
                    ),
                ],
                const SizedBox(height: 18),
                if (_canAssign) ...[
                  const Text(
                    'Phân công người sửa (Có thể chọn nhiều)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final selected = await showDialog<Set<String>>(
                        context: context,
                        builder: (context) {
                          return _TechnicianMultiSelectDialog(
                            technicians: technicians,
                            initialSelected: _technicianIds,
                            isDark: isDark,
                          );
                        },
                      );
                      if (selected != null) {
                        setState(() {
                          _technicianIds.clear();
                          _technicianIds.addAll(selected);
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _technicianIds.isEmpty
                                ? Text(
                                    'Chọn nhân viên',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  )
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: _technicianIds.map((id) {
                                      final name = backend.employees.firstWhere((t) => t.id == id, orElse: () => User(id: id, name: 'Kỹ thuật viên', email: '', employeeId: '', role: UserRole.employee, status: UserStatus.active)).name;
                                      return Chip(
                                        label: Text(
                                          name,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onDeleted: () {
                                          setState(() {
                                            _technicianIds.remove(id);
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Cập nhật trạng thái',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _nextStatus,
                  items: statuses
                      .map(
                        (status) => DropdownMenuItem(
                          value: status.key,
                          child: Text(status.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _nextStatus = value),
                  decoration: const InputDecoration(
                    hintText: 'Chọn trạng thái',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignedTechnicianCard extends StatelessWidget {
  final String name;
  final String? employeeId;
  final String? department;
  final String? phone;
  final bool isAssigned;
  final bool isDark;

  const _AssignedTechnicianCard({
    required this.name,
    required this.employeeId,
    required this.department,
    required this.phone,
    required this.isAssigned,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (employeeId != null && employeeId!.isNotEmpty) employeeId!,
      if (department != null && department!.isNotEmpty) department!,
      if (phone != null && phone!.isNotEmpty) phone!,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isAssigned
                ? AppColors.infoLight
                : const Color(0xFFF1F5F9),
            child: Icon(
              isAssigned
                  ? Icons.engineering_outlined
                  : Icons.person_off_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join(' - '),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateOrderSheet extends StatefulWidget {
  const _CreateOrderSheet();

  @override
  State<_CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<_CreateOrderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  final Set<String> _technicianIds = <String>{};
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();

  bool _isVideo(String path) {
    final lowercase = path.toLowerCase();
    return lowercase.endsWith('.mp4') ||
        lowercase.endsWith('.mov') ||
        lowercase.endsWith('.avi') ||
        lowercase.endsWith('.mkv') ||
        lowercase.endsWith('.webm');
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  Future<void> _pickMultiImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedMedias.addAll(pickedFiles);
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedMedias.add(pickedFile);
      });
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final backend = context.read<BackendDataProvider>();

    try {
      final order = await backend.createRepairOrder(
        customerName: _customerNameController.text.trim(),
        customerPhone: _customerPhoneController.text.replaceAll(
          RegExp(r'\D'),
          '',
        ),
        deviceName: _deviceNameController.text.trim(),
        description: _descriptionController.text.trim(),
      );
      for (final media in _selectedMedias) {
        await backend.uploadRepairMedia(
          order.id,
          bytes: await media.readAsBytes(),
          filename: media.name,
          isVideo: _isVideo(media.path),
        );
      }
      if (_technicianIds.isNotEmpty) {
        await backend.assignRepairOrder(
          order.id,
          technicianIds: _technicianIds.toList(),
          reload: false,
        );
      }
      await backend.loadRepairOrders();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tạo đơn sửa chữa thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deviceNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAssign = context.watch<AuthProvider>().can(AppPermission.assignRepairOrders);
    final technicians = context
        .watch<BackendDataProvider>()
        .employees
        .where(
          (user) =>
              (user.role == UserRole.employee || user.role == UserRole.technician) &&
              user.status == UserStatus.active,
        )
        .toList();

    return _KeyboardBottomPadding(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tạo đơn sửa chữa mới',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    context,
                    controller: _customerNameController,
                    label: 'Tên khách hàng',
                    hint: 'Nhập tên khách hàng',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context,
                    controller: _customerPhoneController,
                    label: 'Số điện thoại',
                    hint: '0901 234 567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context,
                    controller: _deviceNameController,
                    label: 'Tên thiết bị',
                    hint: 'iPhone 15 Pro Max, MacBook Pro...',
                    icon: Icons.smartphone_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context,
                    controller: _descriptionController,
                    label: 'Tình trạng lỗi',
                    hint: 'Mô tả chi tiết lỗi thiết bị',
                    icon: Icons.error_outline,
                    maxLines: 3,
                  ),
                  if (canAssign) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Phân công người sửa (Có thể chọn nhiều)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final selected = await showDialog<Set<String>>(
                          context: context,
                          builder: (context) {
                            return _TechnicianMultiSelectDialog(
                              technicians: technicians,
                              initialSelected: _technicianIds,
                              isDark: isDark,
                            );
                          },
                        );
                        if (selected != null) {
                          setState(() {
                            _technicianIds.clear();
                            _technicianIds.addAll(selected);
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _technicianIds.isEmpty
                                  ? Text(
                                      'Chọn nhân viên (không bắt buộc)',
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _technicianIds.map((id) {
                                        final name = technicians.firstWhere((t) => t.id == id, orElse: () => User(id: id, name: 'Kỹ thuật viên', email: '', employeeId: '', role: UserRole.employee, status: UserStatus.active)).name;
                                        return Chip(
                                          label: Text(
                                            name,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          onDeleted: () {
                                            setState(() {
                                              _technicianIds.remove(id);
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Đính kèm hình ảnh hoặc video',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedMedias.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedMedias.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final file = _selectedMedias[index];
                          final isVideo = _isVideo(file.path);
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isVideo
                                    ? Container(
                                        width: 120,
                                        height: 120,
                                        color: AppColors.infoLight.withOpacity(0.2),
                                        child: const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.play_circle_outline, size: 36, color: AppColors.primary),
                                            SizedBox(height: 4),
                                            Text('Video', style: TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      )
                                    : Image.file(
                                        File(file.path),
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedMedias.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Chụp ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickMultiImages,
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Chọn nhiều ảnh'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.videocam_outlined, size: 18),
                        label: const Text('Chọn video'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Tạo đơn hàng'),
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

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Trường này không được để trống';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _KeyboardBottomPadding extends StatelessWidget {
  final Widget child;

  const _KeyboardBottomPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: child,
    );
  }
}

class _TechnicianMultiSelectDialog extends StatefulWidget {
  final List<User> technicians;
  final Set<String> initialSelected;
  final bool isDark;

  const _TechnicianMultiSelectDialog({
    required this.technicians,
    required this.initialSelected,
    required this.isDark,
  });

  @override
  State<_TechnicianMultiSelectDialog> createState() => _TechnicianMultiSelectDialogState();
}

class _TechnicianMultiSelectDialogState extends State<_TechnicianMultiSelectDialog> {
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn kỹ thuật viên'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.technicians.isEmpty
              ? [const Padding(padding: EdgeInsets.all(16), child: Text('Không có kỹ thuật viên khả dụng.'))]
              : widget.technicians.map((tech) {
                  final isChecked = _selected.contains(tech.id);
                  return CheckboxListTile(
                    title: Text(tech.name),
                    subtitle: Text(tech.employeeId.isNotEmpty ? tech.employeeId : tech.role.label),
                    value: isChecked,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _selected.add(tech.id);
                        } else {
                          _selected.remove(tech.id);
                        }
                      });
                    },
                  );
                }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Chọn'),
        ),
      ],
    );
  }
}

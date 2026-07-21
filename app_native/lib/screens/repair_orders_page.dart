import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../models/repair_device.dart';
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
  final ValueNotifier<bool?> _warrantyFilter = ValueNotifier(null);
  final ValueNotifier<int> _currentPage = ValueNotifier(1);
  static const int _pageSize = 10;

  void _resetPage() {
    _currentPage.value = 1;
  }

  @override
  void initState() {
    super.initState();
    _filter.addListener(_resetPage);
    _searchQuery.addListener(_resetPage);
    _dateFilter.addListener(_resetPage);
    _warrantyFilter.addListener(_resetPage);

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
    _filter.removeListener(_resetPage);
    _searchQuery.removeListener(_resetPage);
    _dateFilter.removeListener(_resetPage);
    _warrantyFilter.removeListener(_resetPage);

    _searchQuery.dispose();
    _filter.dispose();
    _dateFilter.dispose();
    _warrantyFilter.dispose();
    _currentPage.dispose();
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
    final backend = context.read<BackendDataProvider>();
    final currentFilter = _filter.value;
    final selectedDate = _dateFilter.value;
    final warrantyVal = _warrantyFilter.value;
    final query = _searchQuery.value.trim().toLowerCase();

    return backend.repairOrders.where((order) {
      final matchesFilter =
          currentFilter == null || order.status == currentFilter;
      final matchesSearch = query.isEmpty ||
          order.orderNumber.toLowerCase().contains(query) ||
          order.deviceName.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          (order.customerPhone ?? '').contains(query);

      final matchesDate = selectedDate == null ||
          (order.createdAt.year == selectedDate.year &&
              order.createdAt.month == selectedDate.month &&
              order.createdAt.day == selectedDate.day);

      final matchesWarranty = warrantyVal == null ||
          order.underWarranty == warrantyVal;

      return matchesFilter && matchesSearch && matchesDate && matchesWarranty;
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
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: _buildWarrantyFilterChip('Bảo hành', true),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: _buildWarrantyFilterChip('Không BH', false),
                                ),
                                ...[
                                  _buildFilterChip('Tất cả', null),
                                  _buildFilterChip(
                                    'Chưa kiểm tra',
                                    RepairOrderStatus.pending,
                                  ),
                                  _buildFilterChip(
                                    'Chờ kiểm tra',
                                    RepairOrderStatus.waitingForCheck,
                                  ),
                                  _buildFilterChip(
                                    'Đang kiểm tra',
                                    RepairOrderStatus.checking,
                                  ),
                                  _buildFilterChip(
                                    'Đã kiểm tra',
                                    RepairOrderStatus.checked,
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
                          animation: Listenable.merge([
                            _searchQuery,
                            _filter,
                            _dateFilter,
                            _warrantyFilter,
                            _currentPage,
                          ]),
                          builder: (context, _) {
                            final filtered = _filteredOrders;
                            final totalItems = filtered.length;
                            final totalPages = (totalItems / _pageSize).ceil();
                            final currentPageVal = _currentPage.value;
                            
                            final validPage = currentPageVal > totalPages
                                ? (totalPages > 0 ? totalPages : 1)
                                : currentPageVal;

                            final startIndex = (validPage - 1) * _pageSize;
                            final endIndex = startIndex + _pageSize;
                            final pageItems = filtered.sublist(
                              startIndex,
                              endIndex > totalItems ? totalItems : endIndex,
                            );

                            if (filtered.isEmpty) {
                              return RefreshIndicator(
                                onRefresh: () => context
                                    .read<BackendDataProvider>()
                                    .loadRepairOrders(),
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height: constraints.maxHeight - 200,
                                      child: _EmptyOrders(isDark: isDark),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return RefreshIndicator(
                              onRefresh: () => context
                                  .read<BackendDataProvider>()
                                  .loadRepairOrders(),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  wide ? 20 : 22,
                                  4,
                                  wide ? 20 : 22,
                                  24,
                                ),
                                itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == pageItems.length) {
                                    return _buildPaginationControl(
                                      validPage,
                                      totalPages,
                                      isDark,
                                      wide,
                                    );
                                  }
                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 980,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _OrderCard(
                                          order: pageItems[index],
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
                              ),
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

  Widget _buildWarrantyFilterChip(String label, bool? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orders = context.watch<BackendDataProvider>().repairOrders;
    
    return ValueListenableBuilder<RepairOrderStatus?>(
      valueListenable: _filter,
      builder: (context, currentStatusFilter, _) {
        final count = value == null
            ? orders.where((order) => currentStatusFilter == null || order.status == currentStatusFilter).length
            : orders.where((order) => order.underWarranty == value && (currentStatusFilter == null || order.status == currentStatusFilter)).length;

        return ValueListenableBuilder<bool?>(
          valueListenable: _warrantyFilter,
          builder: (context, currentFilter, _) {
            final isSelected = currentFilter == value;
            return FilterChip(
              label: Text('$label  $count'),
              selected: isSelected,
              onSelected: (selected) {
                _warrantyFilter.value = selected ? value : null;
              },
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, RepairOrderStatus? status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orders = context.watch<BackendDataProvider>().repairOrders;

    return ValueListenableBuilder<bool?>(
      valueListenable: _warrantyFilter,
      builder: (context, currentWarrantyFilter, _) {
        final count = status == null
            ? orders.where((order) => currentWarrantyFilter == null || order.underWarranty == currentWarrantyFilter).length
            : orders.where((order) => order.status == status && (currentWarrantyFilter == null || order.underWarranty == currentWarrantyFilter)).length;

        return ValueListenableBuilder<RepairOrderStatus?>(
          valueListenable: _filter,
          builder: (context, currentFilter, _) {
            final isSelected = currentFilter == status;
            return FilterChip(
              label: Text('$label  $count'),
              selected: isSelected,
              onSelected: (selected) {
                _filter.value = selected ? status : null;
                if (status == null) {
                  _warrantyFilter.value = null;
                }
              },
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        );
      },
    );
  }

  List<dynamic> _getPageNumbers(int current, int total) {
    if (total <= 5) {
      return List.generate(total, (i) => i + 1);
    }
    final List<dynamic> pages = [];
    pages.add(1);
    
    int start = current - 1;
    int end = current + 1;
    
    if (start <= 2) {
      start = 2;
      end = 4;
    } else if (end >= total - 1) {
      start = total - 3;
      end = total - 1;
    }
    
    if (start > 2) {
      pages.add(null); // ellipsis
    }
    
    for (int i = start; i <= end; i++) {
      pages.add(i);
    }
    
    if (end < total - 1) {
      pages.add(null); // ellipsis
    }
    
    pages.add(total);
    return pages;
  }

  Widget _buildPaginationControl(int currentPage, int totalPages, bool isDark, bool wide) {
    final pageNumbers = _getPageNumbers(currentPage, totalPages);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nút Previous
              OutlinedButton(
                onPressed: currentPage > 1
                    ? () => _currentPage.value = currentPage - 1
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 16 : 8,
                    vertical: 8,
                  ),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chevron_left, size: 18),
                    if (wide) ...[
                      const SizedBox(width: 4),
                      const Text('Trước'),
                    ],
                  ],
                ),
              ),
              
              // Các số trang
              Row(
                mainAxisSize: MainAxisSize.min,
                children: pageNumbers.map((p) {
                  if (p == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        '...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    );
                  }
                  
                  final isCurrent = p == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: TextButton(
                        onPressed: isCurrent ? null : () => _currentPage.value = p,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: isCurrent
                              ? AppColors.primary
                              : Colors.transparent,
                          foregroundColor: isCurrent
                              ? Colors.white
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isCurrent
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight),
                            ),
                          ),
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Nút Next
              OutlinedButton(
                onPressed: currentPage < totalPages
                    ? () => _currentPage.value = currentPage + 1
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 16 : 8,
                    vertical: 8,
                  ),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (wide) ...[
                      const Text('Sau'),
                      const SizedBox(width: 4),
                    ],
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isWarrantyValid(DateTime? expiry) {
  if (expiry == null) return true;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final expiryDate = DateTime(expiry.year, expiry.month, expiry.day);
  return !expiryDate.isBefore(today);
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: order.status, size: 'sm'),
                    if (order.devices.any((d) => d.underWarranty)) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: order.devices.any((d) => d.underWarranty && _isWarrantyValid(d.warrantyExpiry))
                              ? AppColors.successLight
                              : AppColors.errorLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.devices.any((d) => d.underWarranty && _isWarrantyValid(d.warrantyExpiry))
                              ? 'Còn hạn'
                              : 'Hết hạn',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: order.devices.any((d) => d.underWarranty && _isWarrantyValid(d.warrantyExpiry))
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
                    ).format(order.createdAt.toLocal()),
                    isDark: isDark,
                  ),
                  if (order.serialNumber != null && order.serialNumber!.isNotEmpty)
                    _InfoLine(
                      icon: Icons.tag,
                      label: 'Số seri',
                      value: order.serialNumber!,
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Xóa đơn sửa chữa'),
        content: Text('Bạn có chắc chắn muốn xóa đơn sửa chữa ${order.orderNumber}? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await context.read<BackendDataProvider>().deleteRepairOrder(order.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xóa đơn sửa chữa thành công'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Xóa thất bại: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canDelete = context.watch<AuthProvider>().can(AppPermission.manageRepairOrders);

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
              if (order.devices.length <= 1) ...[
                _DetailRow(
                  'Số seri',
                  order.devices.isNotEmpty
                      ? (order.devices.first.serialNumber ?? 'Không có')
                      : (order.serialNumber ?? 'Không có'),
                ),
                _DetailRow(
                  'Bảo hành',
                  () {
                    final isUnderWarranty = order.devices.isNotEmpty
                        ? order.devices.first.underWarranty
                        : order.underWarranty;
                    final expiry = order.devices.isNotEmpty
                        ? order.devices.first.warrantyExpiry
                        : null;
                    if (!isUnderWarranty) return 'Không bảo hành';
                    final isValid = _isWarrantyValid(expiry);
                    final expiryStr = expiry != null
                        ? DateFormat('dd/MM/yyyy').format(expiry)
                        : 'Không rõ';
                    return '$expiryStr (${isValid ? "Còn hạn" : "Hết hạn"})';
                  }(),
                ),
                if (order.devices.isNotEmpty &&
                    order.devices.first.description != null &&
                    order.devices.first.description!.isNotEmpty)
                  _DetailRow('Mô tả lỗi', order.devices.first.description!)
                else if (order.description != null &&
                    order.description!.isNotEmpty)
                  _DetailRow('Mô tả lỗi', order.description!),
              ],
              _DetailRow(
                'Người sửa (đơn)',
                order.assigneeNames.isNotEmpty
                    ? order.assigneeNames.join('\n')
                    : (order.assignedToName ?? 'Chưa phân công'),
              ),
              _DetailRow(
                'Ngày tạo',
                DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt.toLocal()),
              ),
              if (order.updatedAt != null)
                _DetailRow(
                  'Cập nhật',
                  DateFormat('dd/MM/yyyy HH:mm').format(order.updatedAt!.toLocal()),
                ),
              if (order.notes != null && order.notes!.isNotEmpty)
                _DetailRow(
                  'Ghi chú',
                  order.notes!,
                ),
              if (order.devices.length > 1) ...[
                const SizedBox(height: 20),
                // ── Danh sách thiết bị (Legacy) ─────────────────
                Text(
                  'Thiết bị (${order.devices.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...order.devices.asMap().entries.map((e) => _DeviceDetailCard(
                  isDark: isDark,
                  index: e.key,
                  deviceName: e.value.deviceName,
                  serialNumber: e.value.serialNumber,
                  underWarranty: e.value.underWarranty,
                  warrantyExpiry: e.value.warrantyExpiry,
                  description: e.value.description,
                  assignedToName: e.value.assignedToName,
                  statusLabel: e.value.statusLabel,
                )),
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
              if (canDelete) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Xóa đơn hàng'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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

class _DeviceDetailCard extends StatelessWidget {
  final bool isDark;
  final int index;
  final String deviceName;
  final String? serialNumber;
  final bool underWarranty;
  final DateTime? warrantyExpiry;
  final String? description;
  final String? assignedToName;
  final String? statusLabel;

  const _DeviceDetailCard({
    required this.isDark,
    required this.index,
    required this.deviceName,
    this.serialNumber,
    this.underWarranty = false,
    this.warrantyExpiry,
    this.description,
    this.assignedToName,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.precision_manufacturing_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thiết bị ${index + 1}: $deviceName',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: underWarranty
                            ? AppColors.infoLight
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        underWarranty ? 'Bảo hành' : 'Không BH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: underWarranty ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (underWarranty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isWarrantyValid(warrantyExpiry)
                              ? AppColors.successLight
                              : AppColors.errorLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isWarrantyValid(warrantyExpiry) ? 'Còn hạn' : 'Hết hạn',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isWarrantyValid(warrantyExpiry)
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (serialNumber != null && serialNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.tag, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Số seri: $serialNumber',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
            if (underWarranty && warrantyExpiry != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: !_isWarrantyValid(warrantyExpiry) ? AppColors.error : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hạn bảo hành: ${DateFormat('dd/MM/yyyy').format(warrantyExpiry!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: !_isWarrantyValid(warrantyExpiry)
                          ? AppColors.error
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      fontWeight: !_isWarrantyValid(warrantyExpiry) ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (!_isWarrantyValid(warrantyExpiry)) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '(Hết hạn)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (assignedToName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Phụ trách: $assignedToName',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
            if (statusLabel != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customerNameController;
  late final TextEditingController _customerPhoneController;
  late final TextEditingController _noteController;
  final Set<String> _technicianIds = <String>{};
  String? _nextStatus;
  bool _saving = false;

  // Danh sách thiết bị
  final List<_DeviceFormEntry> _deviceEntries = [];

  // Danh sách hình ảnh/video chọn mới
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();
  // Danh sách media ID muốn xóa
  final Set<String> _deletedMediaIds = {};

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

  bool get _canAssign => context.read<AuthProvider>().can(AppPermission.assignRepairOrders);

  String get _currentStatusBackendCode {
    switch (widget.order.status) {
      case RepairOrderStatus.pending:
        return 'PENDING';
      case RepairOrderStatus.waitingForCheck:
        return 'WAITING_FOR_CHECK';
      case RepairOrderStatus.checking:
        return 'CHECKING';
      case RepairOrderStatus.checked:
        return 'CHECKED';
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
    _customerNameController = TextEditingController(text: widget.order.customerName);
    _customerPhoneController = TextEditingController(text: widget.order.customerPhone ?? '');
    _noteController = TextEditingController(text: widget.order.notes ?? '');

    // Khởi tạo device entries từ dữ liệu đơn hiện tại
    if (widget.order.devices.isNotEmpty) {
      for (final d in widget.order.devices) {
        final entry = _DeviceFormEntry(initialName: d.deviceName);
        entry.serialController.text = d.serialNumber ?? '';
        entry.descController.text = d.description ?? '';
        entry.underWarranty = d.underWarranty;
        entry.warrantyExpiry = d.warrantyExpiry;

        // Tự động khôi phục ngày bảo hành (warrantyStartDate) từ ngày hết hạn
        if (d.warrantyExpiry != null) {
          final expiry = d.warrantyExpiry!;
          final createdAt = widget.order.createdAt;

          DateTime subtractMonths(DateTime date, int months) {
            int targetYear = date.year;
            int targetMonth = date.month - months;
            while (targetMonth <= 0) {
              targetYear -= 1;
              targetMonth += 12;
            }
            final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
            final day = date.day > lastDay ? lastDay : date.day;
            return DateTime(targetYear, targetMonth, day);
          }

          final start6 = subtractMonths(expiry, 6);
          final start12 = subtractMonths(expiry, 12);

          final diff6 = (start6.difference(createdAt).inDays).abs();
          final diff12 = (start12.difference(createdAt).inDays).abs();

          entry.warrantyStartDate = diff6 < diff12 ? start6 : start12;
        }

        entry.assignedToId = d.assignedToId;
        entry.assignedToName = d.assignedToName;
        _deviceEntries.add(entry);
      }
    } else {
      // Fallback: tạo 1 entry từ các field cũ của đơn
      final entry = _DeviceFormEntry(initialName: widget.order.deviceName);
      entry.serialController.text = widget.order.serialNumber ?? '';
      entry.descController.text = widget.order.description ?? '';
      entry.underWarranty = widget.order.underWarranty;
      _deviceEntries.add(entry);
    }

    _technicianIds.addAll(widget.order.assigneeIds);
    if (_technicianIds.isEmpty && widget.order.assignedToId != null) {
      _technicianIds.add(widget.order.assignedToId!);
    }
    _nextStatus = _currentStatusBackendCode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canAssign) {
        final backend = context.read<BackendDataProvider>();
        if (backend.employees.isEmpty) {
          backend.loadEmployees();
        }
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    for (final e in _deviceEntries) {
      e.dispose();
    }
    super.dispose();
  }

  List<MapEntry<String, String>> _availableStatuses() {
    return const [
      MapEntry('PENDING', 'Chưa kiểm tra'),
      MapEntry('WAITING_FOR_CHECK', 'Chờ kiểm tra'),
      MapEntry('CHECKING', 'Đang kiểm tra'),
      MapEntry('CHECKED', 'Đã kiểm tra'),
      MapEntry('IN_PROGRESS', 'Đang sửa'),
      MapEntry('COMPLETED', 'Hoàn thành'),
      MapEntry('DELIVERED', 'Đã giao'),
      MapEntry('CANCELLED', 'Đã hủy'),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final Set<String> originalIds = widget.order.assigneeIds.toSet();
    if (originalIds.isEmpty && widget.order.assignedToId != null) {
      originalIds.add(widget.order.assignedToId!);
    }

    bool infoChanged = _customerNameController.text.trim() != widget.order.customerName ||
        _customerPhoneController.text.replaceAll(RegExp(r'\D'), '') != (widget.order.customerPhone ?? '').replaceAll(RegExp(r'\D'), '');

    if (!infoChanged) {
      if (_deviceEntries.length != widget.order.devices.length) {
        infoChanged = true;
      } else {
        for (int i = 0; i < _deviceEntries.length; i++) {
          final entry = _deviceEntries[i];
          final orig = widget.order.devices[i];
          if (entry.nameController.text.trim() != orig.deviceName ||
              (entry.serialController.text.trim().isEmpty ? null : entry.serialController.text.trim()) != orig.serialNumber ||
              entry.underWarranty != orig.underWarranty ||
              entry.warrantyExpiry != orig.warrantyExpiry ||
              (entry.descController.text.trim().isEmpty ? null : entry.descController.text.trim()) != orig.description ||
              entry.assignedToId != orig.assignedToId) {
            infoChanged = true;
            break;
          }
        }
      }
    }

    final assignmentChanged = _canAssign &&
        (!originalIds.containsAll(_technicianIds) || !_technicianIds.containsAll(originalIds));

    final mediaChanged = _selectedMedias.isNotEmpty || _deletedMediaIds.isNotEmpty;
    final statusChanged = _nextStatus != null && _nextStatus != _currentStatusBackendCode;
    final note = _noteController.text.trim();
    final noteChanged = note != (widget.order.notes ?? '');

    if (!assignmentChanged && !statusChanged && !infoChanged && !mediaChanged && !noteChanged) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có thay đổi để lưu.')));
      return;
    }

    setState(() => _saving = true);
    final backend = context.read<BackendDataProvider>();
    try {
      if (infoChanged || noteChanged) {
        await backend.updateRepairOrder(
          widget.order.id,
          customerName: _customerNameController.text.trim(),
          customerPhone: _customerPhoneController.text.replaceAll(RegExp(r'\D'), ''),
          devices: _deviceEntries.map((e) => RepairDevice(
            id: '',
            deviceName: e.nameController.text.trim(),
            serialNumber: e.serialController.text.trim().isEmpty ? null : e.serialController.text.trim(),
            underWarranty: e.underWarranty,
            warrantyExpiry: e.underWarranty ? e.warrantyExpiry : null,
            description: e.descController.text.trim().isEmpty ? null : e.descController.text.trim(),
            assignedToId: e.assignedToId,
          )).toList(),
          note: note,
          reload: !assignmentChanged && !statusChanged && !mediaChanged,
        );
      }
      if (assignmentChanged) {
        await backend.assignRepairOrder(
          widget.order.id,
          technicianIds: _technicianIds.toList(),
          note: note.isEmpty ? null : note,
          reload: !statusChanged && !mediaChanged,
        );
      }
      if (statusChanged) {
        await backend.updateRepairOrderStatus(
          widget.order.id,
          status: _nextStatus!,
          note: note.isEmpty ? null : note,
        );
      }
      if (_deletedMediaIds.isNotEmpty) {
        for (final mediaId in _deletedMediaIds) {
          await backend.deleteRepairMedia(widget.order.id, mediaId: mediaId, reload: false);
        }
      }
      if (_selectedMedias.isNotEmpty) {
        for (final media in _selectedMedias) {
          await backend.uploadRepairMedia(
            widget.order.id,
            bytes: await media.readAsBytes(),
            filename: media.name,
            isVideo: _isVideo(media.path),
          );
        }
      }
      if (mediaChanged) {
        await backend.loadRepairOrders();
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

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool required = true,
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
            if (required && (value == null || value.isEmpty)) {
              return 'Trường này không được để trống';
            }
            return null;
          },
        ),
      ],
    );
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
            child: Form(
              key: _formKey,
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
                    required: false,
                  ),
                  const SizedBox(height: 16),
                  // ── Danh sách thiết bị ─────────────────────
                  Text(
                    'Thiết bị sửa chữa',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_deviceEntries.length, (index) {
                    final entry = _deviceEntries[index];
                    return _DeviceFormCard(
                      key: ValueKey(entry.id),
                      index: index,
                      entry: entry,
                      isDark: isDark,
                      canAssign: _canAssign,
                      technicians: technicians,
                      canRemove: _deviceEntries.length > 1,
                      onRemove: () => setState(() => _deviceEntries.removeAt(index)),
                      onChanged: () => setState(() {}),
                      orderCreatedAt: widget.order.createdAt,
                    );
                  }),
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
                    'Đính kèm hình ảnh hoặc video',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.order.media.where((m) => !_deletedMediaIds.contains(m.id)).isNotEmpty || _selectedMedias.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...widget.order.media.where((m) => !_deletedMediaIds.contains(m.id)).map((m) {
                            final url = backend.api.resolveUrl(m.url);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: m.isVideo
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
                                        : Image.network(
                                            url,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 120,
                                              height: 120,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.broken_image),
                                            ),
                                          ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _deletedMediaIds.add(m.id)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          ..._selectedMedias.asMap().entries.map((e) {
                            final index = e.key;
                            final file = e.value;
                            final isVideo = _isVideo(file.path);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
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
                                                Text('Video mới', style: TextStyle(fontSize: 11)),
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
                              ),
                            );
                          }),
                        ],
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
                  const SizedBox(height: 20),
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
  bool _isLoading = false;
  final Set<String> _technicianIds = <String>{};
  final List<XFile> _selectedMedias = [];
  final ImagePicker _picker = ImagePicker();

  // Danh sách thiết bị — mỗi phần tử giữ các controller của 1 thiết bị
  final List<_DeviceFormEntry> _deviceEntries = [];

  @override
  void initState() {
    super.initState();
    _deviceEntries.add(_DeviceFormEntry()); // Ít nhất 1 thiết bị
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final canAssign = context.read<AuthProvider>().can(AppPermission.assignRepairOrders);
        if (canAssign) {
          final backend = context.read<BackendDataProvider>();
          if (backend.employees.isEmpty) {
            backend.loadEmployees();
          }
        }
      }
    });
  }

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
        customerPhone: _customerPhoneController.text.replaceAll(RegExp(r'\D'), ''),
        devices: _deviceEntries.map((e) => RepairDevice(
          id: '',
          deviceName: e.nameController.text.trim(),
          serialNumber: e.serialController.text.trim().isEmpty ? null : e.serialController.text.trim(),
          underWarranty: e.underWarranty,
          warrantyExpiry: e.underWarranty ? e.warrantyExpiry : null,
          description: e.descController.text.trim().isEmpty ? null : e.descController.text.trim(),
          assignedToId: e.assignedToId,
        )).toList(),
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
    for (final e in _deviceEntries) {
      e.dispose();
    }
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
                    required: false,
                  ),
                  const SizedBox(height: 16),
                  // ── Danh sách thiết bị ─────────────────────
                  ...List.generate(_deviceEntries.length, (index) {
                    final entry = _deviceEntries[index];
                    return _DeviceFormCard(
                      key: ValueKey(entry.id),
                      index: index,
                      entry: entry,
                      isDark: isDark,
                      canAssign: canAssign,
                      technicians: technicians,
                      canRemove: _deviceEntries.length > 1,
                      onRemove: () => setState(() => _deviceEntries.removeAt(index)),
                      onChanged: () => setState(() {}),
                      orderCreatedAt: null,
                    );
                  }),
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
    bool required = true,
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
            if (required && (value == null || value.isEmpty)) {
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

// ─── Helper: State cho một thiết bị trong form ─────────────────────────────

class _DeviceFormEntry {
  final String id = UniqueKey().toString();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController serialController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  bool underWarranty = false;
  DateTime? warrantyExpiry;
  DateTime? warrantyStartDate;
  String? assignedToId;
  String? assignedToName;

  _DeviceFormEntry({String? initialName}) {
    if (initialName != null) nameController.text = initialName;
  }

  void dispose() {
    nameController.dispose();
    serialController.dispose();
    descController.dispose();
  }
}

// ─── Widget: Card form cho một thiết bị ────────────────────────────────────

class _DeviceFormCard extends StatefulWidget {
  final int index;
  final _DeviceFormEntry entry;
  final bool isDark;
  final bool canAssign;
  final List<User> technicians;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final DateTime? orderCreatedAt;

  const _DeviceFormCard({
    super.key,
    required this.index,
    required this.entry,
    required this.isDark,
    required this.canAssign,
    required this.technicians,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    this.orderCreatedAt,
  });

  @override
  State<_DeviceFormCard> createState() => _DeviceFormCardState();
}

class _DeviceFormCardState extends State<_DeviceFormCard> {
  DateTime _calculateExpiry(DateTime startDate, int months) {
    int targetYear = startDate.year;
    int targetMonth = startDate.month + months;
    
    final tempDate = DateTime(targetYear, targetMonth);
    final actualYear = tempDate.year;
    final actualMonth = tempDate.month;
    
    final lastDay = DateTime(actualYear, actualMonth + 1, 0).day;
    final day = startDate.day > lastDay ? lastDay : startDate.day;
    
    return DateTime(actualYear, actualMonth, day);
  }

  bool _isMatchingShortcut(DateTime? expiry, DateTime startDate, int months) {
    if (expiry == null) return false;
    final expected = _calculateExpiry(startDate, months);
    return expiry.year == expected.year &&
           expiry.month == expected.month &&
           expiry.day == expected.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final entry = widget.entry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // Tên thiết bị
            TextFormField(
              controller: entry.nameController,
              decoration: InputDecoration(
                labelText: 'Tên thiết bị *',
                hintText: 'Biến tần Yaskawa, Delta...',
                prefixIcon: const Icon(Icons.devices_outlined, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: 12),
            // Số seri
            TextFormField(
              controller: entry.serialController,
              decoration: InputDecoration(
                labelText: 'Số seri',
                hintText: 'Nhập số seri (nếu có)',
                prefixIcon: const Icon(Icons.tag, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: 12),
            // Bảo hành switch
            SwitchListTile(
              title: const Text('Bảo hành', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                entry.underWarranty ? 'Có bảo hành' : 'Không bảo hành',
                style: const TextStyle(fontSize: 12),
              ),
              value: entry.underWarranty,
              onChanged: (v) {
                setState(() {
                  entry.underWarranty = v;
                  if (!v) {
                    entry.warrantyExpiry = null;
                  }
                });
                widget.onChanged();
              },
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (entry.underWarranty) ...[
              const SizedBox(height: 8),
              // Chọn ngày bắt đầu bảo hành
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: isDark ? ThemeData.dark() : ThemeData.light(),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      entry.warrantyStartDate = picked;
                    });
                    widget.onChanged();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.warrantyStartDate != null
                              ? 'Ngày bảo hành: ${DateFormat('dd/MM/yyyy').format(entry.warrantyStartDate!)}'
                              : 'Ngày bảo hành: Ngày tạo đơn (${DateFormat('dd/MM/yyyy').format(widget.orderCreatedAt ?? DateTime.now())})',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (entry.warrantyStartDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              entry.warrantyStartDate = null;
                            });
                            widget.onChanged();
                          },
                          child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Nút chọn hạn
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.av_timer, size: 16),
                      label: const Text('Hạn 6 tháng', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 6)
                              ? AppColors.primary
                              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        foregroundColor: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 6)
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                        backgroundColor: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 6)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      onPressed: () {
                        setState(() {
                          entry.warrantyExpiry = _calculateExpiry(entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 6);
                        });
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Hạn 12 tháng', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 12)
                              ? AppColors.primary
                              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                        foregroundColor: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 12)
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                        backgroundColor: _isMatchingShortcut(entry.warrantyExpiry, entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 12)
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      onPressed: () {
                        setState(() {
                          entry.warrantyExpiry = _calculateExpiry(entry.warrantyStartDate ?? widget.orderCreatedAt ?? DateTime.now(), 12);
                        });
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
              if (entry.warrantyExpiry != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: !_isWarrantyValid(entry.warrantyExpiry)
                            ? AppColors.error
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!)),
                    borderRadius: BorderRadius.circular(10),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: !_isWarrantyValid(entry.warrantyExpiry)
                            ? AppColors.error
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Hạn bảo hành: ${DateFormat('dd/MM/yyyy').format(entry.warrantyExpiry!)}',
                              style: TextStyle(
                                color: !_isWarrantyValid(entry.warrantyExpiry)
                                    ? AppColors.error
                                    : (isDark ? Colors.white : Colors.black87),
                                fontSize: 14,
                                fontWeight: !_isWarrantyValid(entry.warrantyExpiry)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (!_isWarrantyValid(entry.warrantyExpiry)) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '(Hết hạn)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            entry.warrantyExpiry = null;
                          });
                          widget.onChanged();
                        },
                        child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 8),
            // Tình trạng lỗi
            TextFormField(
              controller: entry.descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Tình trạng lỗi',
                hintText: 'Mô tả lỗi thiết bị',
                prefixIcon: const Icon(Icons.error_outline, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
              onChanged: (_) => widget.onChanged(),
            ),
          ],
        );
      }
    }


